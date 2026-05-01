# Changelog

## v0.1.7

- Improved menu bar microphone state readability with a stronger muted indicator (`mic.slash.fill`) and subtle muted tint for faster glance recognition.
- Stabilized status item width by using a fixed square slot to eliminate visible jumps when toggling mute/unmute.
- Added a dedicated status item presentation logic module and focused unit tests for muted symbol selection and visual-level mapping behavior.

## v0.1.6

- Improved popover readability and visual hierarchy with updated spacing and typography.
- Refined the global hotkey controls layout in settings for clearer actions.
- Updated mute action button behavior and presentation (`Mute`/`Unmute` labels and state-driven tint).
- Increased popover size to accommodate the updated two-tab interface and spacing.

## v0.1.5

- Replaced the standalone popover level progress bar with a single slider that acts as both indicator and control.
- Fixed slider jitter and post-release bounce by stabilizing slider commit flow in the view and suppressing transient backend reads after user writes.
- Added regression tests for optimistic slider updates and transient-read suppression after volume changes.

## v0.1.1

- Set app activation policy to accessory so the app runs as menu bar only.
- Added bundled app icon assets (`AppIcon.icns` + iconset) based on the selected filled microphone design.
- Updated release packaging script to include app icon resources and `LSUIElement` in generated `Info.plist`.
