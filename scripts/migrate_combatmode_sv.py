#!/usr/bin/env python3
"""Move standalone CombatModeDB into MythicViewDB.combatMode offline.

Run only after WoW is fully closed. This edits the two supplied SavedVariables
files atomically and makes timestamped backups beside each file.
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import shutil
import tempfile
from datetime import datetime


def assignment_table(source: str, name: str) -> tuple[int, int, str]:
    match = re.search(rf"\b{re.escape(name)}\s*=\s*\{{", source)
    if not match:
        raise ValueError(f"Could not find table assignment for {name}")
    start = source.find("{", match.start())
    depth = 0
    quote: str | None = None
    escaped = False
    line_comment = False
    long_comment = False
    i = start
    while i < len(source):
        char = source[i]
        nxt = source[i + 1] if i + 1 < len(source) else ""
        if line_comment:
            if char == "\n":
                line_comment = False
        elif long_comment:
            if char == "]" and nxt == "]":
                long_comment = False
                i += 1
        elif quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
        elif char in ("'", '"'):
            quote = char
        elif char == "-" and nxt == "-":
            if i + 3 < len(source) and source[i + 2 : i + 4] == "[[":
                long_comment = True
                i += 3
            else:
                line_comment = True
                i += 1
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return start, i + 1, source[start : i + 1]
        i += 1
    raise ValueError(f"Unterminated table assignment for {name}")


def rewrite_asset_paths(lua_table: str) -> str:
    old = "Interface\\\\AddOns\\\\CombatMode\\\\"
    new = "Interface\\\\AddOns\\\\MythicView\\\\CombatMode\\\\"
    return lua_table.replace(old, new)


def migrate(old_path: Path, mythic_path: Path) -> tuple[Path, Path]:
    if not old_path.is_file() or not mythic_path.is_file():
        raise FileNotFoundError("Both SavedVariables files must exist")
    old_source = old_path.read_text(encoding="utf-8")
    mythic_source = mythic_path.read_text(encoding="utf-8")
    _, _, cm_table = assignment_table(old_source, "CombatModeDB")
    cm_table = rewrite_asset_paths(cm_table)
    mv_start, mv_end, _ = assignment_table(mythic_source, "MythicViewDB")
    mv_table = mythic_source[mv_start:mv_end]
    if re.search(r'\["combatMode"\]\s*=', mv_table):
        raise ValueError("MythicViewDB already contains combatMode; refusing to overwrite it")
    # Insert directly inside the MythicViewDB top-level table. WoW normally
    # emits a trailing comma, but accept files without one as well.
    inner = mv_table[1:-1].rstrip()
    if inner and not inner.endswith(","):
        inner += ","
    inserted = "{\n" + inner + '\n  ["combatMode"] = ' + cm_table + ",\n}"
    updated = mythic_source[:mv_start] + inserted + mythic_source[mv_end:]

    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backups = (old_path.with_suffix(old_path.suffix + f".pre-mythicview-{stamp}.bak"),
               mythic_path.with_suffix(mythic_path.suffix + f".pre-combatmode-migration-{stamp}.bak"))
    shutil.copy2(old_path, backups[0])
    shutil.copy2(mythic_path, backups[1])
    fd, temp_name = tempfile.mkstemp(prefix=f".{mythic_path.name}.", dir=mythic_path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as handle:
            handle.write(updated)
            handle.flush()
            os.fsync(handle.fileno())
        shutil.copystat(mythic_path, temp_name)
        os.replace(temp_name, mythic_path)
    finally:
        if os.path.exists(temp_name):
            os.unlink(temp_name)
    return backups


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("combatmode_savedvariables", type=Path)
    parser.add_argument("mythicview_savedvariables", type=Path)
    args = parser.parse_args()
    backups = migrate(args.combatmode_savedvariables, args.mythicview_savedvariables)
    print("Migration complete. Backups:")
    for path in backups:
        print(path)


if __name__ == "__main__":
    main()
