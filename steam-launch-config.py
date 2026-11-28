#!/usr/bin/env python3
import argparse
import errno
import json
import os
import re
import shlex
import shutil
import sys
import tempfile
from contextlib import ExitStack
from datetime import datetime
from pathlib import Path

APP_ID = "4115450"
BACKUP_MANIFEST = "steam-launch-backup.json"


def tokenize(text):
    tokens = []
    index = 0
    while index < len(text):
        char = text[index]
        if char.isspace():
            index += 1
            continue
        if text.startswith("//", index):
            newline = text.find("\n", index)
            index = len(text) if newline == -1 else newline + 1
            continue
        if char in "{}":
            tokens.append((char, char, index, index + 1))
            index += 1
            continue
        if char == '"':
            start = index
            index += 1
            value = []
            while index < len(text):
                char = text[index]
                if char == '"':
                    index += 1
                    tokens.append(("string", "".join(value), start, index))
                    break
                if char == "\\" and index + 1 < len(text):
                    next_char = text[index + 1]
                    if next_char in ('"', "\\"):
                        value.append(next_char)
                    else:
                        value.extend(("\\", next_char))
                    index += 2
                    continue
                value.append(char)
                index += 1
            else:
                raise ValueError("Unterminated quoted string in Steam config.")
            continue
        start = index
        while index < len(text) and not text[index].isspace() and text[index] not in "{}":
            index += 1
        tokens.append(("bare", text[start:index], start, index))
    return tokens


def parse_block(tokens, index=0):
    entries = []
    while index < len(tokens):
        token = tokens[index]
        if token[0] == "}":
            return entries, index + 1
        if token[0] not in ("string", "bare"):
            raise ValueError("Unexpected token in Steam config.")
        key_token = token
        index += 1
        if index >= len(tokens):
            raise ValueError("Incomplete key/value pair in Steam config.")
        value_token = tokens[index]
        if value_token[0] == "{":
            children, index = parse_block(tokens, index + 1)
            entries.append(
                {
                    "key": key_token[1],
                    "children": children,
                    "key_start": key_token[2],
                    "open": value_token[2],
                    "close": tokens[index - 1][2],
                }
            )
        elif value_token[0] in ("string", "bare"):
            entries.append(
                {
                    "key": key_token[1],
                    "value": value_token[1],
                    "key_start": key_token[2],
                    "value_start": value_token[2],
                    "value_end": value_token[3],
                }
            )
            index += 1
        else:
            raise ValueError("Unexpected value in Steam config.")
    return entries, index


def child_block(entries, key):
    matches = [
        entry
        for entry in entries
        if entry["key"] == key and "children" in entry
    ]
    if len(matches) > 1:
        raise ValueError(f"Multiple {key!r} blocks in Steam config.")
    return matches[0] if matches else None


def app_settings(text):
    entries, _ = parse_block(tokenize(text))
    root = child_block(entries, "UserLocalConfigStore")
    software = child_block(root["children"], "Software") if root else None
    valve = child_block(software["children"], "Valve") if software else None
    steam = child_block(valve["children"], "Steam") if valve else None
    apps = child_block(steam["children"], "apps") if steam else None
    if apps is None:
        raise ValueError("Steam app settings block is missing from localconfig.vdf.")
    app = child_block(apps["children"], APP_ID)
    if app is None:
        return apps, None, []
    options = [
        entry
        for entry in app["children"]
        if entry["key"] == "LaunchOptions" and "value_start" in entry
    ]
    if len(options) > 1:
        raise ValueError("Multiple LaunchOptions values found for Phantom Blade Zero.")
    return apps, app, options


def set_app_option(text, apps, app, options, launch_option):
    encoded = json.dumps(launch_option, ensure_ascii=False)
    if options:
        option = options[0]
        return (
            text[: option["value_start"]]
            + encoded
            + text[option["value_end"] :]
        )

    if app is None:
        close_line = text.rfind("\n", 0, apps["close"]) + 1
        close_indent = re.match(r"[ \t]*", text[close_line : apps["close"]]).group()
        indent = close_indent + "\t"
        insertion = (
            f'{indent}"{APP_ID}"\n'
            f"{indent}{{\n"
            f'{indent}\t"LaunchOptions"\t{encoded}\n'
            f"{indent}}}\n"
        )
        return text[:close_line] + insertion + text[close_line:]

    close_line = text.rfind("\n", 0, app["close"]) + 1
    close_indent = re.match(r"[ \t]*", text[close_line : app["close"]]).group()
    insertion = f'{close_indent}\t"LaunchOptions"\t{encoded}\n'
    return text[:close_line] + insertion + text[close_line:]


def config_files(steam_root):
    return sorted(
        (Path(steam_root) / "userdata").glob("*/config/localconfig.vdf")
    )


def atomic_write(path, data, mode):
    descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(data)
            os.fchmod(stream.fileno(), mode)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def read_manifest(path):
    if not path.exists():
        return {"entries": []}
    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError("Could not read the previous Steam launch backup manifest.") from error
    if not isinstance(manifest.get("entries"), list):
        raise ValueError("Steam launch backup manifest has an invalid format.")
    return manifest


def write_manifest(path, manifest):
    data = (json.dumps(manifest, indent=2) + "\n").encode("utf-8")
    atomic_write(path, data, 0o600)


