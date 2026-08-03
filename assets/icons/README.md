# App Icons & Splash Screen Assets

## Placeholder SVGs

This directory contains SVG placeholders for app icons and splash screens.
Replace these with actual PNG assets before generating final builds.

## Generating Icons & Splash Screens

### Prerequisites

```bash
# Install the CLI tools
dart pub global activate flutter_launcher_icons
dart pub global activate flutter_native_splash
```

### Generate App Icons

```bash
# From project root
flutter pub run flutter_launcher_icons
```

This will generate:
- Android: mipmap-*/ic_launcher.png + adaptive icons
- iOS: AppIcon.appiconset/*
- Web: icons/icon-*.png in web/

### Generate Splash Screen

```bash
# From project root
flutter pub run flutter_native_splash:create
```

This will generate:
- Android: drawable*/launch_screen.xml + splash images
- iOS: LaunchScreen.storyboard + images
- Web: splash images in web/

## Asset Requirements

| Asset | Size | Format | Notes |
|-------|------|--------|-------|
| `app_icon.png` | 1024x1024 | PNG | Main app icon (no transparency for iOS) |
| `adaptive_background.png` | 1024x1024 | PNG | Android adaptive icon background |
| `adaptive_foreground.png` | 1024x1024 | PNG | Android adaptive icon foreground (with transparency) |
| `splash_icon.png` | 1024x1024 | PNG | Splash screen icon (centered, transparent background) |

## Color Reference

- Primary Brand: `#3F51B5` (RGB: 63, 81, 181)
- Brand Light: `#757DE8` (RGB: 117, 125, 232)
- Splash Background: `#3F51B5`

## Quick Start

1. Create your 1024x1024 PNG assets (use the SVGs as reference)
2. Place them in this directory:
   - `app_icon.png`
   - `adaptive_background.png` (solid brand color)
   - `adaptive_foreground.png` (icon with transparency)
   - `splash_icon.png` (icon with transparency)
3. Run the generation commands above
4. Verify on device/emulator

## Testing

```bash
# Test icons
flutter run --debug

# Test splash screen (cold start)
flutter run --release
```