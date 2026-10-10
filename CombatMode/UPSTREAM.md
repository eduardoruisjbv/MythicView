# Combat Mode source attribution

This module is derived from [Combat Mode](https://github.com/djsmithdev/combatmode),
version 4.8.2, commit `10bd846d1aec4b00b2f6f85df54414eb361e7902`.
The upstream `CombatMode.toc` credits justice7ca and sampconrad.

The source, textures, and original changelog are retained here. The integration
places modules under `MythicView/CombatMode`, binds them to the nested
`MythicView` addon namespace, stores settings in `MythicViewDB.combatMode`, and
leaves camera CVar control with Mythic View. `CombatMode/Embeds.xml` preserves
the upstream module load order. Its standalone Settings bridge is not loaded;
Mythic View provides the entry to the options window.

The copied `CombatMode.toc` and `Bindings.xml` document the upstream package;
the Mythic View root TOC and bindings file are the active manifests.
