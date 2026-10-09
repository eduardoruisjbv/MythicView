# Mythic View — Changelog

## 1.1.0 — Three new camera styles (2026-10-08)

- Added **The Last of Us Part II** (low and tight over the shoulder, narrow view, slow tense movement, aim while casting), **Ghost of Tsushima** (mid-distance, nearly centered, long silky transitions) and **Sekiro: Shadows Die Twice** (closer and faster than Elden Ring, strong enemy focus, sharp impacts).
- Ten selectable styles in total, plus the automatic Competitive PvP camera.

## 1.0.7 — Lua loading hotfix (2026-10-07)

- Fixed the Lua 5.1 chunk local-variable limit that prevented the addon from loading. PvP helpers now use the addon namespace and existing tuning table, preserving the fixed PvP camera and automatic switch.

## 1.0.6 — Fixed PvP camera (2026-10-07)

- The automatic arena/battleground mode now holds one profile through combat, crowds, movement and mounting: maximum addon zoom, 90-degree FOV, centered shoulder, and no dynamic camera layers.
- The automatic-mode checkbox remains enabled by default; the player's selected style is restored after leaving PvP.

## 1.0.5 — Automatic PvP camera (2026-10-07)

- Added a Competitive PvP camera style with a wider, more centered and steadier view, reduced camera motion, and no cast aiming or target focus.
- Arenas and battlegrounds now switch to this style automatically by default; the selected camera style is restored after leaving PvP. The automatic switch can be disabled in Options.

## 1.0.4 — PvP-aware battleground camera (2026-10-07)

- Added dedicated battleground framing, with separate profiles for normal combat, crowds and large groups. Battleground framing takes priority over movement and mounted states so the view stays wide and steady.
- Disabled target-follow camera focus in battlegrounds and arenas to prevent the game camera from pulling the view toward selected enemies.

## 1.0.3 — Smooth camera (2026-10-05)

- Fixed the small camera judder: while it animates, the camera now updates on every rendered frame (capped at 144 Hz). It used to update at half the frame rate and reset its timer, so it advanced in uneven steps of 2–3 frames.
- Profile transitions drive the zoom with the engine's own continuous movement (MoveViewIn/Out at the velocity of the easing curve) instead of many small CameraZoomIn/Out chunks, and hand over a single correction when the curve ends.
- Resting cost is unchanged: with nothing animating the camera still updates rarely.

## 1.0.1 — Hotfix (2026-10-04)

- Flight-path taxis and Skyriding: the camera is handed back to the game for the whole flight and re-applied on landing (fixes the glitching).
- Target tracking is much smoother: slower ease-in, even slower ease-out, and the engine focus is only switched off after it has faded to zero (no more snap when a target is lost).
- All camera events are softer: longer profile/FOV/shoulder transitions, impacts rise gently and last longer, hit-stop freeze removed, slower aim, drag, look-ahead, rubber band and footstep fades, finer FOV steps.

## 1.0.0 — First stable release (2026-10-04)

A cinematic, context-aware camera for World of Warcraft: Midnight (12.x), inspired by third-person action games. No dependencies.

### Camera styles
Seven styles, chosen in **Options › AddOns › Mythic View** (or `/mv`):
- **God of War Ragnarök** — tight over the right shoulder, weighty transitions.
- **Darksiders** — higher and farther, character centred, camera looking down.
- **Horizon Zero Dawn** — mid-distance shoulder view, fluid movement, aim on cast.
- **Warhammer 40K: Space Marine** — wide shoulder offset and a low camera, sprint pulls back, aim on cast.
- **The Witcher 3** — high, distant and nearly centred, slow and floaty.
- **Elden Ring** — mid distance, crisp transitions, strong focus on the enemy.
- **Red Dead Redemption 2** — slow and cinematic, wide mounted view, aim on cast.

### Context-aware camera
- Dedicated framing for: standing and moving exploration, sustained running, staged backpedalling, hostile target out of combat, cities and indoors, dungeons, raids, arenas, ground mounts, flying and Skyriding.
- In combat: close target, crowd (2+ attackers) and horde (4+), with the frame stretching for each extra enemy up to 8 (*rubber band*) and relaxing slowly.
- **Speed drag**: the camera falls behind as you accelerate and catches up as you slow down.
- **Look-ahead**: turning or strafing opens space on the side you are heading to.
- **Rule of thirds**: when zoom or FOV change, the shoulder offset follows so your character keeps their place on screen.
- **Aim on cast** (Horizon, Space Marine, RDR2): cast-time spells and channels push the camera in over the shoulder.
- **Lock-on**: lock the camera onto your target with a key binding (Key Bindings › AddOns › Mythic View) or `/mv lock`; it releases by itself when the target dies or disappears.
- Target focus ramps in smoothly: firmer in duels, lighter in crowds and while you move.
- High-speed Skyriding raises the view distance.

### Smoothness
- Every transition uses a *smootherstep* curve: moves start and stop without a jolt.
- Zoom, FOV and shoulder move at independent paces.
- Zoom follows the curve's pace while moving and only corrects what is left once settled — no overshoot and bounce back.
- Manual mouse-wheel zoom is respected; the framing returns 2.5 s after you stop scrolling.

### Options
- Camera style and overall distance (70–150%).
- Individual toggles: speed drag, look-ahead, rule of thirds, rubber band and aim on cast.
- Game engine (optional): smoother collision with a character silhouette behind walls, and a camera that trails behind you while moving (*free follow*).

### Performance and safety
- Event driven: when idle, the addon does not write camera settings every frame.
- Reacts only to your own spells, never to the whole raid's.
- Every camera setting it changes is restored when you log out.

### Integration
- Optional AzeriteUI support: applies its cinematic preset once, when AzeriteUI offers it.

### Known limitations
- **Camera shake (impacts, footsteps, breathing) is disabled in this release** while its motion is being redesigned. The code ships switched off.
- WoW does not let addons rotate the camera sideways safely, so there is no rotational shake.
- WoW does not expose enemy positions to addons; target framing relies on the game's native target focus.
