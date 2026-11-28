#!/usr/bin/env python3
import importlib.util
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

        CONFIG.setup_launch_options(
            steam_root, install_dir, lambda _path: True
        )
        expected_option = (
            f'bash "{install_dir.resolve()}/steam-launch-beta.sh" %command%'
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

        CONFIG.undo_launch_options(steam_root, install_dir)
        assert first.read_text(encoding="utf-8") == first_original
        assert second.read_text(encoding="utf-8") == second_original
        assert not manifest_path.exists()

        declined = steam_root / "userdata/300/config/localconfig.vdf"
        declined_original = first_original.replace(
            '"old option"', '"keep my launch option"'
        )
        write_config(declined, declined_original)
        CONFIG.setup_launch_options(
            steam_root, install_dir, lambda _path: False
        )
        assert declined.read_text(encoding="utf-8") == declined_original
        print("Steam launch config tests passed.")


if __name__ == "__main__":
    main()
