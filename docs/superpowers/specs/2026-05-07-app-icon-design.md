# App Icon Design

## Goal

Create a new icon system for Mac Mic Widget that feels like a quiet native macOS utility while preserving the existing menu bar behavior.

## Direction

The approved direction is `System Capsule Mic`.

The app icon uses a light macOS-style rounded square, a centered graphite capsule microphone, and an integrated input-level meter. The level meter is part of the mark rather than a decorative add-on. The icon avoids slash, red warning color, and aggressive mute imagery so it does not imply that the microphone is always disabled.

## Layers

- `AppIcon`: new generated full-color raster source in `assets/AppIcon.source.png`, resized icon set in `assets/AppIcon.iconset`, plus regenerated `assets/AppIcon.icns`.
- Status bar: unchanged system-symbol layer using `mic.and.signal.meter.fill` and `mic.slash.and.signal.meter.fill` with template rendering and `variableValue`.

## Visual Requirements

- Light silver background with subtle depth.
- Graphite microphone shape with high contrast in small sizes.
- Meter bars integrated into the lower/right area of the central composition.
- No text in the icon.
- No status item width changes.
- No changes to microphone toggle behavior.

## Verification

- Generate all required iconset PNG sizes from `assets/AppIcon.source.png`.
- Regenerate `AppIcon.icns`.
- Check the 1024 px `icon_512x512@2x.png` output and small 16/32 px outputs visually.
- Run `make test`.
