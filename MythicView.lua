-- Mythic View
-- A close, over-the-shoulder camera modelled on God of War Ragnarök.
-- Change the values below; no interface panel is created by this addon.
--
-- The camera is built in layers, the way a game engine composes it:
--   1. Base layer: a contextual profile (zoom, shoulder, FOV) with eased
--      transitions between profiles.
--   2. Additive layers on top: trauma shake, hit/landing/combat impulses,
--      footsteps, sprint pull-back and idle breathing. They never change a
--      profile's resting framing, only how the camera moves around it.
-- WoW exposes no camera roll or yaw that is safe to drive (yaw turns the
-- character while mouse-looking), and the camera pitch cannot be read back,
-- so continuous motion uses only directly written channels: shoulder offset
-- (lateral translation), zoom and FOV. Pitch is an opt-in for short impacts.
local _, ns = ...
ns = ns or {}

-- Base profiles, as tuned for the Ragnarök style. Camera styles (PRESETS)
-- reshape these into the live PROFILES table.
local BASE_PROFILES = {
  -- World rule: a closer camera gets a wider FOV; pulling back narrows it.
  -- Deliberately close, keeping the upper body prominent in open-world travel.
  explore = { zoom = 3.0, shoulder = 1.55, fov = 78 },
  -- Walking opens the composition just enough to add depth and look-ahead.
  exploreMoving = { zoom = 5.75, shoulder = 1.25, fov = 85 },
  -- Sustained forward movement gets a final, restrained opening of the frame.
  exploreMovingSustain = { zoom = 6.25, shoulder = 1.25, fov = 90 },
  exploreBackward = { zoom = 3.80, shoulder = 1.25, fov = 74, transitionDuration = 1.20 },
  exploreBackwardApproach = { zoom = 3.45, shoulder = 1.25, fov = 73.5, transitionDuration = 1.00 },
  exploreBackwardSettle = { zoom = 2.95, shoulder = 1.25, fov = 72.8, transitionDuration = 1.00 },
  exploreBackwardLimit = { zoom = 2.50, shoulder = 1.25, fov = 72, transitionDuration = 1.10 },
  -- Once the close framing settles, open only the FOV to restore clarity.
  exploreBackwardReveal = { zoom = 2.50, shoulder = 1.25, fov = 78, transitionDuration = 1.05, fovTransitionDuration = 1.35 },
  -- Selecting a hostile target outside combat narrows only the FOV, making
  -- that target feel more present. Combat profiles deliberately reopen it.
  exploreTarget = { zoom = 5.75, shoulder = 1.25, fov = 74 },
  exploreMovingTarget = { zoom = 7.00, shoulder = 1.25, fov = 81 },
  exploreMovingTargetSustain = { zoom = 7.50, shoulder = 1.25, fov = 84 },
  exploreBackwardTarget = { zoom = 5.05, shoulder = 1.25, fov = 72, transitionDuration = 1.20 },
  exploreBackwardTargetApproach = { zoom = 4.70, shoulder = 1.25, fov = 71.5, transitionDuration = 1.00 },
  exploreBackwardTargetSettle = { zoom = 4.20, shoulder = 1.25, fov = 70.8, transitionDuration = 1.00 },
  exploreBackwardTargetLimit = { zoom = 3.75, shoulder = 1.25, fov = 70, transitionDuration = 1.10 },
  exploreBackwardTargetReveal = { zoom = 3.75, shoulder = 1.25, fov = 76, transitionDuration = 1.05, fovTransitionDuration = 1.35 },
  -- Cities (rest areas) and enclosed spaces use the intimate camera distance.
  indoors = { zoom = 2.5, shoulder = 1.35, fov = 82 },
  indoorsMoving = { zoom = 3.75, shoulder = 1.35, fov = 88 },
  indoorsMovingSustain = { zoom = 4.25, shoulder = 1.35, fov = 90 },
  indoorsBackward = { zoom = 2.10, shoulder = 1.35, fov = 78, transitionDuration = 1.20 },
  indoorsBackwardApproach = { zoom = 1.95, shoulder = 1.35, fov = 77.5, transitionDuration = 1.00 },
  indoorsBackwardSettle = { zoom = 1.72, shoulder = 1.35, fov = 76.8, transitionDuration = 1.00 },
  indoorsBackwardLimit = { zoom = 1.55, shoulder = 1.35, fov = 76, transitionDuration = 1.10 },
  indoorsBackwardReveal = { zoom = 1.55, shoulder = 1.35, fov = 80, transitionDuration = 1.05, fovTransitionDuration = 1.35 },
  indoorsTarget = { zoom = 3.75, shoulder = 1.35, fov = 78 },
  indoorsMovingTarget = { zoom = 5.00, shoulder = 1.35, fov = 85 },
  indoorsMovingTargetSustain = { zoom = 5.50, shoulder = 1.35, fov = 87 },
  indoorsBackwardTarget = { zoom = 3.35, shoulder = 1.35, fov = 76, transitionDuration = 1.20 },
  indoorsBackwardTargetApproach = { zoom = 3.20, shoulder = 1.35, fov = 75.5, transitionDuration = 1.00 },
  indoorsBackwardTargetSettle = { zoom = 2.97, shoulder = 1.35, fov = 74.8, transitionDuration = 1.00 },
  indoorsBackwardTargetLimit = { zoom = 2.80, shoulder = 1.35, fov = 74, transitionDuration = 1.10 },
  indoorsBackwardTargetReveal = { zoom = 2.80, shoulder = 1.35, fov = 80, transitionDuration = 1.05, fovTransitionDuration = 1.35 },
  -- Group/PvP are deliberate exceptions: awareness matters more than perspective.
  dungeon = { zoom = 12.0, shoulder = 1.35, fov = 78 },
  raid = { zoom = 16.0, shoulder = 1.45, fov = 86 },
  arena = { zoom = 15.0, shoulder = 1.45, fov = 86 },
  -- Ground travel stays close and deliberately off-centre for a cinematic ride.
  mountedGround = { zoom = 9.0, shoulder = 4.50, fov = 65 },
  mountedGroundMoving = { zoom = 10.5, shoulder = 4.50, fov = 71 },
  mountedGroundBackward = { zoom = 8.20, shoulder = 4.50, fov = 66 },
  mountedFlying = { zoom = 21.0, shoulder = 0.95, fov = 88 },
  mountedFlyingMoving = { zoom = 22.5, shoulder = 0.95, fov = 90 },
  -- Skyriding needs extra look-ahead at its much higher traversal speed.
  -- Keep both speed states visually identical. Their distinction now controls
  -- view distance only, avoiding camera movement from flight-state churn.
  mountedSkyriding = { zoom = 28.5, shoulder = 0.75, fov = 90 },
  mountedSkyridingMoving = { zoom = 28.5, shoulder = 0.75, fov = 90 },
  -- Retains awareness of enemies while fighting at range or without a target.
  combatWorld = { zoom = 6.0, shoulder = 1.45, fov = 82 },
  combatDungeon = { zoom = 11.5, shoulder = 1.55, fov = 80 },
  combatRaid = { zoom = 14.5, shoulder = 1.60, fov = 86 },
  combatArena = { zoom = 14.0, shoulder = 1.60, fov = 86 },
  -- Ragnarök pulls the camera out and nearer the centre as more enemies close
  -- in. Two or three attackers open the frame; four or more open it further.
  combatCrowdWorld = { zoom = 9.5, shoulder = 1.25, fov = 88 },
  combatCrowdDungeon = { zoom = 14.0, shoulder = 1.35, fov = 86 },
  combatCrowdRaid = { zoom = 17.0, shoulder = 1.40, fov = 88 },
  combatCrowdArena = { zoom = 16.0, shoulder = 1.45, fov = 88 },
  combatHordeWorld = { zoom = 12.5, shoulder = 1.00, fov = 90, transitionDuration = 1.10 },
  combatHordeDungeon = { zoom = 16.5, shoulder = 1.15, fov = 90, transitionDuration = 1.10 },
  combatHordeRaid = { zoom = 19.0, shoulder = 1.20, fov = 90, transitionDuration = 1.10 },
  combatHordeArena = { zoom = 18.0, shoulder = 1.25, fov = 90, transitionDuration = 1.10 },
  -- Tight, intimate framing for enemies within CLOSE_TARGET_DISTANCE yards.
  combatClose = { zoom = 4.5, shoulder = 1.75, fov = 88 },
}

-- Ragnarök feel. Every effect is additive; set a scale to 0 to disable it.
local FEEL = {
  -- Master switch for every shake-type effect: trauma shake, footstep sway,
  -- breathing, hit/landing/combat-entry impulses and micro-freezes. Off until
  -- the motion is redesigned; framing (styles, drag, look-ahead, rubber band,
  -- lock-on, aim) is unaffected.
  shakesEnabled = false,

  -- Ragnarök keeps the camera over the right shoulder; it never swaps sides
  -- when strafing. Set to true to restore the old left-shoulder strafe swap.
  strafeShoulderSwap = false,
  -- Optional vertical tilt (menu: "Tremor vertical"). WoW rotates the camera
  -- at speed * cameraPitchMoveSpeed degrees/second but never reports the
  -- resulting pitch, so it is driven blind; scale it here if it misbehaves.
  pitchScale = 1.0,
  -- Group content stays readable: shakes are softened in raids and parties.
  raidScale = 0.60,
  partyScale = 0.85,

  -- Trauma model (as used by modern action cameras): shake magnitude is
  -- trauma², so light hits stay subtle and heavy ones escalate sharply.
  traumaDecay = 1.8, -- trauma lost per second
  shakePitch = 1.50, -- degrees at full trauma
  shakeShoulder = 0.14, -- shoulder offset at full trauma
  shakeFov = 1.40, -- FOV degrees at full trauma
  shakeFrequency = 14, -- Hz, the dominant shake frequency

  -- Footsteps: a sharp dip on each foot strike plus a sway toward the planted
  -- foot. Cadence follows the real movement speed.
  stepStride = 2.6, -- yards per step on foot
  mountStride = 5.5, -- yards per stride on a ground mount
  stepMinRate = 1.4, -- steps per second
  stepMaxRate = 3.6,
  stepWalkPitch = 0.06, -- degrees
  stepRunPitch = 0.16,
  stepSprintPitch = 0.30,
  stepMountPitch = 0.22,
  stepSway = 0.045, -- shoulder offset; footsteps are a lateral sway, the
  -- vertical bob comes from the native head movement, synced to animation
  stepFadeIn = 0.50, -- seconds
  stepFadeOut = 0.60,
  walkSpeed = 2.5, -- yards per second
  runSpeed = 7.0,
  sprintSpeed = 9.0, -- anything faster on foot reads as a sprint

  -- Sprint: speed boosts pull the camera back, widen the view and add a fine
  -- handheld shake. Sustained running gets a reduced share of the same feel.
  sprintZoom = 0.90,
  sprintFov = 3.0,
  sprintShakeFloor = 0.24, -- trauma floor while sprinting
  sprintSustainWeight = 0.45,
  sprintBlendRate = 1.2, -- per second

  -- Idle breathing: a slow, barely visible lateral drift.
  breathShoulder = 0.015,
  breathRate = 0.21, -- Hz
  breathPitch = 0.10, -- degrees, only with vertical shake enabled

  -- Aim (Horizon style): hard casts and channels push in over the shoulder.
  aimZoom = -1.40,
  aimFov = -7.0,
  aimShoulder = 0.20,
  aimInTime = 0.45,
  aimOutTime = 0.70,

  -- Impacts. zoom < 0 pushes in, > 0 pushes out; attack is the share of the
  -- duration spent rising, so hits snap in and settle out.
  hitLight = { trauma = 0.36, zoom = -0.20, fov = -1.30, pitch = -0.40, duration = 0.30, attack = 0.16 },
  hitHeavy = { trauma = 0.56, zoom = -0.38, fov = -2.40, pitch = -0.75, duration = 0.44, attack = 0.14 },
  hitCriticalTrauma = 0.12,
  hitAutoAttackScale = 0.60,
  hitTaken = { trauma = 0.38, zoom = 0.25, fov = 0.80, pitch = 0.50, duration = 0.34, attack = 0.12 },
  combatEntry = { trauma = 0.12, zoom = 0.65, fov = 2.80, pitch = 0, duration = 0.60, attack = 0.50 },
  landing = { trauma = 0.10, zoom = -0.10, fov = 0, pitch = -0.30, duration = 0.32, attack = 0.15 },
  landingHeavy = { trauma = 0.45, zoom = -0.30, fov = -1.0, pitch = -1.40, duration = 0.52, attack = 0.14 },

  -- Impact micro-freezes: a hit impulse snaps to its peak and holds while the
  -- rest of the camera (shake, steps, drift, springs) pauses for a few frames.
  -- The game itself cannot be paused, so the freeze lives in the camera.
  hitstopLight = 0, -- seconds
  hitstopHeavy = 0,

  -- Speed drag: the camera trails further and widens as ground speed rises,
  -- with spring lag so acceleration and braking are felt.
  dragZoomPerYard = 0.08, -- zoom per yard/second above walking speed
  dragZoomMax = 1.20,
  dragFovPerYard = 0.30,
  dragFovMax = 3.0,
  dragSmoothTime = 0.70, -- seconds

  -- Look-ahead (leading offset): the frame leads into turns and strafes,
  -- opening space on the side the character is heading to.
  leadTurn = 0.22, -- shoulder per radian/second of turning
  leadStrafe = 0.45, -- shoulder at full strafing speed
  leadMax = 0.60,
  leadSmoothTime = 0.90,

  -- Rule of thirds: dynamic zoom and FOV changes rescale the shoulder offset
  -- so the character keeps its place on the frame instead of drifting.

  -- Rubber band: beyond the horde threshold each extra attacker stretches the
  -- frame further; it stretches quickly and relaxes slowly.
  rubberZoomPerEnemy = 0.70,
  rubberFovPerEnemy = 0.50,
  rubberMaxEnemies = 8,
  rubberStretchTime = 0.90,
  rubberRelaxTime = 2.20,

  -- Lock-on (Z-targeting): Key Bindings > AddOns > Mythic View, or /mv lock.
  lockYaw = 1.0,
  lockPitch = 0.70,
  lockZoom = 0.80,
  -- Target tracking ramps focus strength in and out instead of snapping.
  -- DynamicCam-style: the engine focus is eased in slowly, eased out even
  -- slower, and only switched off once it has faded to nothing.
  focusAcquireTime = 0.90,
  focusReleaseTime = 1.30,
  focusMovingScale = 0.75, -- while moving, look-ahead wins over the target
  focusClosePitchScale = 0.65, -- close targets: do not stare at the floor

  -- Boundary limits for the composed camera.
  minZoom = 1.0,
  maxZoom = 39,
  maxPitchOffset = 3.0, -- degrees
  maxShoulder = 6.0,

  -- Engine-side collision and follow. WoW runs its own camera raycasts; these
  -- are the controls it exposes. Each group is a menu toggle; disabling it
  -- (or logging out) restores the player's original values.
  collision = {
    cameraIndirectVisibility = 1, -- thin geometry passes instead of snapping in
    cameraIndirectOffset = 6, -- obstruction tolerance before pulling in (1-10)
    occludedSilhouettePlayer = 1, -- draw the character through occluders
  },
  follow = {
    cameraSmoothStyle = 1, -- trail horizontally behind the character while moving
    cameraYawSmoothSpeed = 120, -- lazier follow swing (WoW default 180)
    cameraPitchSmoothSpeed = 45,
  },
  -- Engine-driven tilt that lowers the character in frame as the camera pulls
  -- back. Used by the Darksiders style.
  dynamicPitch = {
    test_cameraDynamicPitch = 1,
  },
}

