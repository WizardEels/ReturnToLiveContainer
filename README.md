# Return to LiveContainer

A [LiveContainer](https://github.com/LiveContainer/LiveContainer) TweakLoader tweak that places a draggable Return button over guest apps.

## Note:
This repository was made entirely by Codex (AI).

## Features

- Draggable circular Return control that snaps to the nearest screen edge.
- Starts in the top-left safe-area corner and remembers its dragged position separately for each container across launches.
- Keeps the same side and proportional height when switching between portrait and landscape (for example, 3/4 down the left edge), with the arrow rotating with the interface.
- Liquid Glass effect on iOS 26 when the system API is available, with a system-material fallback on earlier versions.
- High-contrast white return icon, border, and shadow for readability over bright content.
- Fades to 20% opacity after three seconds of inactivity; touching it restores full opacity.
- Uses LiveContainer's built-in return/relaunch bridge, with URL-based fallbacks for older builds.

## Downloading a build

### Built version (.dylib only)
You can download the latest version [here](https://github.com/WizardEels/ReturnToLiveContainer/releases/latest)

### Actions
You can also run a build manually to download either the .dylib or the .deb:

1. Open the repository's **Actions** tab.
2. Select **Build tweak**.
3. Choose **Run workflow**.
4. When the workflow finishes, open that run and download one of its artifacts:
   - `ReturnToLiveContainer-dylib` — recommended for LiveContainer. It contains `ReturnToLiveContainer.dylib`.
   - `ReturnToLiveContainer` — the Debian (`.deb`) package for conventional Theos/jailbreak package installation.

## Installing in LiveContainer

1. Download the `ReturnToLiveContainer.dylib` file.
2. Open the primary LiveContainer app and go to **Tweaks**.
3. Import `ReturnToLiveContainer.dylib` into either the global Tweaks folder or an app-specific tweak folder.
4. Assign the folder to a guest app when using an app-specific folder.
5. Use LiveContainer's **Sign** action if the tweak manager does not automatically sign the imported dylib, then launch the guest app.

LiveContainer loads global tweaks into every guest app and supports app-specific tweak folders. Do not enable both **Don't Inject TweakLoader** and **Don't Load TweakLoader** for the guest app, since that disables tweak loading.

## Building locally on macOS

### Prerequisites

- Xcode Command Line Tools
- [Theos](https://theos.dev/docs/installation-macos) with an iPhoneOS SDK installed
- A shell environment with `THEOS` pointing at the Theos directory

```sh
git clone https://github.com/WizardEels/ReturnToLiveContainer.git
cd ReturnToLiveContainer
export THEOS="$HOME/theos" # Replace with your actual Theos directory.
make package FINALPACKAGE=1
```

The finished outputs are:

- `packages/*.deb` — installable Debian package.
- `.theos/_/Library/MobileSubstrate/DynamicLibraries/ReturnToLiveContainer.dylib` — dylib for LiveContainer import.

## Customisation

Edit these values near the top of [`Tweak.xm`](Tweak.xm):

```objc
static CGFloat const RTLCDiameter = 58.0;
static CGFloat const RTLCMargin = 10.0;
static NSTimeInterval const RTLCFadeDelay = 3.0;
static CGFloat const RTLCIdleAlpha = 0.20;
```

Rebuild and re-import/re-sign the dylib after making a change.

## Compatibility notes

This project targets arm64 guest apps on iOS 15 and later. The iOS 26 glass API is looked up at runtime, so building with an older Theos SDK remains supported.

The Return action relies on LiveContainer's `LCSharedUtils` bridge. If a fork or older build does not expose that bridge, the tweak tries URL and scene-activation fallbacks, but its return behavior may be limited by that LiveContainer build.

## License

This project is distributed under the [MIT License](LICENSE).
