# Return to LiveContainer

A [LiveContainer](https://github.com/LiveContainer/LiveContainer) TweakLoader tweak that places a draggable Return button over guest apps.

### Note: This repository was made entirely by Codex (AI).

## Features

- Draggable circular Return control that snaps to the nearest screen edge similar to how the miniplayer works.
- High-contrast white return icon, border, and shadow for readability over bright content.
- Remembers its dragged position separately for each container across launches.
- Liquid Glass effect on iOS 26 when the system API is available, with a system-material fallback on earlier versions.
- Fades to 20% opacity after three seconds of inactivity, and touching it restores full opacity.
- Uses LiveContainer's built-in return/relaunch bridge. No additional apps or download required.

## Downloading a build

### Built version
You can download the latest version [here](https://github.com/WizardEels/ReturnToLiveContainer/releases/latest)
You can also download the nightly build [here](https://github.com/WizardEels/ReturnToLiveContainer/releases/tag/nightly). Be aware that it may have some bugs

### Actions
You can also run a build manually to download the `.dylib`:

1. Open the repository's **Actions** tab.
2. Select **Build tweak**.
3. Choose **Run workflow**.
4. When the workflow finishes, open that run and download the `ReturnToLiveContainer.dylib` artifact. Extract it to get `ReturnToLiveContainer.dylib`.

## Installing in LiveContainer

1. Download the `ReturnToLiveContainer.dylib` file.
2. Open the primary LiveContainer app and go to **Tweaks**.
3. Import `ReturnToLiveContainer.dylib` into either the global Tweaks folder or an app-specific tweak folder.
4. Assign the folder to a guest app if you're using an app-specific folder.
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

The finished dylib for LiveContainer import is at `.theos/_/Library/MobileSubstrate/DynamicLibraries/ReturnToLiveContainer.dylib`.

## Customisation

Edit these values near the top of [`Tweak.xm`](Tweak.xm):

```objc
static CGFloat const RTLCDiameter = 58.0; // Button diameter in points.
static BOOL const RTLCConfirmReturn = YES; // Set to NO to return immediately on tap.
static CGFloat const RTLCMargin = 10.0; // Gap between the button and safe-area edges in points.
static NSTimeInterval const RTLCFadeDelay = 3.0; // Seconds of inactivity before the button fades.
static CGFloat const RTLCIdleAlpha = 0.20; // Idle opacity from 0.0 (invisible) to 1.0 (fully opaque).
```

Set `RTLCConfirmReturn` to `NO` to skip the confirmation and return immediately on tap. The default, `YES`, shows the confirmation prompt.

Rebuild and re-import/re-sign the dylib after making a change.

## Compatibility notes

This project targets arm64 guest apps on iOS 15 and later. The iOS 26 glass API is looked up at runtime, so building with an older Theos SDK remains supported.

The Return action relies on LiveContainer's `LCSharedUtils` bridge. If a fork or older build does not expose that bridge, the tweak tries URL and scene-activation fallbacks, but its return behavior may be limited by that LiveContainer build.

## License

This project is distributed under the [MIT License](LICENSE).