-- A long smootherstep keeps the camera weighty instead of mechanical.
local TRANSITION_DURATION = 1.00
-- FOV is more noticeable than camera distance, so let it breathe a little longer.
local FOV_TRANSITION_DURATION = 1.40
-- Returning from a walking camera to the close idle frame needs extra settle
-- time; otherwise the large distance change reads like a mouse-wheel snap.
local MOVEMENT_RETURN_DURATION = 1.70
local MOVEMENT_RETURN_FOV_DURATION = 1.90
-- A shoulder handoff crosses the character's centre line, so it needs a softer
-- curve and longer settle than ordinary profile changes.
local SHOULDER_SWAP_DURATION = 1.80
-- A small temporary FOV contraction during camera travel suggests motion
-- without changing any profile's final framing.
local ZOOM_TRANSITION_FOV_DIP = 1.20
local CLOSE_TARGET_DISTANCE = 8
-- Keep the close-combat composition until the target has clearly moved away.
local CLOSE_TARGET_RELEASE_DISTANCE = 10
-- Context changes do not need a 60 Hz poll. Keep the camera frame-accurate,
-- but sample stable gameplay state at a calmer cadence.
local PROFILE_POLL_INTERVAL = 0.25
local MOTION_UPDATE_INTERVAL = 1 / 30
-- While animating the camera updates every frame (see K.CAMERA_BUSY_INTERVAL);
-- at rest (nothing animating but the barely visible breathing) it needs far fewer.
-- While animating, the camera updates at half the player's frame rate (they
-- cannot see more than that in a CVar-driven move), clamped to a sane range.
local CAMERA_IDLE_INTERVAL = 1 / 20
local MOTION_IDLE_INTERVAL = 1 / 10
-- Manual mouse-wheel zoom is allowed; restore the contextual framing after idle time.
local MANUAL_ZOOM_RETURN_DELAY = 2.50
local EPSILON = 0.05 -- Smallest reliable camera-zoom increment.
local FOV_EPSILON = 0.05
local FOV_MIN, FOV_MAX = 50, 90
-- Pitch tracking: feed-forward plus a proportional correction, rate-limited.
local PITCH_CORRECTION = 12
local PITCH_MAX_RATE = 80
local MAX_IMPULSES = 6
-- Crowd framing upgrades at once but releases only after the count stays low,
-- so a mob briefly switching target does not pump the camera.
local CROWD_COUNT = 2
local HORDE_COUNT = 4
local CROWD_RELEASE_DELAY = 1.50
-- Hit confirmation: a cast is a hit only once the target actually takes damage.
local HIT_CONFIRM_WINDOW = 1.20
-- Used only until the first UNIT_COMBAT arrives (e.g. if it is unavailable).
local HIT_FALLBACK_DELAY = 0.20
local HIT_COOLDOWN = 0.12
local AUTO_ATTACK_HIT_COOLDOWN = 0.90
local HEAVY_CAST_TIME = 0.90
local HIT_TAKEN_COOLDOWN = 0.50
local HIT_TAKEN_SECRET_COOLDOWN = 0.80
local AUTO_ATTACK_SPELL_ID = 6603
local LANDING_MIN_FALL = 0.25
local LANDING_HEAVY_FALL = 1.75
-- Grouped constants (keeps the main chunk under Lua's 200-local limit).
local K = {}
K.CAMERA_BUSY_INTERVAL = 1 / 144 -- cap while the camera is animating
K.TARGET_FOCUS_DUEL_YAW_STRENGTH = 0.78
K.TARGET_FOCUS_DUEL_PITCH_STRENGTH = 0.46
K.TARGET_FOCUS_CROWD_YAW_STRENGTH = 0.30
K.TARGET_FOCUS_CROWD_PITCH_STRENGTH = 0.16
K.DEFAULT_VIEW_DISTANCE = 7
K.SKYRIDING_VIEW_DISTANCE = 10
K.SKYRIDING_DETAIL_ENABLE_SPEED = 45
K.SKYRIDING_DETAIL_DISABLE_SPEED = 35
-- Native ActionCam head movement. These on-foot values mirror the proven
-- DynamicCam setup: subtle body presence at rest and firmer movement weight.
K.HEAD_MOVEMENT_STANDING_STRENGTH = 0 -- idle animations would jolt the camera
K.HEAD_MOVEMENT_STRENGTH = 0.50
K.HEAD_MOVEMENT_DAMP_RATE = 10
K.HEAD_MOVEMENT_RANGE_SCALE = 5
K.HEAD_MOVEMENT_DEAD_ZONE = 0.05
K.MOUNT_HEAD_MOVEMENT_STANDING_STRENGTH = 0
K.MOUNT_HEAD_MOVEMENT_STRENGTH = 0.70
K.MOUNT_HEAD_MOVEMENT_DAMP_RATE = 10
K.MOUNT_HEAD_MOVEMENT_RANGE_SCALE = 18
K.MOUNT_HEAD_MOVEMENT_DEAD_ZONE = 0.04
local COMBAT_ENTRY_FALLBACK_DELAY = 0.45

K.BACKWARD_APPROACH_DELAY = 1.10
K.BACKWARD_SETTLE_DELAY = 2.15
K.BACKWARD_LIMIT_DELAY = 3.20
K.BACKWARD_REVEAL_DELAY = 4.55
K.FORWARD_SUSTAIN_DELAY = 2.25

local IsCurrentSpellByID = C_Spell and C_Spell.IsCurrentSpell or IsCurrentSpell
local abs, min, max, sin, cos, sqrt, pi = math.abs, math.min, math.max, math.sin, math.cos, math.sqrt, math.pi
local floor, tan, rad = math.floor, math.tan, math.rad
local format = string.format
local TWO_PI = 2 * pi

-- Camera styles. Each reshapes the base profiles per context group and retunes
-- the feel layers; the menu sliders then scale on top.
--   foot: on-foot exploration and open-world combat
--   group: dungeons, raids and arenas
--   mount: mounted travel
local PRESETS = {
  ragnarok = {
    name = "God of War Ragnarök",
    description = "Tight over the right shoulder, with weighty impacts, hit-stop, and strong shake.",
    foot = { zoomScale = 1, zoomAdd = 0, fovAdd = 0 },
    group = { zoomScale = 1, zoomAdd = 0, fovAdd = 0 },
    mount = { zoomScale = 1, zoomAdd = 0, fovAdd = 0 },
    shoulderScale = 1, timeScale = 1,
    shake = 1, hitstop = 1, sway = 1, drag = 1, lead = 1, focus = 1,
    aimOnCast = false, dynamicPitch = false,
  },
  darksiders = {
    name = "Darksiders",
    description = "Higher and farther back, with a centered character, exaggerated impacts, and strong target focus.",
    foot = { zoomScale = 0.75, zoomAdd = 4.5, fovAdd = -6 },
    group = { zoomScale = 1, zoomAdd = 1.0, fovAdd = -2 },
    mount = { zoomScale = 1, zoomAdd = 0, fovAdd = -2 },
    shoulderScale = 0.12, timeScale = 0.85,
    shake = 1.25, hitstop = 1.3, sway = 0.5, drag = 0.6, lead = 0.5, focus = 1.15,
    aimOnCast = false, dynamicPitch = true,
  },
  horizon = {
    name = "Horizon Zero Dawn",
    description = "Right-shoulder, mid-distance framing with fluid movement, sprint pull-back, and aim while casting.",
    foot = { zoomScale = 0.9, zoomAdd = 1.0, fovAdd = -2 },
    group = { zoomScale = 1, zoomAdd = 0, fovAdd = 0 },
    mount = { zoomScale = 1, zoomAdd = 0, fovAdd = 0 },
    shoulderScale = 0.85, timeScale = 1.25,
    shake = 0.6, hitstop = 0.5, sway = 0.7, drag = 1.4, lead = 1.3, focus = 0.8,
    aimOnCast = true, dynamicPitch = false,
  },
  spacemarine = {
    name = "Warhammer 40K: Space Marine",
    description = "Wide shoulder offset and a low camera for a massive character, weighty transitions, sprint pull-back, and aim while casting.",
    foot = { zoomScale = 0.9, zoomAdd = 2.0, fovAdd = 2 },
    group = { zoomScale = 1, zoomAdd = 0.5, fovAdd = 1 },
    mount = { zoomScale = 1, zoomAdd = 0, fovAdd = 0 },
    shoulderScale = 1.15, timeScale = 1.10,
    shake = 1.1, hitstop = 0.8, sway = 1.2, drag = 1.25, lead = 0.9, focus = 0.9,
    aimOnCast = true, dynamicPitch = false,
  },
  witcher = {
    name = "The Witcher 3",
    description = "Higher and farther back, nearly centered, with slow, floaty movement and a downward view of the character.",
    foot = { zoomScale = 0.8, zoomAdd = 3.5, fovAdd = -3 },
    group = { zoomScale = 1, zoomAdd = 0.5, fovAdd = -1 },
    mount = { zoomScale = 1, zoomAdd = 1.0, fovAdd = -2 },
    shoulderScale = 0.30, timeScale = 1.30,
    shake = 0.5, hitstop = 0.4, sway = 0.6, drag = 0.8, lead = 0.7, focus = 0.9,
    aimOnCast = false, dynamicPitch = true,
  },
  eldenring = {
    name = "Elden Ring",
    description = "Mid-distance and nearly centered, with crisp transitions and strong enemy focus inspired by soulslike lock-on.",
    foot = { zoomScale = 0.8, zoomAdd = 2.5, fovAdd = -2 },
    group = { zoomScale = 1, zoomAdd = 0.5, fovAdd = -1 },
    mount = { zoomScale = 1, zoomAdd = 1.5, fovAdd = -1 },
    shoulderScale = 0.20, timeScale = 0.90,
    shake = 0.9, hitstop = 1.1, sway = 0.6, drag = 0.7, lead = 0.6, focus = 1.30,
    aimOnCast = false, dynamicPitch = false,
  },
  rdr2 = {
    name = "Red Dead Redemption 2",
    description = "Slow, weighty, and cinematic, with a distant mounted view and aim while casting, like Dead Eye.",
    foot = { zoomScale = 0.85, zoomAdd = 3.0, fovAdd = -4 },
    group = { zoomScale = 1, zoomAdd = 0.5, fovAdd = -2 },
    mount = { zoomScale = 1, zoomAdd = 2.5, fovAdd = -3 },
    shoulderScale = 0.55, timeScale = 1.40,
    shake = 0.6, hitstop = 0.5, sway = 0.8, drag = 0.9, lead = 0.8, focus = 0.85,
    aimOnCast = true, dynamicPitch = false,
  },
}
local PRESET_ORDER = { "ragnarok", "darksiders", "horizon", "spacemarine", "witcher", "eldenring", "rdr2" }

local SETTINGS_DEFAULTS = {
  preset = "ragnarok",
  zoomScale = 100,
  shakeIntensity = 100,
  stepSway = 100,
  hitImpacts = true,
  hitstop = true,
  breathing = true,
  verticalShake = false,
  speedDrag = true,
  lookAhead = true,
  composition = true,
  rubberBand = true,
  aimOnCast = false,
  smoothCollision = true,
  freeFollow = false,
}

-- Live settings; replaced by MythicViewDB.settings at login.
local settings = {}
for key, value in pairs(SETTINGS_DEFAULTS) do settings[key] = value end

-- Effective tuning, derived from the style and the settings.
local tune = {}
local PROFILES = {}

local function GetProfileGroup(profileID)
  if profileID:find("^mounted") then return "mount" end
  if profileID == "dungeon" or profileID == "raid" or profileID == "arena"
      or profileID:find("Dungeon$") or profileID:find("Raid$") or profileID:find("Arena$") then
    return "group"
  end
  return "foot"
end

local function RebuildTuning()
  local preset = PRESETS[settings.preset] or PRESETS.ragnarok
  tune.shake = preset.shake * settings.shakeIntensity / 100
  tune.hits = settings.hitImpacts
  tune.hitstop = settings.hitstop and preset.hitstop or 0
  tune.sway = preset.sway * settings.stepSway / 100
  tune.drag = settings.speedDrag and preset.drag or 0
  tune.lead = settings.lookAhead and preset.lead or 0
  tune.focus = preset.focus
  tune.time = preset.timeScale
  tune.vertical = settings.verticalShake
  tune.breathing = settings.breathing
  if not FEEL.shakesEnabled then
    tune.shake, tune.hits, tune.hitstop, tune.sway = 0, false, 0, 0
    tune.vertical, tune.breathing = false, false
  end
  tune.composition = settings.composition
  tune.rubber = settings.rubberBand
  tune.aim = settings.aimOnCast
  tune.dynamicPitch = preset.dynamicPitch

  local zoomScale = settings.zoomScale / 100
  for profileID, base in pairs(BASE_PROFILES) do
    local shape = preset[GetProfileGroup(profileID)]
    local profile = PROFILES[profileID] or {}
    profile.zoom = max(1, (base.zoom * shape.zoomScale + shape.zoomAdd) * zoomScale)
    profile.shoulder = base.shoulder * preset.shoulderScale
    profile.fov = min(90, max(50, base.fov + shape.fovAdd))
    profile.transitionDuration = base.transitionDuration
      and base.transitionDuration * preset.timeScale
    profile.fovTransitionDuration = base.fovTransitionDuration
      and base.fovTransitionDuration * preset.timeScale
    PROFILES[profileID] = profile
  end
end
RebuildTuning()

local frame = CreateFrame("Frame")
local activeProfile
local activeShoulderTarget
local transition
local pollElapsed = 0
local motionUpdateElapsed = 0
local cameraUpdateElapsed = 0
local originalCVars = {}
local activeMountID
local activeMountScanned = false
local lastMountedState
local mountRefreshSerial = 0
local targetFocusEnabled
local taxiSuspended = false
local activeViewDistance
local closeTargetActive = false
local playerMoving = false
local playerMovingBackward = false
local playerMovingRight = false
local movementSampleElapsed = 0
local lastMovementX, lastMovementY, lastMovementInstance
local positionSpeed
local backwardMoveElapsed = 0
local backwardCameraStage = 0
local forwardMoveElapsed = 0
local forwardCameraStage = 0
local visibleNameplateUnits = {}
local attackerCount = 0
local crowdLevel = 0
local crowdLowerSince
local crowdCombatActive = false
local headMovementMode
local combatEntryPending = false
local combatEntryElapsed = 0
local profileRefreshPending = false
local azeritePresetPending = false
local azeritePresetAttempts = 0
local lockOn = false
local aiming = false
local ApplyCurrentProfile
local IsHighSpeedSkyriding

-- Composed camera state. The base layer is what the profile transition says;
-- the live camera is base plus every additive layer.
local cam = {
  ready = false,
  zoom = 0, zoomVelocity = 0, fov = 78, shoulder = 0,
  zoomOffset = 0, lastZoomOffset = 0, zoomSettled = true,
  zoomSpeed = 20, pitchMoveSpeed = 90,
  zoomPausedUntil = nil,
  pitchApplied = 0, pitchRate = 0, lastPitchTarget = 0,
  clock = 0,
  trauma = 0,
  impulses = {},
  sprint = 0,
  stepPhase = 0, stepEnvelope = 0,
  movementSpeed = 7,
  grounded = true, pitchAllowed = true, mounted = false,
  falling = false, fallStart = 0,
  effectScale = 1,
  freeze = 0,
  smoothSpeed = 0, speedVelocity = 0,
  lead = 0, leadVelocity = 0,
  turnRate = 0, lastFacing = nil, strafeSpeed = 0,
  rubber = 0, rubberVelocity = 0,
  lockZoom = 0, lockZoomVelocity = 0,
  focusYaw = 0, focusYawVelocity = 0,
  focusPitch = 0, focusPitchVelocity = 0,
  aim = 0, aimVelocity = 0,
}

-- Hit confirmation state.
local pendingHit
local pendingHitHeavy = false
local unitCombatSeen = false
local lastHitTime = 0
local lastAutoAttackHit = 0
local lastHitTakenTime = 0
local castStartTime
local castStartGUID

local CAMERA_CVARS = {
  "test_cameraOverShoulder",
  "cameraFov",
  "CameraKeepCharacterCentered",
  "CameraReduceUnexpectedMovement",
  "test_cameraTargetFocusEnemyEnable",
  "test_cameraTargetFocusEnemyStrengthYaw",
  "test_cameraTargetFocusEnemyStrengthPitch",
  "test_cameraHeadMovementStrength",
  "test_cameraHeadMovementStandingStrength",
  "test_cameraHeadMovementStandingDampRate",
  "test_cameraHeadMovementMovingStrength",
  "test_cameraHeadMovementMovingDampRate",
  "test_cameraHeadMovementFirstPersonDampRate",
  "test_cameraHeadMovementRangeScale",
  "test_cameraHeadMovementDeadZone",
  "graphicsViewDistance",
}

local function SetCVarNumber(name, value)
  SetCVar(name, format("%.3f", value), "MythicView")
end

-- Per-frame camera writes skip values that did not move since our last write.
-- Every SetCVar broadcasts CVAR_UPDATE to all addons, so redundant writes are
-- pure overhead. Comparing numbers first also avoids a string per frame.
local lastFrameCVarValues = {}

local function SetFrameCVarNumber(name, value, threshold)
  local last = lastFrameCVarValues[name]
  if last and abs(last - value) < threshold then return end
  lastFrameCVarValues[name] = value
  SetCVar(name, format("%.3f", value), "MythicView")
end

local function ResetFrameCVarCache()
  wipe(lastFrameCVarValues)
end

local selfZoom = false -- true while the addon itself calls CameraZoomIn/Out

local function StopZoomMovement()
  MoveViewInStop()
  MoveViewOutStop()
end

local function StopPitchMovement()
  MoveViewUpStop()
  MoveViewDownStop()
  cam.pitchRate = 0
end

local function Clamp(value, low, high)
  if value < low then return low end
  if value > high then return high end
  return value
end

-- Critically damped spring (Unity's SmoothDamp). Each layer eases with its
-- own time constant, so channels move asynchronously yet never overshoot.
-- It snaps once settled so a resting layer stops producing work.
local function SmoothDamp(current, target, velocity, smoothTime, dt)
  if dt <= 0 then return current, velocity end
  local omega = 2 / max(0.0001, smoothTime)
  local x = omega * dt
  local decay = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x)
  local change = current - target
  local temp = (velocity + omega * change) * dt
  local output = target + (change + temp) * decay
  local newVelocity = (velocity - omega * temp) * decay
  if abs(output - target) < 0.0005 and abs(newVelocity) < 0.001 then
    return target, 0
  end
  return output, newVelocity
end

-- 1D gradient (Perlin) noise: smooth and non-repeating, unlike layered sines.
local PERLIN_GRADIENTS = {}
do
  local seed = 1337
  for i = 0, 255 do
    seed = (seed * 16807) % 2147483647
    PERLIN_GRADIENTS[i] = seed / 2147483647 * 2 - 1
  end
end

local function Perlin(x)
  local cell = floor(x)
  local t = x - cell
  local i = cell % 256
  local g0 = PERLIN_GRADIENTS[i] * t
  local g1 = PERLIN_GRADIENTS[(i + 1) % 256] * (t - 1)
  local fade = t * t * t * (t * (t * 6 - 15) + 10)
  return (g0 + (g1 - g0) * fade) * 2
end

local function IsSkyriding()
  -- The mount cache survives take-off and landing; only a dismount (or a
  -- mount-display change, see RefreshMountProfileAfterStateSettles) clears it.
  -- Skyriding lands and takes off constantly, and each rescan walks the whole
  -- mount journal.
  if not IsMounted() then
    activeMountID = nil
    activeMountScanned = false
    return false
  end
  if not IsFlying() then return false end

  local getMountIDs = C_MountJournal and C_MountJournal.GetMountIDs or C_MountJournal_GetMountIDs
  local getMountInfo = C_MountJournal and C_MountJournal.GetMountInfoByID or C_MountJournal_GetMountInfoByID
  if not getMountIDs or not getMountInfo then return false end

  if activeMountID then
    local _, _, _, active = getMountInfo(activeMountID)
    if not active then
      activeMountID = nil
      activeMountScanned = false
    end
  end

  -- A mount absent from the journal (rare) would otherwise be rescanned on
  -- every poll; remember that the scan already came up empty.
  if not activeMountID and not activeMountScanned then
    activeMountScanned = true
    for _, mountID in pairs(getMountIDs()) do
      local _, _, _, active = getMountInfo(mountID)
      if active then
        activeMountID = mountID
        break
      end
    end
  end

  if not activeMountID then return false end

  -- The 13th mount-info return is true for Steady Flight. A flying mount
  -- without that flag is therefore using Skyriding/Dynamic Flight.
  local _, _, _, _, _, _, _, _, _, _, _, _, isSteadyFlight = getMountInfo(activeMountID)
  return not isSteadyFlight
end

-- Smootherstep: zero velocity and zero acceleration at both ends, so moves
-- start and stop without a jolt, and a mid-move peak of only 1.875x the
-- average speed. (The quintic in-out used before peaked at 5x; the game's
-- camera could not follow that burst, lagged, then overshot and bounced.)
local function EaseSmooth(progress)
  return progress * progress * progress * (progress * (progress * 6 - 15) + 10)
end

local function EaseSmoothVelocity(progress)
  local inverse = 1 - progress
  return 30 * progress * progress * inverse * inverse
end

local function EaseInOutSine(progress)
  return -(cos(pi * progress) - 1) / 2
end

local function IsReadableTrue(value)
  return not (issecretvalue and issecretvalue(value)) and value == true
end

local function IsReadableNumber(value)
  return not (issecretvalue and issecretvalue(value)) and type(value) == "number"
end

local function IsReadableString(value)
  return not (issecretvalue and issecretvalue(value)) and type(value) == "string"
end

local function IsTargetClose()
  if not UnitExists("target") or not UnitCanAttack("player", "target") then
    closeTargetActive = false
    return false
  end

  local px, py, pz, pInstance = UnitPosition("player")
  local tx, ty, tz, tInstance = UnitPosition("target")
  if IsReadableNumber(px) and IsReadableNumber(tx) and pInstance == tInstance then
    local dx, dy, dz = px - tx, py - ty, pz - tz
    local threshold = closeTargetActive
      and CLOSE_TARGET_RELEASE_DISTANCE or CLOSE_TARGET_DISTANCE
    closeTargetActive = dx * dx + dy * dy + dz * dz <= threshold * threshold
    return closeTargetActive
  end

  -- Position data is unavailable for a few units; the 10-yard interaction check
  -- is a safe fallback that keeps the close-combat profile responsive.
  closeTargetActive = IsReadableTrue(CheckInteractDistance("target", 3))
  return closeTargetActive
end

local function ResetMovementDirection()
  playerMovingBackward = false
  playerMovingRight = false
  movementSampleElapsed = 0
  lastMovementX, lastMovementY, lastMovementInstance = nil, nil, nil
  positionSpeed = nil
  cam.strafeSpeed = 0
  backwardMoveElapsed = 0
  backwardCameraStage = 0
  forwardMoveElapsed = 0
  forwardCameraStage = 0
end

local function UpdateMovementDirection(elapsed)
  if not playerMoving then
    return
  end

  movementSampleElapsed = movementSampleElapsed + elapsed
  if movementSampleElapsed < 0.10 then return end
  local sampleTime = movementSampleElapsed
  movementSampleElapsed = 0

  local x, y, _, instance = UnitPosition("player")
  local facing = GetPlayerFacing()
  if not IsReadableNumber(x) or not IsReadableNumber(y) or not IsReadableNumber(facing) then
    positionSpeed = nil
    return
  end

  if lastMovementX and lastMovementInstance == instance then
    local dx, dy = x - lastMovementX, y - lastMovementY
    -- Smoothed ground speed; it drives footstep cadence and sprint detection
    -- where GetUnitSpeed is unreadable.
    local sampleSpeed = sqrt(dx * dx + dy * dy) / sampleTime
    positionSpeed = positionSpeed and (positionSpeed * 0.5 + sampleSpeed * 0.5) or sampleSpeed
    -- Positive projection means travel in the facing direction; negative means
    -- backpedalling. The right vector is perpendicular to the facing vector.
    -- Ignore tiny samples created by position quantization.
    local forwardProjection = dx * cos(facing) + dy * sin(facing)
    local rightProjection = dx * sin(facing) - dy * cos(facing)
    cam.strafeSpeed = cam.strafeSpeed * 0.5 + rightProjection / sampleTime * 0.5
    local wasMovingBackward = playerMovingBackward
    local wasMovingRight = playerMovingRight
    if forwardProjection < -0.02 then
      playerMovingBackward = true
    elseif forwardProjection > 0.02 then
      playerMovingBackward = false
    end
    if rightProjection > 0.02 then
      playerMovingRight = true
    elseif rightProjection < -0.02 then
      playerMovingRight = false
    end
    if wasMovingBackward ~= playerMovingBackward
        or (FEEL.strafeShoulderSwap and wasMovingRight ~= playerMovingRight) then
      ApplyCurrentProfile()
    end
  end

  lastMovementX, lastMovementY, lastMovementInstance = x, y, instance
end

local function UpdateBackwardCameraStage(elapsed)
  if not playerMovingBackward then
    backwardMoveElapsed = 0
    backwardCameraStage = 0
    return
  end

  backwardMoveElapsed = backwardMoveElapsed + elapsed
  local nextStage = backwardMoveElapsed >= K.BACKWARD_REVEAL_DELAY and 4
    or (backwardMoveElapsed >= K.BACKWARD_LIMIT_DELAY and 3
      or (backwardMoveElapsed >= K.BACKWARD_SETTLE_DELAY and 2
        or (backwardMoveElapsed >= K.BACKWARD_APPROACH_DELAY and 1 or 0)))
  if nextStage ~= backwardCameraStage then
    backwardCameraStage = nextStage
    ApplyCurrentProfile()
  end
end

local function UpdateForwardCameraStage(elapsed)
  if not playerMoving or playerMovingBackward then
    forwardMoveElapsed = 0
    forwardCameraStage = 0
    return
  end

  forwardMoveElapsed = forwardMoveElapsed + elapsed
  if forwardCameraStage == 0 and forwardMoveElapsed >= K.FORWARD_SUSTAIN_DELAY then
    forwardCameraStage = 1
    ApplyCurrentProfile()
  end
end

local function SafeUnitIsUnit(unit, otherUnit)
  if type(unit) ~= "string" or type(otherUnit) ~= "string" then return false end

  local match = UnitIsUnit(unit, otherUnit)
  return IsReadableTrue(match)
end

local function IsEnemyTargetingPlayer(unit)
  if not IsReadableTrue(UnitExists(unit)) then return false end
  if not IsReadableTrue(UnitCanAttack("player", unit)) then return false end
  if not IsReadableTrue(UnitAffectingCombat(unit)) then return false end

  local targetUnit = unit .. "target"
  return IsReadableTrue(UnitExists(targetUnit)) and SafeUnitIsUnit(targetUnit, "player")
end

local function HasHostileTarget()
  return IsReadableTrue(UnitExists("target"))
    and IsReadableTrue(UnitCanAttack("player", "target"))
    and not IsReadableTrue(UnitIsDeadOrGhost("target"))
end

-- NAME_PLATE_UNIT_ADDED/REMOVED keep the set current. A full resync is only
-- needed after a loading screen or /reload, and once on combat entry as a
-- safety net, rather than on every attacker count.
local function RefreshVisibleNameplates()
  if not C_NamePlate or not C_NamePlate.GetNamePlates then return end

  wipe(visibleNameplateUnits)
  for _, plate in pairs(C_NamePlate.GetNamePlates()) do
    local unit = plate.namePlateUnitToken
      or (plate.UnitFrame and plate.UnitFrame.unit)
    if type(unit) == "string" then
      visibleNameplateUnits[unit] = true
    end
  end
end

local function ResetCrowd()
  attackerCount = 0
  crowdLevel = 0
  crowdLowerSince = nil
  crowdCombatActive = false
end

local function UpdateAttackerCount()
  if not UnitAffectingCombat("player") then
    ResetCrowd()
    return
  end

  local count = 0
  local targetCounted = false
  for unit in pairs(visibleNameplateUnits) do
    if IsEnemyTargetingPlayer(unit) then
      count = count + 1
      targetCounted = targetCounted or SafeUnitIsUnit(unit, "target")
      if count >= FEEL.rubberMaxEnemies then break end
    end
  end

  -- The current target can remain valid before its nameplate is added, or when
  -- nameplates are disabled. Count it once without double-counting it above.
  if count < FEEL.rubberMaxEnemies and not targetCounted and IsEnemyTargetingPlayer("target") then
    count = count + 1
  end
  attackerCount = count

  local level = count >= HORDE_COUNT and 2 or (count >= CROWD_COUNT and 1 or 0)
  if level >= crowdLevel then
    crowdLevel = level
    crowdLowerSince = nil
  else
    local now = GetTime()
    crowdLowerSince = crowdLowerSince or now
    if now - crowdLowerSince >= CROWD_RELEASE_DELAY then
      crowdLevel = level
      crowdLowerSince = nil
    end
  end
  crowdCombatActive = crowdLevel >= 1
end

local function SelectProfile()
  local _, instanceType = IsInInstance()

  if not UnitAffectingCombat("player") then
    closeTargetActive = false
    ResetCrowd()
    -- Check flying first: flying mounts are also reported as mounted.
    if IsSkyriding() then
      -- Keep one immutable camera profile through all glide/boost/turn states.
      -- High speed still controls only view distance below.
      return "mountedSkyriding", PROFILES.mountedSkyriding
    elseif IsFlying() then
      if playerMoving then
        return "mountedFlyingMoving", PROFILES.mountedFlyingMoving
      end
      return "mountedFlying", PROFILES.mountedFlying
    elseif IsMounted() then
      -- Indoor/group travel stays less distant than open-world travel.
      if instanceType == "party" then
        return "dungeon", PROFILES.dungeon
      end
      if playerMoving then
        if playerMovingBackward then
          return "mountedGroundBackward", PROFILES.mountedGroundBackward
        end
        return "mountedGroundMoving", PROFILES.mountedGroundMoving
      end
      return "mountedGround", PROFILES.mountedGround
    end

    local prefix
    if (IsResting() or IsIndoors()) and (not instanceType or instanceType == "none") then
      prefix = "indoors"
    elseif instanceType == "party" then
      return "dungeon", PROFILES.dungeon
    elseif instanceType == "raid" then
      return "raid", PROFILES.raid
    elseif instanceType == "arena" then
      return "arena", PROFILES.arena
    else
      prefix = "explore"
    end

    local hostileTarget = HasHostileTarget()
    local suffix
    if playerMoving then
      if playerMovingBackward then
        local stage = backwardCameraStage == 4 and "Reveal"
          or backwardCameraStage == 3 and "Limit"
          or backwardCameraStage == 2 and "Settle"
          or backwardCameraStage == 1 and "Approach"
          or ""
        suffix = (hostileTarget and "BackwardTarget" or "Backward") .. stage
      else
        suffix = (hostileTarget and "MovingTarget" or "Moving")
          .. (forwardCameraStage == 1 and "Sustain" or "")
      end
    else
      suffix = hostileTarget and "Target" or ""
    end
    local profileID = prefix .. suffix
    return profileID, PROFILES[profileID]
  end

  UpdateAttackerCount()
  local area = instanceType == "party" and "Dungeon"
    or instanceType == "raid" and "Raid"
    or instanceType == "arena" and "Arena"
    or "World"
  if crowdLevel == 2 then
    local profileID = "combatHorde" .. area
    return profileID, PROFILES[profileID]
  elseif crowdLevel == 1 then
    local profileID = "combatCrowd" .. area
    return profileID, PROFILES[profileID]
  end

  if IsTargetClose() then
    return "combatClose", PROFILES.combatClose
  end

  local profileID = "combat" .. area
  return profileID, PROFILES[profileID]
end

-- Profile categories are fixed, so classify every profile once at load instead
-- of pattern-matching its name on each evaluation.
local ON_FOOT_PROFILES = {}
local ON_FOOT_MOTION_PROFILES = {}
local SHOULDER_SWAP_PROFILES = {
  combatWorld = true,
  combatCrowdWorld = true,
  combatHordeWorld = true,
  combatClose = true,
}
local ON_FOOT_IDLE_PROFILES = {
  explore = true,
  exploreTarget = true,
  indoors = true,
  indoorsTarget = true,
}
for profileID in pairs(BASE_PROFILES) do
  if profileID:find("^explore") or profileID:find("^indoors") then
    ON_FOOT_PROFILES[profileID] = true
    SHOULDER_SWAP_PROFILES[profileID] = true
  end
  if profileID:find("^exploreMoving")
      or profileID:find("^exploreBackward")
      or profileID:find("^indoorsMoving")
      or profileID:find("^indoorsBackward") then
    ON_FOOT_MOTION_PROFILES[profileID] = true
  end
end

local function GetContextualShoulder(profileID, profile)
  -- Optional: right strafing moves the camera to the left shoulder so the
  -- travel direction stays open. Off by default to match Ragnarök.
  if FEEL.strafeShoulderSwap and playerMovingRight
      and SHOULDER_SWAP_PROFILES[profileID] and not IsMounted() then
    return -abs(profile.shoulder)
  end
  return profile.shoulder
end

local function InitializeCamera()
  cam.zoom = GetCameraZoom()
  cam.zoomCommanded = cam.zoom
  cam.fov = tonumber(GetCVar("cameraFov")) or 78
  cam.shoulder = tonumber(GetCVar("test_cameraOverShoulder")) or 0
  cam.zoomSpeed = tonumber(GetCVar("cameraZoomSpeed")) or 20
  cam.pitchMoveSpeed = tonumber(GetCVar("cameraPitchMoveSpeed")) or 90
  if cam.pitchMoveSpeed <= 0 then cam.pitchMoveSpeed = 90 end
  cam.ready = true
end

local function BeginTransition(profileID, profile)
  local targetShoulder = GetContextualShoulder(profileID, profile)
  if activeProfile == profileID and activeShoulderTarget == targetShoulder then return end
  if not cam.ready then InitializeCamera() end
  local previousProfile = activeProfile
  local previousShoulderTarget = activeShoulderTarget
  local isMovementReturn = ON_FOOT_IDLE_PROFILES[profileID]
    and previousProfile ~= nil and ON_FOOT_MOTION_PROFILES[previousProfile]
  local isShoulderSwap = previousProfile == profileID
    and previousShoulderTarget ~= nil
    and previousShoulderTarget ~= targetShoulder
  activeProfile = profileID
  activeShoulderTarget = targetShoulder
  cam.zoomSpeed = tonumber(GetCVar("cameraZoomSpeed")) or 20
  ResetFrameCVarCache()

  local duration = profile.transitionDuration
    or (isMovementReturn and MOVEMENT_RETURN_DURATION or TRANSITION_DURATION) * tune.time
  transition = {
    elapsed = 0,
    -- Start from the real camera minus whatever the effect layers add, so a
    -- profile change mid-shake continues without a jump.
    zoomStart = GetCameraZoom() - cam.zoomOffset,
    shoulderStart = cam.shoulder,
    shoulderTarget = targetShoulder,
    shoulderDuration = isShoulderSwap and SHOULDER_SWAP_DURATION * tune.time or duration,
    shoulderUsesSoftEase = isShoulderSwap,
    fovStart = cam.fov,
    duration = duration,
    fovDuration = profile.fovTransitionDuration
      or (isMovementReturn and MOVEMENT_RETURN_FOV_DURATION or FOV_TRANSITION_DURATION) * tune.time,
    profile = profile,
  }
  cam.zoomCommanded = GetCameraZoom()
  cam.zoomSettled = false
end

-- Base layer: advance the profile transition and publish its values.
local function UpdateBaseLayer(elapsed)
  local state = transition
  if not state then
    cam.zoomVelocity = 0
    return false
  end

  state.elapsed = state.elapsed + elapsed
  local profile = state.profile
  local normalizedTime = min(state.elapsed / state.duration, 1)
  local normalizedShoulderTime = min(state.elapsed / state.shoulderDuration, 1)
  local shoulderProgress = state.shoulderUsesSoftEase
    and EaseInOutSine(normalizedShoulderTime)
    or EaseSmooth(normalizedShoulderTime)
  local normalizedFovTime = min(state.elapsed / state.fovDuration, 1)
  local zoomTravel = profile.zoom - state.zoomStart

  cam.zoom = state.zoomStart + zoomTravel * EaseSmooth(normalizedTime)
  cam.zoomVelocity = normalizedTime < 1
    and zoomTravel * EaseSmoothVelocity(normalizedTime) / state.duration or 0
  cam.shoulder = state.shoulderStart
    + (state.shoulderTarget - state.shoulderStart) * shoulderProgress
  -- The sine envelope is zero at both ends: this is a visual travel cue only,
  -- never a change to the target FOV or to its existing transition timing.
  local zoomTransitionDip = abs(zoomTravel) > EPSILON
    and ZOOM_TRANSITION_FOV_DIP * sin(pi * normalizedTime) or 0
  cam.fov = state.fovStart + (profile.fov - state.fovStart) * EaseInOutSine(normalizedFovTime)
    - zoomTransitionDip

  if normalizedTime >= 1 and normalizedFovTime >= 1 and normalizedShoulderTime >= 1 then
    cam.zoom = profile.zoom
    cam.fov = profile.fov
    cam.shoulder = state.shoulderTarget
    cam.zoomVelocity = 0
    transition = nil
  end
  return normalizedTime < 1
end

-- Additive layers --------------------------------------------------------

local function AddTrauma(amount)
  cam.trauma = min(1, cam.trauma + amount * cam.effectScale * tune.shake)
end

-- Impacts breathe instead of snapping: longer, with a gentler rise.
local IMPULSE_SOFTEN = 1.45
local IMPULSE_MIN_ATTACK = 0.32

local function AddImpulse(spec, scale, hold)
  scale = (scale or 1) * cam.effectScale * tune.shake
  if scale <= 0 then return end
  hold = hold or 0
  local impulses = cam.impulses
  if #impulses >= MAX_IMPULSES then table.remove(impulses, 1) end
  impulses[#impulses + 1] = {
    elapsed = 0,
    hold = hold,
    duration = spec.duration * IMPULSE_SOFTEN + hold,
    attack = max(spec.attack, IMPULSE_MIN_ATTACK),
    zoom = spec.zoom * scale,
    fov = spec.fov * scale,
    pitch = spec.pitch * scale,
  }
  cam.trauma = min(1, cam.trauma + spec.trauma * scale)
end

-- Fast rise, softer settle: hits snap in and breathe out. An impulse with a
-- hold (micro-freeze) jumps straight to its peak, holds, then releases.
local function ImpulseEnvelope(impulse)
  local hold = impulse.hold
  if hold > 0 then
    if impulse.elapsed < hold then return 1 end
    local release = (impulse.elapsed - hold) / (impulse.duration - hold)
    return 0.5 * (1 + cos(pi * release))
  end
  local progress = impulse.elapsed / impulse.duration
  local attack = impulse.attack
  if progress < attack then
    return EaseInOutSine(progress / attack)
  end
  return 0.5 * (1 + cos(pi * (progress - attack) / (1 - attack)))
end

-- Two octaves of Perlin noise per channel; distant seeds decorrelate channels.
local function ShakeNoise(time, seed)
  local x = time * FEEL.shakeFrequency + seed
  return Perlin(x) * 0.7 + Perlin(x * 2.03 + 17.3) * 0.3
end

local function UpdateEffectLayers(elapsed)
  -- fovOffset holds sustained changes (drag, sprint, rubber band); fovKick
  -- holds transient juice (impulses, shake), applied after the sustained part
  -- is clamped so a kick still reads when the view is already at its widest.
  local zoomOffset, fovOffset, fovKick, shoulderOffset, pitchOffset = 0, 0, 0, 0, 0
  -- During a micro-freeze every continuous layer stops; only the impulses
  -- holding their peak keep real time.
  local fxElapsed = elapsed
  if cam.freeze > 0 then
    cam.freeze = cam.freeze - elapsed
    fxElapsed = 0
  end
  local clock = cam.clock + fxElapsed
  cam.clock = clock

  -- Impulses.
  local impulses = cam.impulses
  for i = #impulses, 1, -1 do
    local impulse = impulses[i]
    impulse.elapsed = impulse.elapsed + elapsed
    if impulse.elapsed >= impulse.duration then
      table.remove(impulses, i)
    else
      local envelope = ImpulseEnvelope(impulse)
      zoomOffset = zoomOffset + impulse.zoom * envelope
      fovKick = fovKick + impulse.fov * envelope
      if tune.vertical then
        pitchOffset = pitchOffset + impulse.pitch * envelope
      end
    end
  end

  -- Sprint pull-back and its handheld floor.
  local sprintTarget = 0
  if playerMoving and cam.grounded and not playerMovingBackward and not cam.mounted then
    if cam.movementSpeed >= FEEL.sprintSpeed then
      sprintTarget = 1
    elseif forwardCameraStage == 1 then
      sprintTarget = FEEL.sprintSustainWeight
    end
  end
  local sprint = cam.sprint
  if sprint ~= sprintTarget then
    local step = FEEL.sprintBlendRate * fxElapsed
    sprint = sprint < sprintTarget and min(sprintTarget, sprint + step) or max(sprintTarget, sprint - step)
    cam.sprint = sprint
  end
  if sprint > 0 then
    local eased = EaseInOutSine(sprint)
    zoomOffset = zoomOffset + FEEL.sprintZoom * eased
    fovOffset = fovOffset + FEEL.sprintFov * eased
  end

  -- Trauma shake.
  local trauma = max(cam.trauma, FEEL.sprintShakeFloor * sprint * tune.shake)
  if cam.trauma > 0 then
    cam.trauma = max(0, cam.trauma - FEEL.traumaDecay * fxElapsed)
  end
  if trauma > 0 then
    local shake = trauma * trauma
    if tune.vertical then
      pitchOffset = pitchOffset + FEEL.shakePitch * shake * ShakeNoise(clock, 0.0)
    end
    shoulderOffset = shoulderOffset + FEEL.shakeShoulder * shake * ShakeNoise(clock, 61.7)
    fovKick = fovKick + FEEL.shakeFov * shake * ShakeNoise(clock, 123.1)
  end

  -- Footsteps: cadence from real speed and a sway toward the planted foot
  -- across each pair of steps. The strike dip exists only as the opt-in
  -- vertical channel: rotating the camera per step reads as nodding, and its
  -- blind pitch drive fought the native head bob while running.
  local stepping = playerMoving and cam.grounded
  local envelope = cam.stepEnvelope
  if stepping and envelope < 1 then
    envelope = min(1, envelope + fxElapsed / FEEL.stepFadeIn)
  elseif not stepping and envelope > 0 then
    envelope = max(0, envelope - fxElapsed / FEEL.stepFadeOut)
  end
  cam.stepEnvelope = envelope
  if envelope > 0 then
    local mounted = cam.mounted
    local speed = cam.movementSpeed
    local rate = Clamp(speed / (mounted and FEEL.mountStride or FEEL.stepStride),
      FEEL.stepMinRate, FEEL.stepMaxRate)
    local phase = (cam.stepPhase + rate * fxElapsed) % 2
    cam.stepPhase = phase
    local runShare = Clamp((speed - FEEL.walkSpeed) / (FEEL.runSpeed - FEEL.walkSpeed), 0, 1)
    local swayWeight = mounted and 1 or (0.6 + 0.4 * runShare + 0.5 * sprint)
    shoulderOffset = shoulderOffset
      + FEEL.stepSway * tune.sway * swayWeight * envelope * sin(pi * phase) * cam.effectScale
    if tune.vertical then
      local amplitude = mounted and FEEL.stepMountPitch
        or FEEL.stepWalkPitch + (FEEL.stepRunPitch - FEEL.stepWalkPitch) * runShare
          + (FEEL.stepSprintPitch - FEEL.stepRunPitch) * sprint
      local strike = (1 + cos(TWO_PI * (phase % 1))) / 2
      pitchOffset = pitchOffset
        - amplitude * tune.sway * envelope * strike * strike * strike * cam.effectScale
    end
  end

  -- Speed drag: springs toward the current ground speed, so the camera
  -- falls behind on acceleration and catches up on braking.
  local dragTarget = (playerMoving and cam.grounded and not playerMovingBackward)
    and cam.movementSpeed or 0
  cam.smoothSpeed, cam.speedVelocity = SmoothDamp(cam.smoothSpeed, dragTarget,
    cam.speedVelocity, FEEL.dragSmoothTime, fxElapsed)
  local excess = cam.smoothSpeed - FEEL.walkSpeed
  if excess > 0 and tune.drag > 0 then
    zoomOffset = zoomOffset + min(FEEL.dragZoomMax, excess * FEEL.dragZoomPerYard) * tune.drag
    fovOffset = fovOffset + min(FEEL.dragFovMax, excess * FEEL.dragFovPerYard) * tune.drag
  end

  -- Look-ahead: lead into turns (facing changes clockwise when turning right)
  -- and strafes. Positive shoulder moves the character left on screen.
  local leadTarget = 0
  if not lockOn and playerMoving and cam.grounded then
    -- Small turns (mouse noise) are ignored; only deliberate turns lead.
    local turn = abs(cam.turnRate) > 0.6 and cam.turnRate or 0
    leadTarget = Clamp((-turn * FEEL.leadTurn
      + cam.strafeSpeed / FEEL.runSpeed * FEEL.leadStrafe) * tune.lead, -FEEL.leadMax, FEEL.leadMax)
  end
  cam.lead, cam.leadVelocity = SmoothDamp(cam.lead, leadTarget, cam.leadVelocity,
    FEEL.leadSmoothTime, fxElapsed)

  -- Rubber band: extra attackers beyond the horde threshold stretch the frame.
  local rubberTarget = tune.rubber and crowdLevel == 2
    and max(0, min(attackerCount, FEEL.rubberMaxEnemies) - HORDE_COUNT) or 0
  cam.rubber, cam.rubberVelocity = SmoothDamp(cam.rubber, rubberTarget, cam.rubberVelocity,
    rubberTarget > cam.rubber and FEEL.rubberStretchTime or FEEL.rubberRelaxTime, fxElapsed)
  if cam.rubber > 0 then
    zoomOffset = zoomOffset + cam.rubber * FEEL.rubberZoomPerEnemy
    fovOffset = fovOffset + cam.rubber * FEEL.rubberFovPerEnemy
  end

  -- Lock-on pulls back slightly so the target and the character both fit.
  cam.lockZoom, cam.lockZoomVelocity = SmoothDamp(cam.lockZoom, lockOn and FEEL.lockZoom or 0,
    cam.lockZoomVelocity, 0.5, fxElapsed)
  zoomOffset = zoomOffset + cam.lockZoom

  -- Aim: hard casts and channels push in over the shoulder (Horizon style).
  local aimTarget = (tune.aim and aiming and not cam.mounted) and 1 or 0
  cam.aim, cam.aimVelocity = SmoothDamp(cam.aim, aimTarget, cam.aimVelocity,
    aimTarget > cam.aim and FEEL.aimInTime or FEEL.aimOutTime, fxElapsed)
  local aimZoom, aimFov, aimShoulder = 0, 0, 0
  if cam.aim > 0 then
    aimZoom, aimFov, aimShoulder = FEEL.aimZoom * cam.aim, FEEL.aimFov * cam.aim, FEEL.aimShoulder * cam.aim
    zoomOffset = zoomOffset + aimZoom
    fovOffset = fovOffset + aimFov
  end

  -- Idle breathing: a slow lateral drift (and a tilt with vertical shake on).
  if tune.breathing and not playerMoving then
    local w = TWO_PI * FEEL.breathRate
    local breath = sin(clock * w) * 0.7 + sin(clock * w * 0.61 + 1.3) * 0.3
    shoulderOffset = shoulderOffset + FEEL.breathShoulder * breath
    if tune.vertical then
      pitchOffset = pitchOffset + FEEL.breathPitch * breath
    end
  end

  return zoomOffset, fovOffset, fovKick, shoulderOffset, pitchOffset, cam.lead,
    aimZoom, aimFov, aimShoulder
end

-- Drivers ----------------------------------------------------------------

-- Zoom is driven the way DynamicCam does it: open loop, through the game's own
-- CameraZoomIn/CameraZoomOut. We only ever send the change in the wanted
-- distance (never compare against GetCameraZoom each frame), so an idle camera
-- sends nothing and the engine's collision and smoothing cannot be fought.
--
-- The exception is a profile transition: there the zoom follows the curve with
-- the engine's own continuous movement (MoveViewIn/Out at the curve's velocity,
-- the way the early alpha did). Stepping a curve with many small
-- CameraZoomIn/Out chunks makes the engine restart its interpolation on each
-- chunk, which shows up as judder. The first frame after the curve ends hands
-- over to one open-loop correction for whatever residual is left.
local function DriveZoom(elapsed, curveActive, zoomOffset)
  local previousOffset = cam.lastZoomOffset or zoomOffset
  cam.lastZoomOffset = zoomOffset
  cam.zoomOffset = zoomOffset

  if cam.zoomPausedUntil then
    cam.zoomVelocityDriven = false
    return
  end

  local wanted = cam.zoom + zoomOffset

  if curveActive then
    local zoomSpeed = cam.zoomSpeed > 0 and cam.zoomSpeed or 20
    local velocity = cam.zoomVelocity + (zoomOffset - previousOffset) / max(elapsed, 1 / 240)
    local rate = abs(velocity) / zoomSpeed
    if rate < 0.001 then
      StopZoomMovement()
    elseif velocity > 0 then
      MoveViewInStop()
      MoveViewOutStart(rate)
    else
      MoveViewOutStop()
      MoveViewInStart(rate)
    end
    cam.zoomVelocityDriven = true
    cam.zoomCommanded = wanted
    cam.zoomSettled = false
    return
  end

  if cam.zoomVelocityDriven then
    cam.zoomVelocityDriven = false
    StopZoomMovement()
    cam.zoomCommanded = GetCameraZoom()
  end

  if not cam.zoomCommanded then cam.zoomCommanded = GetCameraZoom() end
  local delta = wanted - cam.zoomCommanded

  if abs(delta) < EPSILON then
    cam.zoomSettled = not transition
    return
  end
  cam.zoomSettled = false

  cam.zoomCommanded = wanted
  selfZoom = true
  if delta > 0 then
    CameraZoomOut(delta)
  else
    CameraZoomIn(-delta)
  end
  selfZoom = false
