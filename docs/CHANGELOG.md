# Changelog

## v0.1.5

- Replaced the standalone popover level progress bar with a single slider that acts as both indicator and control.
- Fixed slider jitter and post-release bounce by stabilizing slider commit flow in the view and suppressing transient backend reads after user writes.
- Added regression tests for optimistic slider updates and transient-read suppression after volume changes.

## v0.1.1

- Set app activation policy to accessory so the app runs as menu bar only.
- Added bundled app icon assets (`AppIcon.icns` + iconset) based on the selected filled microphone design.
- Updated release packaging script to include app icon resources and `LSUIElement` in generated `Info.plist`.