def is_previous_pbz_wrapper(option):
    try:
        args = shlex.split(option)
    except ValueError:
        return False
    if len(args) == 2 and args[1] == "%command%":
        return Path(args[0]).name == "steam-launch-beta.sh"
    if len(args) == 3 and args[2] == "%command%":
        return (
            Path(args[0]).name in ("bash", "sh")
            and Path(args[1]).name == "steam-launch-beta.sh"
        )
    return False


def setup_launch_options(steam_root, install_dir, prompt_replace):
    steam_root = Path(steam_root).resolve()
    install_dir = Path(install_dir).resolve()
    configs = config_files(steam_root)
    if not configs:
        raise ValueError("No Steam userdata localconfig.vdf files were found.")

    wrapper_path = install_dir / "steam-launch-beta.sh"
    quoted_path = (
        str(wrapper_path)
        .replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("$", "\\$")
        .replace("`", "\\`")
    )
    launch_option = f'bash "{quoted_path}" %command%'
    plans = []

    for path in configs:
        text = path.read_text(encoding="utf-8")
        apps, app, options = app_settings(text)
        current = options[0]["value"] if options else None
        if current == launch_option:
            continue
        if (
            current is not None
            and not is_previous_pbz_wrapper(current)
            and not prompt_replace(path)
        ):
            print(f"Skipped existing launch options for Steam user {path.parts[-3]}.")
            continue
        updated = set_app_option(text, apps, app, options, launch_option)
        plans.append((path, text, updated))

    if not plans:
        print("No Steam launch options needed changes.")
        return

    install_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = install_dir / BACKUP_MANIFEST
    manifest = read_manifest(manifest_path)
    tracked = {entry["config_path"] for entry in manifest["entries"]}
    new_backups = []
    untracked_plans = [plan for plan in plans if str(plan[0]) not in tracked]

    if untracked_plans:
        backups_root = install_dir / "backups"
        backups_root.mkdir(parents=True, exist_ok=True)
        backup_dir = Path(
            tempfile.mkdtemp(
                prefix=f"{datetime.now().strftime('%Y%m%d-%H%M%S')}-",
                dir=backups_root,
            )
        )
        for index, (path, _, _) in enumerate(untracked_plans):
            backup_path = backup_dir / f"localconfig-{path.parts[-3]}-{index}.vdf"
            shutil.copy2(path, backup_path)
            new_backups.append(
                {"config_path": str(path), "backup_path": str(backup_path)}
            )

    if new_backups:
        manifest["entries"].extend(new_backups)
        write_manifest(manifest_path, manifest)

    for path, _, updated in plans:
        atomic_write(path, updated.encode("utf-8"), path.stat().st_mode)

    print(f"Steam launch options configured for {len(plans)} account(s).")
    if new_backups:
        print(f"Original Steam config backed up under {backup_dir}.")


def undo_launch_options(steam_root, install_dir):
    steam_root = Path(steam_root).resolve()
    install_dir = Path(install_dir).resolve()
    manifest_path = install_dir / BACKUP_MANIFEST
    manifest = read_manifest(manifest_path)
    entries = manifest["entries"]
    if not entries:
        raise ValueError("No saved Steam launch configuration backup was found.")

    userdata_root = (steam_root / "userdata").resolve()
    backup_root = (install_dir / "backups").resolve()
    for entry in entries:
        config_path = Path(entry["config_path"])
        backup_path = Path(entry["backup_path"])
        if config_path.name != "localconfig.vdf" or config_path.parent.name != "config":
            raise ValueError("Backup manifest contains an invalid Steam config path.")
        if userdata_root not in config_path.resolve().parents:
            raise ValueError("Backup manifest points outside Steam userdata.")
        if backup_root not in backup_path.resolve().parents or not backup_path.is_file():
            raise ValueError("A Steam config backup is missing or outside the backup folder.")

    for entry in entries:
        config_path = Path(entry["config_path"])
        backup_path = Path(entry["backup_path"])
        data = backup_path.read_bytes()
        mode = backup_path.stat().st_mode
        atomic_write(config_path, data, mode)

    manifest_path.unlink()
    print(f"Restored Steam launch settings for {len(entries)} account(s).")
    print("Steam launch wrapper files remain installed and can be removed manually.")


def ask_replace(path):
    with ExitStack() as stack:
        try:
            terminal_in = stack.enter_context(open("/dev/tty", "r", encoding="utf-8"))
            terminal_out = stack.enter_context(open("/dev/tty", "w", encoding="utf-8"))
        except OSError as error:
            if error.errno in (errno.ENXIO, errno.ENODEV, errno.ENOENT):
                raise ValueError(
                    "Replacing existing Steam launch options requires a controlling terminal."
                ) from error
            raise ValueError(f"Could not open the terminal: {error}") from error
        try:
            terminal_out.write(
                f"Launch options already exist for Steam user {path.parts[-3]}. "
                "Replace them? [y/N] "
            )
            terminal_out.flush()
            answer = terminal_in.readline()
        except OSError as error:
            raise ValueError(f"Could not read or write the terminal: {error}") from error
        if not answer:
            raise ValueError("Could not read confirmation from the terminal.")
        return answer.strip().lower() in ("y", "yes")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("setup", "undo"))
    parser.add_argument("--steam-root", required=True)
    parser.add_argument("--install-dir", required=True)
    args = parser.parse_args()
    try:
        if args.action == "setup":
            setup_launch_options(args.steam_root, args.install_dir, ask_replace)
        else:
            undo_launch_options(args.steam_root, args.install_dir)
    except (OSError, ValueError) as error:
        print(f"Steam launch setup failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