end

local function DrivePitch(elapsed, target)
  if not tune.vertical or not cam.pitchAllowed then
    if cam.pitchRate ~= 0 then StopPitchMovement() end
    cam.pitchApplied = 0
    cam.lastPitchTarget = 0
    return
  end

  target = target * FEEL.pitchScale
  -- Integrate what the engine applied since the last frame.
  cam.pitchApplied = cam.pitchApplied + cam.pitchRate * elapsed
  local dt = max(elapsed, 1 / 240)
  local feedForward = (target - cam.lastPitchTarget) / dt
  cam.lastPitchTarget = target
  local pitchError = target - cam.pitchApplied
  local rate = Clamp(feedForward + pitchError * PITCH_CORRECTION, -PITCH_MAX_RATE, PITCH_MAX_RATE)

  if abs(pitchError) < 0.004 and abs(feedForward) < 0.02 then
    if cam.pitchRate ~= 0 then StopPitchMovement() end
    return
  end

  if rate > 0 then
    MoveViewDownStop()
    MoveViewUpStart(rate / cam.pitchMoveSpeed)
  else
    MoveViewUpStop()
    MoveViewDownStart(-rate / cam.pitchMoveSpeed)
  end
  cam.pitchRate = rate
end

local function UpdateCamera(elapsed)
  if not cam.ready then return end

  local curveActive = UpdateBaseLayer(elapsed)
  local zoomOffset, fovOffset, fovKick, shoulderOffset, pitchOffset, shoulderLead,
    aimZoom, aimFov, aimShoulder = UpdateEffectLayers(elapsed)

  -- Boundary limits.
  zoomOffset = Clamp(cam.zoom + zoomOffset, FEEL.minZoom, FEEL.maxZoom) - cam.zoom
  pitchOffset = Clamp(pitchOffset, -FEEL.maxPitchOffset, FEEL.maxPitchOffset)
  local fov = Clamp(Clamp(cam.fov + fovOffset, FOV_MIN, FOV_MAX) + fovKick, FOV_MIN, FOV_MAX)

  -- Rule of thirds: the character's screen position is shoulder divided by
  -- (distance * tan(fov / 2)). Scale the framing part of the shoulder with
  -- the dynamic zoom and FOV so the composition holds; shake stays unscaled.
  -- Aiming is a deliberate reframe (push in, shift aside), so it is excluded
  -- from the compensation; otherwise the character would drift to centre.
  local shoulder = cam.shoulder + shoulderLead
  local framedZoom = zoomOffset - aimZoom
  local framedFov = Clamp(fov - aimFov, FOV_MIN, FOV_MAX)
  if tune.composition and cam.zoom > 0.5 and (framedZoom ~= 0 or framedFov ~= cam.fov) then
    local baseHalfFov = rad(Clamp(cam.fov, FOV_MIN, FOV_MAX)) / 2
    shoulder = shoulder * (cam.zoom + framedZoom) / cam.zoom
      * tan(rad(framedFov) / 2) / tan(baseHalfFov)
  end
  shoulder = Clamp(shoulder + aimShoulder + shoulderOffset, -FEEL.maxShoulder, FEEL.maxShoulder)

  SetFrameCVarNumber("cameraFov", fov, 0.003)
  SetFrameCVarNumber("test_cameraOverShoulder", shoulder, 0.002)
  DriveZoom(elapsed, curveActive, zoomOffset)
  DrivePitch(elapsed, pitchOffset)
