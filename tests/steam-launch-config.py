#!/usr/bin/env python3
import importlib.util
import json
import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parents[1]
MODULE_SPEC = importlib.util.spec_from_file_location(
    "steam_launch_config", SCRIPT_DIR / "steam-launch-config.py"
)
CONFIG = importlib.util.module_from_spec(MODULE_SPEC)
sys.modules[MODULE_SPEC.name] = CONFIG
MODULE_SPEC.loader.exec_module(CONFIG)


def write_config(path, body):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body, encoding="utf-8")


def main():
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        steam_root = root / "Steam"
        install_dir = root / "share" / "pbz-fix"
        first = steam_root / "userdata/100/config/localconfig.vdf"
        second = steam_root / "userdata/200/config/localconfig.vdf"
        first_original = '''"UserLocalConfigStore"
{
    "Software"
    {
        "Valve"
        {
            "Steam"
            {
                "apps"
                {
                    "4115450"
                    {
                        "LaunchOptions" "old option"
                        "LastPlayed" "1"
                    }
                }
            }
        }
    }
}
'''
        second_original = '''"UserLocalConfigStore"
{
    "Software"
    {
        "Valve"
        {
            "Steam"
            {
                "apps"
                {
                    "1234"
                    {
                        "LastPlayed" "2"
                    }
                }
            }
        }
    }
}
'''
        write_config(first, first_original)
        write_config(second, second_original)

        CONFIG.setup_launch_options(steam_root, install_dir)
        expected_option = (
            f'bash "{install_dir.resolve()}/steam-launch.sh" %command%'
        )
        first_updated = first.read_text(encoding="utf-8")
        second_updated = second.read_text(encoding="utf-8")
        assert "old option" not in first_updated
        assert CONFIG.app_settings(first_updated)[2][0]["value"] == expected_option
        assert CONFIG.app_settings(second_updated)[2][0]["value"] == expected_option
        assert "4115450" in second_updated

        manifest_path = install_dir / CONFIG.BACKUP_MANIFEST
        manifest = CONFIG.read_manifest(manifest_path)
        assert len(manifest["entries"]) == 2
        assert all(Path(entry["backup_path"]).is_file() for entry in manifest["entries"])

        changed_option = 'MANGOHUD=1 %command%'
        changed_text = CONFIG.set_app_option(
            first_updated, *CONFIG.app_settings(first_updated), changed_option
        )
        write_config(first, changed_text)
        CONFIG.setup_launch_options(steam_root, install_dir)
        assert CONFIG.app_settings(first.read_text(encoding="utf-8"))[2][0][
            "value"
        ] == expected_option
        backups = list((install_dir / "backups").glob("*/localconfig-100-*.vdf"))
        assert any(path.read_text(encoding="utf-8") == changed_text for path in backups)
        assert CONFIG.read_manifest(manifest_path) == manifest

        CONFIG.undo_launch_options(steam_root, install_dir)
        assert first.read_text(encoding="utf-8") == first_original
        assert second.read_text(encoding="utf-8") == second_original
        assert not manifest_path.exists()

        old_steam = root / "old-wrapper-steam"
        old_config = old_steam / "userdata/400/config/localconfig.vdf"
        old_option = 'bash "~/pbz-fix-beta/steam-launch-beta.sh" %command%'
        old_original = first_original.replace('"old option"', json.dumps(old_option))
        write_config(old_config, old_original)

        CONFIG.setup_launch_options(old_steam, root / "old-install")
        old_updated = old_config.read_text(encoding="utf-8")
        assert CONFIG.app_settings(old_updated)[2][0]["value"] == (
            f'bash "{(root / "old-install").resolve()}/steam-launch.sh" %command%'
        )
        manifest = CONFIG.read_manifest(root / "old-install" / CONFIG.BACKUP_MANIFEST)
        assert Path(manifest["entries"][0]["backup_path"]).read_text(
            encoding="utf-8"
        ) == old_original
        CONFIG.undo_launch_options(old_steam, root / "old-install")
        assert old_config.read_text(encoding="utf-8") == old_original

        legacy_steam = root / "legacy-steam"
        legacy_install = root / "legacy-install"
        legacy_config = legacy_steam / "userdata/600/config/localconfig.vdf"
        legacy_backup = legacy_install / "backups" / "old" / "localconfig.vdf"
        write_config(legacy_config, old_original)
        write_config(legacy_backup, first_original)
        CONFIG.write_manifest(
            legacy_install / CONFIG.BACKUP_MANIFEST,
            {"entries": [{
                "config_path": str(legacy_config.resolve()),
                "backup_path": str(legacy_backup.resolve()),
            }]},
        )
        CONFIG.setup_launch_options(legacy_steam, legacy_install)
        assert CONFIG.app_settings(legacy_config.read_text(encoding="utf-8"))[2][0][
            "value"
        ] == f'bash "{legacy_install.resolve()}/steam-launch.sh" %command%'
        assert legacy_backup.read_text(encoding="utf-8") == first_original
        CONFIG.undo_launch_options(legacy_steam, legacy_install)
        assert legacy_config.read_text(encoding="utf-8") == first_original

        no_tty_steam = root / "no-tty-steam"
        no_tty_config = no_tty_steam / "userdata/500/config/localconfig.vdf"
        no_tty_install = root / "no-tty-install"
        write_config(no_tty_config, first_original)
        no_tty = subprocess.run(
            [
                sys.executable,
                str(SCRIPT_DIR / "steam-launch-config.py"),
                "setup",
                "--steam-root",
                str(no_tty_steam),
                "--install-dir",
                str(no_tty_install),
            ],
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            start_new_session=True,
            check=False,
        )
        assert no_tty.returncode == 0, no_tty.stderr
        assert "Replaced existing launch options" in no_tty.stdout
        assert CONFIG.app_settings(no_tty_config.read_text(encoding="utf-8"))[2][0][
            "value"
        ] == f'bash "{no_tty_install.resolve()}/steam-launch.sh" %command%'
        manifest = CONFIG.read_manifest(no_tty_install / CONFIG.BACKUP_MANIFEST)
        assert Path(manifest["entries"][0]["backup_path"]).read_text(
            encoding="utf-8"
        ) == first_original
        CONFIG.undo_launch_options(no_tty_steam, no_tty_install)
        assert no_tty_config.read_text(encoding="utf-8") == first_original
        print("Steam launch config tests passed.")


if __name__ == "__main__":
    main()
