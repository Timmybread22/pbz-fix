#!/usr/bin/env python3
import importlib.util
import json
import os
import pty
import select
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from unittest.mock import MagicMock, patch

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


def run_piped_prompt(steam_root, install_dir, answer):
    child, terminal = pty.fork()
    if child == 0:
        os.execlp(
            "bash",
            "bash",
            "-c",
            'printf "piped input\\n" | python3 "$1" setup --steam-root "$2" --install-dir "$3"',
            "prompt-test",
            str(SCRIPT_DIR / "steam-launch-config.py"),
            str(steam_root),
            str(install_dir),
        )

    output = bytearray()
    prompted = False
    status = None
    deadline = time.monotonic() + 10
    try:
        while time.monotonic() < deadline:
            ready, _, _ = select.select([terminal], [], [], 0.1)
            if ready:
                try:
                    chunk = os.read(terminal, 4096)
                except OSError:
                    chunk = b""
                output.extend(chunk)
                if b"Replace them? [y/N]" in output and not prompted:
                    os.write(terminal, answer.encode() + b"\n")
                    prompted = True
            result, child_status = os.waitpid(child, os.WNOHANG)
            if result == child:
                status = child_status
                break
        if status is None:
            os.kill(child, signal.SIGKILL)
            os.waitpid(child, 0)
            raise AssertionError(f"Prompt test timed out: {output!r}")
        assert os.waitstatus_to_exitcode(status) == 0, output.decode(errors="replace")
        assert prompted, output.decode(errors="replace")
    finally:
        os.close(terminal)


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

        old_steam = root / "old-wrapper-steam"
        old_config = old_steam / "userdata/400/config/localconfig.vdf"
        old_option = 'bash "~/pbz-fix-beta/steam-launch-beta.sh" %command%'
        old_original = first_original.replace('"old option"', json.dumps(old_option))
        write_config(old_config, old_original)

        def unexpected_prompt(_path):
            raise AssertionError("Previous PBZ wrapper should not prompt.")

        CONFIG.setup_launch_options(old_steam, root / "old-install", unexpected_prompt)
        old_updated = old_config.read_text(encoding="utf-8")
        assert CONFIG.app_settings(old_updated)[2][0]["value"] == (
            f'bash "{(root / "old-install").resolve()}/steam-launch-beta.sh" %command%'
        )
        manifest = CONFIG.read_manifest(root / "old-install" / CONFIG.BACKUP_MANIFEST)
        assert Path(manifest["entries"][0]["backup_path"]).read_text(
            encoding="utf-8"
        ) == old_original
        assert not CONFIG.is_previous_pbz_wrapper('echo steam-launch-beta.sh.bak')
        assert not CONFIG.is_previous_pbz_wrapper('echo steam-launch-beta.sh %command%')
        assert not CONFIG.is_previous_pbz_wrapper(
            'bash ~/pbz-fix-beta/steam-launch-beta.sh --custom %command%'
        )
        assert not CONFIG.is_previous_pbz_wrapper('"unterminated')

        for answer in ("y", "n"):
            prompt_steam = root / f"prompt-{answer}"
            prompt_config = prompt_steam / "userdata/500/config/localconfig.vdf"
            prompt_install = root / f"prompt-install-{answer}"
            write_config(prompt_config, first_original)
            run_piped_prompt(prompt_steam, prompt_install, answer)
            updated = prompt_config.read_text(encoding="utf-8")
            if answer == "y":
                assert CONFIG.app_settings(updated)[2][0]["value"] == (
                    f'bash "{prompt_install.resolve()}/steam-launch-beta.sh" %command%'
                )
            else:
                assert updated == first_original

        no_tty = subprocess.run(
            [
                sys.executable,
                str(SCRIPT_DIR / "steam-launch-config.py"),
                "setup",
                "--steam-root",
                str(root / "prompt-n"),
                "--install-dir",
                str(root / "no-tty-install"),
            ],
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            start_new_session=True,
            check=False,
        )
        assert no_tty.returncode == 1
        assert "requires a controlling terminal" in no_tty.stderr

        with patch("builtins.open", side_effect=PermissionError(13, "Permission denied")):
            try:
                CONFIG.ask_replace(first)
            except ValueError as error:
                assert "Could not open the terminal" in str(error)
                assert "Permission denied" in str(error)
            else:
                raise AssertionError("Terminal access error was not reported.")
        terminal_in = MagicMock()
        terminal_out = MagicMock()
        terminal_in.__enter__.return_value = terminal_in
        terminal_out.__enter__.return_value = terminal_out
        terminal_out.write.side_effect = OSError(5, "Input/output error")
        with patch("builtins.open", side_effect=[terminal_in, terminal_out]):
            try:
                CONFIG.ask_replace(first)
            except ValueError as error:
                assert "Could not read or write the terminal" in str(error)
                assert "Input/output error" in str(error)
            else:
                raise AssertionError("Terminal I/O error was not reported.")
        print("Steam launch config tests passed.")


if __name__ == "__main__":
    main()