end

-- Hits -------------------------------------------------------------------

local function FireHit(heavy, critical, scale)
  if not tune.hits then return end
  local now = GetTime()
  if now - lastHitTime < HIT_COOLDOWN then
    -- Rapid hits keep the shake alive without stacking push-ins.
    AddTrauma(0.08)
    return
  end
  lastHitTime = now
  local hold = ((heavy or critical) and FEEL.hitstopHeavy or FEEL.hitstopLight) * tune.hitstop
  AddImpulse(heavy and FEEL.hitHeavy or FEEL.hitLight, scale, hold)
  cam.freeze = max(cam.freeze, hold)
  if critical then AddTrauma(FEEL.hitCriticalTrauma) end
end

local function OnPlayerCastSucceeded(castGUID)
  local sameCast = castStartTime ~= nil and IsReadableString(castGUID)
    and castGUID == castStartGUID
  local castTime = sameCast and GetTime() - castStartTime or 0
  castStartTime, castStartGUID = nil, nil
  if not IsReadableTrue(UnitAffectingCombat("player")) then return end
  pendingHit = GetTime()
  -- Hard casts land like Ragnarök's heavy attacks; instants like light ones.
  pendingHitHeavy = castTime >= HEAVY_CAST_TIME
end

local function OnUnitCombat(unit, action, flagText, amount)
  local actionReadable = IsReadableString(action)
  if actionReadable and action ~= "WOUND" then return end

  if unit == "target" then
    unitCombatSeen = true
    local critical = IsReadableString(flagText)
      and (flagText == "CRITICAL" or flagText == "CRUSHING")
    if pendingHit then
      if GetTime() - pendingHit <= HIT_CONFIRM_WINDOW then
        FireHit(pendingHitHeavy, critical)
      end
      pendingHit = nil
    elseif not IsInGroup() and closeTargetActive
        and IsCurrentSpellByID and IsReadableTrue(IsCurrentSpellByID(AUTO_ATTACK_SPELL_ID)) then
      -- Solo melee: auto-attack swings land without a cast.
      local now = GetTime()
      if now - lastAutoAttackHit >= AUTO_ATTACK_HIT_COOLDOWN then
        lastAutoAttackHit = now
        FireHit(false, critical, FEEL.hitAutoAttackScale)
      end
    end
  elseif unit == "player" then
    if not tune.hits then return end
    local now = GetTime()
    local scale = 0.5
    local cooldown = HIT_TAKEN_SECRET_COOLDOWN
    local maxHealth = UnitHealthMax("player")
    if actionReadable and IsReadableNumber(amount) and IsReadableNumber(maxHealth) and maxHealth > 0 then
      local fraction = amount / maxHealth
      if fraction < 0.02 then return end
      scale = Clamp(0.35 + fraction * 6, 0.35, 1.30)
      cooldown = HIT_TAKEN_COOLDOWN
    end
    if now - lastHitTakenTime < cooldown then return end
    lastHitTakenTime = now
    AddImpulse(FEEL.hitTaken, scale)
  end
