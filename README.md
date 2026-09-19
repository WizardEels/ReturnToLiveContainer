# Return to LiveContainer

<div id="toc">
  <ul style="list-style: none">
    <summary>
      <h1> NOTE: THIS REPOSITORY IS VIDE-CODED! </h1>
    </summary>
  </ul>
</div>

A LiveContainer TweakLoader tweak that adds a draggable floating button to guest apps.

## Behaviour

- Circular Liquid Glass-style button.
- Uses `UIGlassEffect` on iOS 26+.
- Falls back to a system blur on older iOS versions.
- Starts fully visible.
- Fades to 20% opacity after 3 seconds of inactivity.
- Touching or dragging it restores full opacity.
- Drag it anywhere and release it to snap to the nearest left/right edge.
- Vertical position is preserved while snapping.
- Uses LiveContainer's `lcAppUrlScheme` helper when available.
- Falls back to `livecontainer://` for older builds.
- Does not install the overlay into LiveContainer's own process.

## Build on macOS with Theos

```sh
export THEOS=/path/to/theos
make package
```

The resulting package is in `packages/`.

## Build without a Mac

This repository includes `.github/workflows/build.yml`.

1. Create a GitHub repository.
2. Upload this project.
3. Open **Actions**.
4. Run **Build tweak**.
5. Download the `ReturnToLiveContainer` artifact.
6. Extract the `.deb`.
7. The tweak dylib is inside the package under the normal Theos library path.

## Installing in LiveContainer

LiveContainer's TweakLoader loads `.dylib` tweaks placed in its Tweaks folder, and LiveContainer's built-in tweak manager can sign imported tweaks.

Import the built dylib/package using LiveContainer's Tweak manager.

## Customisation

At the top of `Tweak.xm`:

```objc
static CGFloat const RTLCDiameter = 58.0;
static CGFloat const RTLCMargin = 10.0;
static NSTimeInterval const RTLCFadeDelay = 3.0;
static CGFloat const RTLCIdleAlpha = 0.20;
```

### Current design

The supplied reference image is used as the visual direction: a dark translucent circular control with a white curved return arrow.

The implementation uses the iOS system glass effect rather than embedding the supplied image into the tweak.

## Return behaviour

When pressed, the tweak opens LiveContainer using its exposed URL scheme and then exits the guest process after a short delay. Current LiveContainer releases document `livecontainer://` URL handling and expose the URL-scheme helper used by this tweak.

If a particular LiveContainer build does not accept the root URL, the fallback is to terminate the guest so LiveContainer can regain control through its normal termination flow.
