# Mythic View — Changelog

## 1.0.3 — Smooth camera (2026-10-05)

- Fixed the slight camera judder: while animating, the camera now updates on every rendered frame (up to 144 Hz). Previously, it updated at half the frame rate and reset the timer, producing uneven 2–3-frame steps.
- Profile transitions now drive zoom through the engine’s continuous movement (`MoveViewIn/Out`) at the easing curve’s velocity, instead of many short `CameraZoomIn/Out` steps, and apply a single correction when the curve ends.
- Idle cost is unchanged: when nothing is animating, the camera still updates infrequently.

The full history is in [CHANGELOG.md](CHANGELOG.md).