end

local function OnLanded(fallTime)
  if fallTime < LANDING_MIN_FALL then return end
  local severity = Clamp((fallTime - LANDING_MIN_FALL) / (LANDING_HEAVY_FALL - LANDING_MIN_FALL), 0, 1)
  local light, heavy = FEEL.landing, FEEL.landingHeavy
  local scale = IsMounted() and 0.5 or 1
  AddImpulse({
    trauma = light.trauma + (heavy.trauma - light.trauma) * severity,
    zoom = light.zoom + (heavy.zoom - light.zoom) * severity,
    fov = light.fov + (heavy.fov - light.fov) * severity,
    pitch = light.pitch + (heavy.pitch - light.pitch) * severity,
    duration = light.duration + (heavy.duration - light.duration) * severity,
    attack = light.attack,
  }, scale)
end

-- Context ----------------------------------------------------------------

-- Intelligent target tracking. WoW does not expose enemy positions to addons,
-- so framing zones are approximated through the native ActionCam target focus:
-- a soft bias in a duel, a light one in crowds, a hard track when locked on,
-- and weaker while moving so look-ahead keeps priority.
local function GetFocusStrength()
  if not HasHostileTarget() then return nil end
  if lockOn then return FEEL.lockYaw, FEEL.lockPitch end

  local yaw, pitch
  if crowdCombatActive then
    yaw, pitch = K.TARGET_FOCUS_CROWD_YAW_STRENGTH, K.TARGET_FOCUS_CROWD_PITCH_STRENGTH
  else
    yaw, pitch = K.TARGET_FOCUS_DUEL_YAW_STRENGTH, K.TARGET_FOCUS_DUEL_PITCH_STRENGTH
    if closeTargetActive then pitch = pitch * FEEL.focusClosePitchScale end
  end
  if playerMoving then
    yaw, pitch = yaw * FEEL.focusMovingScale, pitch * FEEL.focusMovingScale
  end
  return min(1, yaw * tune.focus), min(1, pitch * tune.focus)
