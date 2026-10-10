# Combat Mode integration and settings migration

The integrated Combat Mode code lives under `CombatMode/` and stores its settings in
`MythicViewDB.combatMode`. Before loading this version, migrate settings from the
standalone Combat Mode addon while World of Warcraft is fully closed:

```text
python3 scripts/migrate_combatmode_sv.py /path/to/CombatMode.lua /path/to/MythicView.lua
```

The script preserves the standalone file, makes timestamped backups of both files,
converts saved Combat Mode texture paths, and refuses to overwrite an existing
`MythicViewDB.combatMode`. After migration, disable the standalone Combat Mode addon
in the launcher or addon manager, then start the client with Mythic View enabled.

Open the integrated controls with `/mv combat` or from the Mythic View settings
category. Camera framing and camera CVars remain owned by Mythic View.