end

local function UpdateTargetFocus(elapsed)
  local yawTarget, pitchTarget = GetFocusStrength()
  local hasTarget = yawTarget ~= nil
  if not hasTarget then yawTarget, pitchTarget = 0, 0 end

  if not targetFocusEnabled then
    if not hasTarget then return end
    -- Acquire softly: start from zero strength and ramp toward the target.
    targetFocusEnabled = true
    cam.focusYaw, cam.focusYawVelocity = 0, 0
    cam.focusPitch, cam.focusPitchVelocity = 0, 0
    lastFrameCVarValues.test_cameraTargetFocusEnemyStrengthYaw = nil
    lastFrameCVarValues.test_cameraTargetFocusEnemyStrengthPitch = nil
    SetFrameCVarNumber("test_cameraTargetFocusEnemyStrengthYaw", 0, 0.002)
    SetFrameCVarNumber("test_cameraTargetFocusEnemyStrengthPitch", 0, 0.002)
    SetCVar("test_cameraTargetFocusEnemyEnable", "1", "MythicView")
  end

  local smoothTime = hasTarget and FEEL.focusAcquireTime or FEEL.focusReleaseTime
  cam.focusYaw, cam.focusYawVelocity = SmoothDamp(cam.focusYaw, yawTarget,
    cam.focusYawVelocity, smoothTime, elapsed)
  cam.focusPitch, cam.focusPitchVelocity = SmoothDamp(cam.focusPitch, pitchTarget,
    cam.focusPitchVelocity, smoothTime, elapsed)
  SetFrameCVarNumber("test_cameraTargetFocusEnemyStrengthYaw", cam.focusYaw, 0.002)
  SetFrameCVarNumber("test_cameraTargetFocusEnemyStrengthPitch", cam.focusPitch, 0.002)

  -- Switch the engine feature off only after the fade-out has finished.
  if not hasTarget and cam.focusYaw == 0 and cam.focusPitch == 0 then
    targetFocusEnabled = nil
    SetCVar("test_cameraTargetFocusEnemyEnable", "0", "MythicView")
  end
end

local function SetLockOn(enabled)
  enabled = enabled and HasHostileTarget() or false
  if enabled == lockOn then return end
  lockOn = enabled
  if UIErrorsFrame then
    UIErrorsFrame:AddMessage(lockOn and "Mythic View: alvo travado" or "Mythic View: trava solta",
      0.85, 0.75, 0.55)
  end
end

function MythicView_ToggleLockOn()
  SetLockOn(not lockOn)
end

BINDING_HEADER_MYTHICVIEW = "Mythic View"
BINDING_NAME_MYTHICVIEW_LOCKON = "Travar/soltar alvo (lock-on)"

SLASH_MYTHICVIEW1 = "/mv"
SLASH_MYTHICVIEW2 = "/mythicview"
SlashCmdList.MYTHICVIEW = function(message)
  local command = (message or ""):lower():match("^%s*(.-)%s*$")
  if command == "lock" then
    MythicView_ToggleLockOn()
  elseif ns.OpenOptions then
    ns.OpenOptions()
  else
    print("|cffd9bf8cMythic View|r: /mv — menu, /mv lock — travar/soltar o alvo atual.")
  end
end

local function GetSkyridingForwardSpeed()
  if not C_PlayerInfo or not C_PlayerInfo.GetGlidingInfo then return false end

  local isGliding, _, forwardSpeed = C_PlayerInfo.GetGlidingInfo()
  if not isGliding then return false end

  return forwardSpeed or 0
end

IsHighSpeedSkyriding = function()
  local forwardSpeed = GetSkyridingForwardSpeed()
  if not forwardSpeed then return false end

  -- Hysteresis avoids toggling view distance repeatedly around one speed.
  local threshold = activeViewDistance == K.SKYRIDING_VIEW_DISTANCE
    and K.SKYRIDING_DETAIL_DISABLE_SPEED or K.SKYRIDING_DETAIL_ENABLE_SPEED
  return forwardSpeed >= threshold
end

local function IsSkyridingProfile(profileID)
  return profileID == "mountedSkyriding" or profileID == "mountedSkyridingMoving"
end

local function UpdateViewDistance(profileID)
  local desiredDistance = IsSkyridingProfile(profileID) and IsHighSpeedSkyriding()
    and K.SKYRIDING_VIEW_DISTANCE or K.DEFAULT_VIEW_DISTANCE

  if activeViewDistance == desiredDistance then return end
  activeViewDistance = desiredDistance
  SetCVarNumber("graphicsViewDistance", desiredDistance)
end

local function IsGroundMountProfile(profileID)
  return profileID == "mountedGroundMoving" or profileID == "mountedGroundBackward"
end

local function UpdateHeadMovement(profileID)
  local mode
  if not IsReadableTrue(UnitAffectingCombat("player")) then
    if IsGroundMountProfile(profileID) then
      mode = "mount"
    elseif ON_FOOT_PROFILES[profileID] then
      mode = "walk"
    end
  end
  if mode == headMovementMode then return end
  headMovementMode = mode

  if mode then
    local isMount = mode == "mount"
    SetCVar("test_cameraHeadMovementStrength", "1", "MythicView")
    SetCVarNumber("test_cameraHeadMovementStandingStrength", isMount
      and K.MOUNT_HEAD_MOVEMENT_STANDING_STRENGTH or K.HEAD_MOVEMENT_STANDING_STRENGTH)
    SetCVarNumber("test_cameraHeadMovementStandingDampRate", isMount
      and K.MOUNT_HEAD_MOVEMENT_DAMP_RATE or K.HEAD_MOVEMENT_DAMP_RATE)
    SetCVarNumber("test_cameraHeadMovementMovingStrength", isMount
      and K.MOUNT_HEAD_MOVEMENT_STRENGTH or K.HEAD_MOVEMENT_STRENGTH)
    SetCVarNumber("test_cameraHeadMovementMovingDampRate", isMount
      and K.MOUNT_HEAD_MOVEMENT_DAMP_RATE or K.HEAD_MOVEMENT_DAMP_RATE)
    SetCVarNumber("test_cameraHeadMovementFirstPersonDampRate", 20)
    SetCVarNumber("test_cameraHeadMovementRangeScale", isMount
      and K.MOUNT_HEAD_MOVEMENT_RANGE_SCALE or K.HEAD_MOVEMENT_RANGE_SCALE)
    SetCVarNumber("test_cameraHeadMovementDeadZone", isMount
      and K.MOUNT_HEAD_MOVEMENT_DEAD_ZONE or K.HEAD_MOVEMENT_DEAD_ZONE)
  else
    SetCVar("test_cameraHeadMovementStrength", "0", "MythicView")
  end
end

local function UpdateEffectScale()
  local _, instanceType = IsInInstance()
  cam.effectScale = instanceType == "raid" and FEEL.raidScale
    or (instanceType == "party" and FEEL.partyScale or 1)
end

ApplyCurrentProfile = function()
  if taxiSuspended then return end
  local profileID, profile = SelectProfile()
  UpdateViewDistance(profileID)
  UpdateHeadMovement(profileID)
  BeginTransition(profileID, profile)
end

local function RefreshMountProfileAfterStateSettles()
  -- Skyriding can fire PLAYER_MOUNT_DISPLAY_CHANGED before IsMounted()/IsFlying()
  -- report their final values. Defer one short frame window, then force a fresh
  -- transition from the actual current FOV.
  mountRefreshSerial = mountRefreshSerial + 1
  local serial = mountRefreshSerial
  activeMountID = nil
  activeMountScanned = false

  C_Timer.After(0.15, function()
    if serial ~= mountRefreshSerial then return end
    activeMountID = nil
    activeMountScanned = false
    activeProfile = nil
    ApplyCurrentProfile()
  end)
end

-- Ground/air state sampled at the motion cadence: footsteps, landing and
-- whether pitch effects are safe (pitch steers flight and swimming).
local function UpdateGroundState(elapsed)
  local facing = GetPlayerFacing()
  if IsReadableNumber(facing) then
    if cam.lastFacing and elapsed > 0 then
      local delta = facing - cam.lastFacing
      if delta > pi then
        delta = delta - TWO_PI
      elseif delta < -pi then
        delta = delta + TWO_PI
      end
      cam.turnRate = cam.turnRate * 0.85 + delta / elapsed * 0.15
    end
    cam.lastFacing = facing
  else
    cam.lastFacing = nil
    cam.turnRate = 0
  end

  local flying = IsFlying()
  local swimming = IsSwimming()
  local falling = IsFalling()
  cam.mounted = IsMounted()
  local onTaxi = UnitOnTaxi("player")
  local inVehicle = UnitInVehicle("player")

  cam.pitchAllowed = not flying and not swimming and not onTaxi and not inVehicle
  cam.grounded = not flying and not swimming and not falling and not onTaxi and not inVehicle

  if falling and not cam.falling then
    cam.fallStart = GetTime()
  elseif not falling and cam.falling and not flying and not swimming then
    OnLanded(GetTime() - cam.fallStart)
  end
  cam.falling = falling

  if playerMoving then
    local speed = GetUnitSpeed and GetUnitSpeed("player")
    if IsReadableNumber(speed) and speed > 0 then
      cam.movementSpeed = speed
    elseif positionSpeed then
      cam.movementSpeed = positionSpeed
    else
      cam.movementSpeed = cam.mounted and 14 or FEEL.runSpeed
    end
  end
end

local function OnManualZoom()
  if selfZoom or not cam.ready then return end
  cam.zoomPausedUntil = GetTime() + MANUAL_ZOOM_RETURN_DELAY
  StopZoomMovement()
end

local function SaveCameraSettings()
  for _, name in ipairs(CAMERA_CVARS) do
    originalCVars[name] = GetCVar(name)
  end

  -- These Blizzard accessibility options suppress the horizontal shoulder offset.
  -- They are restored on logout, exactly as they were before this addon loaded.
  SetCVar("CameraKeepCharacterCentered", "0", "MythicView")
  SetCVar("CameraReduceUnexpectedMovement", "0", "MythicView")

  -- Engine settings are applied by ApplyEngineSettings; remember originals.
  -- A CVar this client lacks stays nil and is never touched.
  for _, group in ipairs({ FEEL.collision, FEEL.follow, FEEL.dynamicPitch }) do
    for name in pairs(group) do
      originalCVars[name] = GetCVar(name)
    end
  end
end

local function SetEngineGroup(values, enabled)
  for name, value in pairs(values) do
    local original = originalCVars[name]
    if original ~= nil then
      SetCVar(name, enabled and tostring(value) or original, "MythicView")
    end
  end
end

local function ApplyEngineSettings()
  SetEngineGroup(FEEL.collision, settings.smoothCollision)
  SetEngineGroup(FEEL.follow, settings.freeFollow)
  SetEngineGroup(FEEL.dynamicPitch, tune.dynamicPitch)
end

local lastPresetID

-- Called on login and whenever the menu changes a value.
local function ApplySettings()
  if settings.preset ~= lastPresetID then
    local preset = PRESETS[settings.preset] or PRESETS.ragnarok
    if lastPresetID ~= nil and settings.aimOnCast ~= preset.aimOnCast then
      -- Switching style adopts that style's aim behaviour; the player can
      -- still override it afterwards.
      settings.aimOnCast = preset.aimOnCast
      if ns.RefreshOptionValue then ns.RefreshOptionValue("aimOnCast", preset.aimOnCast) end
    end
    lastPresetID = settings.preset
  end
  RebuildTuning()
  if not taxiSuspended then ApplyEngineSettings() end
  if cam.ready then
    activeProfile = nil
    ApplyCurrentProfile()
  end
end

local function LoadSettings()
  MythicViewDB.settings = MythicViewDB.settings or {}
  local saved = MythicViewDB.settings
  for key, value in pairs(SETTINGS_DEFAULTS) do
    if saved[key] == nil or type(saved[key]) ~= type(value) then saved[key] = value end
  end
  if not PRESETS[saved.preset] then saved.preset = SETTINGS_DEFAULTS.preset end
  settings = saved
end

ns.PRESETS = PRESETS
ns.PRESET_ORDER = PRESET_ORDER
ns.SETTINGS_DEFAULTS = SETTINGS_DEFAULTS
ns.SHAKES_ENABLED = FEEL.shakesEnabled
ns.GetSettings = function() return settings end
ns.ApplySettings = ApplySettings

local function RestoreCameraSettings()
  StopZoomMovement()
  StopPitchMovement()
  targetFocusEnabled = nil
  headMovementMode = nil
  activeShoulderTarget = nil
  activeViewDistance = nil
  for name, value in pairs(originalCVars) do
    if value ~= nil then
      SetCVar(name, value, "MythicView")
    end
  end
end

-- Flight-path taxis and Skyriding are driven by the game's own camera; every
-- layer here fights it. Hand the camera back untouched until the flight ends.
local SUSPEND_RESUME_DELAY = 1.5 -- Skyriding lands and takes off constantly
local suspendClearSince

local function ShouldSuspend()
  return UnitOnTaxi("player") or IsSkyriding() or GetSkyridingForwardSpeed() ~= false
end

local function SuspendForTaxi()
  suspendClearSince = nil
  taxiSuspended = true
  lockOn = false
  aiming = false
  RestoreCameraSettings()
  ResetFrameCVarCache()
end

local function ResumeFromTaxi()
  taxiSuspended = false
  SetCVar("CameraKeepCharacterCentered", "0", "MythicView")
  SetCVar("CameraReduceUnexpectedMovement", "0", "MythicView")
  ApplyEngineSettings()
  ResetFrameCVarCache()
  activeProfile = nil
  ApplyCurrentProfile()
end

local function SuppressActionCamWarning()
  -- ActionCam-backed CVars used for the shoulder and target-focus effects
  -- trigger Blizzard's experimental-camera confirmation on every reload.
  if GameEvent and GameEvent.UnregisterInternalEvent then
    GameEvent.UnregisterInternalEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
  else
    UIParent:UnregisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
  end
end

local AZERITE_CINEMATIC_PRESET_VERSION = 2

local function ApplyAzeriteCinematicPreset()
  -- This is a first-install handoff, not a permanent override of the user's
  -- Azerite preferences. If AzeriteUI is absent or has not adopted the small
  -- public integration API yet, Mythic View simply keeps its camera-only mode.
  local presetVersion = MythicViewDB and MythicViewDB.azeriteCinematicPresetVersion or 0
  if presetVersion >= AZERITE_CINEMATIC_PRESET_VERSION then
    return
  end

  local azerite = _G.AzeriteUI
  local api = azerite and azerite.API
  local applyPreset = api and api.ApplyMythicViewCinematicPreset
  if type(applyPreset) ~= "function" then return end

  local applied, reason = applyPreset()
  if applied then
    MythicViewDB.azeriteCinematicPresetApplied = true
    MythicViewDB.azeriteCinematicPresetVersion = AZERITE_CINEMATIC_PRESET_VERSION
    azeritePresetPending = false
    azeritePresetAttempts = 0
  elseif reason == "combat" then
    azeritePresetPending = true
  elseif reason == "not_ready" and azeritePresetAttempts < 6 then
    -- AzeriteUI can still be enabling individual modules just after login.
    -- Retry a few times instead of touching its internals or assuming timing.
    azeritePresetAttempts = azeritePresetAttempts + 1
    C_Timer.After(0.50, ApplyAzeriteCinematicPreset)
  end
end

-- Mouse-wheel zoom has no event, but the bindings call these functions; the
-- addon itself only zooms through MoveView, so every call here is the player.
if CameraZoomIn then hooksecurefunc("CameraZoomIn", OnManualZoom) end
if CameraZoomOut then hooksecurefunc("CameraZoomOut", OnManualZoom) end

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
-- Only the player's own casts drive impacts; an unfiltered registration fires
-- for every caster in a raid or dungeon.
frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
-- Aim state (Horizon style): any hard cast or channel in progress.
for _, castEvent in ipairs({ "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP" }) do
  frame:RegisterUnitEvent(castEvent, "player")
end
frame:RegisterUnitEvent("UNIT_COMBAT", "player", "target")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("PLAYER_UPDATE_RESTING")
frame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
frame:RegisterEvent("PLAYER_STARTED_MOVING")
frame:RegisterEvent("PLAYER_STOPPED_MOVING")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", function(_, event, unit, ...)
  if event == "UNIT_COMBAT" then
    -- High-frequency on a raid boss target: keep this path allocation-free.
    if unit == "target" and not pendingHit and IsInGroup() then
      unitCombatSeen = true
      return
    end
    OnUnitCombat(unit, ...)
    return
  elseif event == "UNIT_SPELLCAST_START" then
    local castGUID = ...
    if IsReadableString(castGUID) then
      castStartTime, castStartGUID = GetTime(), castGUID
    end
    aiming = true
    return
  elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
    aiming = true
    return
  elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED"
      or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
    aiming = false
    return
  elseif event == "PLAYER_LOGIN" then
    MythicViewDB = MythicViewDB or {}
    LoadSettings()
    SaveCameraSettings()
    ApplySettings()
    SuppressActionCamWarning()
    if ns.BuildOptions then
      local built, problem = pcall(ns.BuildOptions)
      if not built then
        print("|cffd9bf8cMythic View|r: menu unavailable (" .. tostring(problem) .. ")")
      end
    end
    lastMountedState = IsMounted()
    -- Retail may return a protected (secret) speed value here. Movement events
    -- below are safe and provide the only state this camera layer needs.
    playerMoving = false
    -- AzeriteUI finishes its own startup slightly after PLAYER_LOGIN. Defer the
    -- one-time preset so the public API can safely refresh its existing frames.
    C_Timer.After(1.50, ApplyAzeriteCinematicPreset)
    return
  elseif event == "PLAYER_LOGOUT" then
    RestoreCameraSettings()
    return
  elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
    -- This event can fire for display/animation refreshes while already
    -- mounted. The regular poll handles actual mount-state changes; avoid
    -- re-basing the camera during those harmless display updates.
    local mountedNow = IsMounted()
    if lastMountedState == nil or mountedNow ~= lastMountedState then
      lastMountedState = mountedNow
      RefreshMountProfileAfterStateSettles()
    end
    return
  elseif event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" then
    if type(unit) == "string" then
      visibleNameplateUnits[unit] = event == "NAME_PLATE_UNIT_ADDED" or nil
    end
    -- Nameplates only feed the in-combat attacker count. Pulls add many
    -- plates in one frame, so coalesce them into a single refresh next frame.
    if UnitAffectingCombat("player") then
      profileRefreshPending = true
    end
    return
  end

  if taxiSuspended then return end

  local triggerCombatEntry = false
  if event == "PLAYER_ENTERING_WORLD" then
    RefreshVisibleNameplates()
    UpdateEffectScale()
    cam.pitchMoveSpeed = tonumber(GetCVar("cameraPitchMoveSpeed")) or 90
    if cam.pitchMoveSpeed <= 0 then cam.pitchMoveSpeed = 90 end
  elseif event == "PLAYER_REGEN_DISABLED" then
    RefreshVisibleNameplates()
    combatEntryPending = true
    combatEntryElapsed = 0
  elseif event == "PLAYER_REGEN_ENABLED" then
    combatEntryPending = false
    combatEntryElapsed = 0
    pendingHit = nil
    if azeritePresetPending then
      ApplyAzeriteCinematicPreset()
    end
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    aiming = false
    if combatEntryPending then
      triggerCombatEntry = true
    else
      OnPlayerCastSucceeded((...))
    end
  elseif event == "PLAYER_STARTED_MOVING" then
    playerMoving = true
  elseif event == "PLAYER_STOPPED_MOVING" then
    playerMoving = false
    ResetMovementDirection()
  end
  ApplyCurrentProfile()
  if triggerCombatEntry then
    combatEntryPending = false
    AddImpulse(FEEL.combatEntry)
  end
end)

frame:SetScript("OnUpdate", function(_, elapsed)
  pollElapsed = pollElapsed + elapsed
  if taxiSuspended then
    if pollElapsed >= PROFILE_POLL_INTERVAL then
      pollElapsed = 0
      if ShouldSuspend() then
        suspendClearSince = nil
      else
        suspendClearSince = suspendClearSince or GetTime()
        if GetTime() - suspendClearSince >= SUSPEND_RESUME_DELAY then ResumeFromTaxi() end
      end
    end
    return
  end
  if pollElapsed >= PROFILE_POLL_INTERVAL then
    pollElapsed = 0
    if cam.ready and ShouldSuspend() then
      SuspendForTaxi()
      return
    end
    profileRefreshPending = false
    local mountedNow = IsMounted()
    if lastMountedState ~= nil and mountedNow ~= lastMountedState then
      lastMountedState = mountedNow
      RefreshMountProfileAfterStateSettles()
    end
    -- Another addon (or Blizzard) may have changed the FOV behind our back;
    -- drop the write cache so the composed value is written again.
    local lastFov = lastFrameCVarValues.cameraFov
    if lastFov then
      local liveFov = tonumber(GetCVar("cameraFov"))
      if liveFov and abs(liveFov - lastFov) > FOV_EPSILON then
        ResetFrameCVarCache()
      end
    end
    ApplyCurrentProfile()
  elseif profileRefreshPending then
    profileRefreshPending = false
    ApplyCurrentProfile()
  end

  if combatEntryPending then
    combatEntryElapsed = combatEntryElapsed + elapsed
    if combatEntryElapsed >= COMBAT_ENTRY_FALLBACK_DELAY then
      combatEntryPending = false
      AddImpulse(FEEL.combatEntry)
    end
  end

  if pendingHit then
    local age = GetTime() - pendingHit
    if not unitCombatSeen and age >= HIT_FALLBACK_DELAY then
      -- UNIT_COMBAT never arrived this session: fall back to cast timing.
      pendingHit = nil
      FireHit(pendingHitHeavy, false)
    elseif age > HIT_CONFIRM_WINDOW then
      pendingHit = nil
    end
  end

  -- True while any layer is still moving. Everything compared here snaps to an
  -- exact value once settled, so a resting camera reads as not busy.
  local busy = transition ~= nil or #cam.impulses > 0 or cam.trauma > 0 or cam.sprint ~= 0
    or cam.stepEnvelope > 0 or cam.aim ~= 0 or cam.rubber ~= 0 or cam.lockZoom ~= 0
    or cam.smoothSpeed ~= 0 or cam.lead ~= 0 or cam.freeze > 0 or cam.pitchRate ~= 0
    or not cam.zoomSettled or playerMoving or aiming or lockOn
  local motionInterval = (busy or targetFocusEnabled or cam.falling)
    and MOTION_UPDATE_INTERVAL or MOTION_IDLE_INTERVAL

  motionUpdateElapsed = motionUpdateElapsed + elapsed
  if motionUpdateElapsed >= motionInterval then
    local motionElapsed = motionUpdateElapsed
    motionUpdateElapsed = 0

    UpdateGroundState(motionElapsed)
    -- A lock ends when its target is gone or dead.
    if lockOn and not HasHostileTarget() then SetLockOn(false) end
    UpdateTargetFocus(motionElapsed)
    if playerMoving then
      UpdateMovementDirection(motionElapsed)
      UpdateBackwardCameraStage(motionElapsed)
      UpdateForwardCameraStage(motionElapsed)
    end

    -- Return to the contextual framing once the mouse wheel has been idle.
    if cam.zoomPausedUntil and GetTime() >= cam.zoomPausedUntil then
      cam.zoomPausedUntil = nil
      activeProfile = nil
      ApplyCurrentProfile()
    end
  end

  -- While anything moves, update on every rendered frame (capped at 144 Hz).
  -- Updating at half the frame rate, and resetting the accumulator, made the
  -- camera step every 2-3 frames unevenly, which reads as judder. The
  -- remainder is kept (modulo) so the cadence stays even above the cap.
  cameraUpdateElapsed = cameraUpdateElapsed + elapsed
  local cameraInterval = busy and K.CAMERA_BUSY_INTERVAL or CAMERA_IDLE_INTERVAL
  if cameraUpdateElapsed >= cameraInterval then
    local cameraElapsed = cameraUpdateElapsed
    cameraUpdateElapsed = busy and cameraUpdateElapsed % cameraInterval or 0
    UpdateCamera(cameraElapsed)
  end
end)
