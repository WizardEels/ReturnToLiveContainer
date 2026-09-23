#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <QuartzCore/QuartzCore.h>
#import <dlfcn.h>
#import <math.h>

#pragma mark - LiveContainer bridge

@interface NSUserDefaults (LiveContainerPrivate)
+ (instancetype)lcUserDefaults;
+ (instancetype)lcSharedDefaults;
+ (NSString *)lcAppUrlScheme;
+ (NSBundle *)lcMainBundle;
+ (NSDictionary *)guestAppInfo;
+ (NSDictionary *)guestContainerInfo;
+ (BOOL)isLiveProcess;
+ (NSString *)lcGuestAppId;
@end

#pragma mark - Configuration

static CGFloat const RTLCDiameter = 58.0;
static CGFloat const RTLCMargin = 10.0;
static NSTimeInterval const RTLCFadeDelay = 3.0;
static CGFloat const RTLCIdleAlpha = 0.20;
static CGFloat const RTLCActiveAlpha = 1.0;
static CGFloat const RTLCDragThreshold = 8.0;

#pragma mark - Overlay window

@class RTLCOverlayWindow;

#pragma mark - Button

@interface RTLCButton : UIButton
@property(nonatomic, weak) RTLCOverlayWindow *overlayWindow;
@property(nonatomic, assign) CGPoint touchStartPoint;
@property(nonatomic, assign) CGPoint buttonStartCenter;
@property(nonatomic, assign) BOOL dragging;
@property(nonatomic, assign) BOOL movedDuringTouch;
@property(nonatomic, assign) BOOL ignoreNextTap;
@property(nonatomic, strong) NSTimer *fadeTimer;
@property(nonatomic, strong) UIImageView *iconView;
@property(nonatomic, weak) UIAlertController *returnConfirmation;
@property(nonatomic, copy) NSString *positionPath;
@property(nonatomic, assign) BOOL positionOnRight;
@property(nonatomic, assign) CGFloat positionYFraction;
@property(nonatomic, assign) UIEdgeInsets positionSafeAreaInsets;
- (void)setAlpha:(CGFloat)alpha animated:(BOOL)animated;
- (void)restorePosition;
- (void)snapToNearestEdgeAnimated:(BOOL)animated;
@end

@interface RTLCOverlayWindow : UIWindow
@property(nonatomic, weak) RTLCButton *returnButton;
@end

@implementation RTLCOverlayWindow

// Keeping the guest window key prevents video players and other apps from
// treating an overlay drag as a loss of application focus.
- (BOOL)canBecomeKeyWindow {
    return NO;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    RTLCButton *button = self.returnButton;
    if (!button || button.hidden || button.alpha < 0.01) {
        return NO;
    }

    CGPoint localPoint = [button convertPoint:point fromView:self];
    return [button pointInside:localPoint withEvent:event];
}

@end

@implementation RTLCButton

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    // LiveContainer gives each guest data container its own home directory.
    // A dedicated file also avoids sharing app preference domains between containers.
    self.positionPath = [NSHomeDirectory() stringByAppendingPathComponent:
                         @"Library/Preferences/ReturnToLiveContainer.position.plist"];
    NSDictionary *position = [NSDictionary dictionaryWithContentsOfFile:self.positionPath];
    NSNumber *right = position[@"right"];
    NSNumber *fraction = position[@"yFraction"];
    if ([right isKindOfClass:NSNumber.class] &&
        [fraction isKindOfClass:NSNumber.class] && isfinite(fraction.doubleValue)) {
        self.positionOnRight = right.boolValue;
        self.positionYFraction = MAX(0.0, MIN(1.0, fraction.doubleValue));
    }
    // Zero-initialized position properties place new containers at the top left.

    self.backgroundColor = UIColor.clearColor;
    self.accessibilityLabel = @"Return to LiveContainer";
    self.accessibilityHint = @"Asks for confirmation before returning to the main LiveContainer app.";

    Class glassEffectClass = NSClassFromString(@"UIGlassEffect");
    SEL glassFactory = NSSelectorFromString(@"effectWithStyle:");
    if (glassEffectClass && [glassEffectClass respondsToSelector:glassFactory]) {
        // UIGlassEffect is absent from the iOS 15 build SDK. Resolve it at runtime
        // and verify its factory selector because early iOS 26 builds exposed an
        // incomplete class that otherwise crashes here.
        id glassEffect = ((id (*)(id, SEL, NSInteger))objc_msgSend)(glassEffectClass, glassFactory, 0);
        ((void (*)(id, SEL, id))objc_msgSend)(glassEffect,
                                               @selector(setTintColor:),
                                               [UIColor colorWithWhite:1.0 alpha:0.14]);
        ((void (*)(id, SEL, BOOL))objc_msgSend)(glassEffect, @selector(setInteractive:), YES);

        UIVisualEffectView *glassView = [[UIVisualEffectView alloc] initWithEffect:(UIVisualEffect *)glassEffect];
        glassView.frame = self.bounds;
        glassView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        glassView.userInteractionEnabled = NO;
        glassView.layer.cornerRadius = RTLCDiameter / 2.0;
        glassView.clipsToBounds = YES;
        [self insertSubview:glassView atIndex:0];
    } else {
        UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:
                                    [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial]];
        blur.frame = self.bounds;
        blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        blur.userInteractionEnabled = NO;
        blur.layer.cornerRadius = RTLCDiameter / 2.0;
        blur.clipsToBounds = YES;
        [self insertSubview:blur atIndex:0];
    }

    self.layer.cornerRadius = RTLCDiameter / 2.0;
    self.layer.borderWidth = 1.0;
    self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.55].CGColor;
    self.layer.shadowColor = UIColor.blackColor.CGColor;
    self.layer.shadowOpacity = 0.28;
    self.layer.shadowRadius = 8.0;
    self.layer.shadowOffset = CGSizeMake(0, 3.0);
    self.clipsToBounds = YES;

    UIImageSymbolConfiguration *symbolConfig =
        [UIImageSymbolConfiguration configurationWithPointSize:25.0 weight:UIImageSymbolWeightMedium];

    UIImage *image = [UIImage systemImageNamed:@"arrow.uturn.backward" withConfiguration:symbolConfig];
    if (!image) {
        image = [UIImage systemImageNamed:@"arrow.counterclockwise" withConfiguration:symbolConfig];
    }

    // Keep the symbol outside UIVisualEffectView. UIKit otherwise composites the
    // button image into the glass material on some guest apps, making it blurry.
    self.iconView = [[UIImageView alloc] initWithImage:[image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    self.iconView.frame = CGRectInset(self.bounds, 15.0, 15.0);
    self.iconView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconView.tintColor = UIColor.whiteColor;
    self.iconView.userInteractionEnabled = NO;
    self.iconView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.iconView.layer.shadowOpacity = 0.35;
    self.iconView.layer.shadowRadius = 2.0;
    self.iconView.layer.shadowOffset = CGSizeMake(0, 1.0);
    [self addSubview:self.iconView];

    [self addTarget:self action:@selector(buttonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [self addTarget:self action:@selector(buttonTouchUpInside:) forControlEvents:UIControlEventTouchUpInside];
    [self addTarget:self action:@selector(buttonTouchCancelled:) forControlEvents:UIControlEventTouchCancel | UIControlEventTouchUpOutside];

    [self resetFadeTimer];

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    for (UIView *view in self.subviews) {
        if ([view isKindOfClass:UIVisualEffectView.class]) {
            view.frame = self.bounds;
            view.layer.cornerRadius = self.bounds.size.width / 2.0;
        }
    }
    self.iconView.frame = CGRectInset(self.bounds, 15.0, 15.0);
}

- (void)buttonTouchDown:(UIButton *)sender {
    self.touchStartPoint = self.center;
    self.buttonStartCenter = self.center;
    self.dragging = NO;
    self.movedDuringTouch = NO;

    [self setAlpha:RTLCActiveAlpha animated:YES];
    [UIView animateWithDuration:0.14 animations:^{
        self.transform = CGAffineTransformMakeScale(0.92, 0.92);
    }];
    [self resetFadeTimer];
}

- (void)setAlpha:(CGFloat)alpha animated:(BOOL)animated {
    void (^changeAlpha)(void) = ^{
        self.alpha = alpha;
    };

    if (animated) {
        [UIView animateWithDuration:0.18 animations:changeAlpha];
    } else {
        changeAlpha();
    }
}

- (void)buttonTouchUpInside:(UIButton *)sender {
    [UIView animateWithDuration:0.18 animations:^{
        self.transform = CGAffineTransformIdentity;
    }];
    if (self.movedDuringTouch || self.ignoreNextTap) {
        self.ignoreNextTap = NO;
        [self resetFadeTimer];
        return;
    }

    [self confirmReturnToLiveContainer];
}

- (void)buttonTouchCancelled:(UIButton *)sender {
    [UIView animateWithDuration:0.18 animations:^{
        self.transform = CGAffineTransformIdentity;
    }];
    if (self.dragging || self.movedDuringTouch) {
        [self snapToNearestEdgeAnimated:YES];
    }

    [self resetFadeTimer];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = touches.anyObject;
    CGPoint point = [touch locationInView:self.superview];

    CGPoint original = [touch previousLocationInView:self.superview];
    CGFloat dx = point.x - original.x;
    CGFloat dy = point.y - original.y;

    if (!self.dragging) {
        CGPoint start = [touch locationInView:self.superview];
        CGFloat distance = hypot(start.x - self.touchStartPoint.x, start.y - self.touchStartPoint.y);

        if (distance > RTLCDragThreshold) {
            self.dragging = YES;
            self.movedDuringTouch = YES;
        }
    }

    if (self.dragging) {
        CGPoint center = self.center;
        center.x += dx;
        center.y += dy;

        CGRect bounds = self.superview.bounds;
        CGFloat half = self.bounds.size.width / 2.0;

        center.x = MAX(CGRectGetMinX(bounds) + half, MIN(CGRectGetMaxX(bounds) - half, center.x));
        center.y = MAX(CGRectGetMinY(bounds) + half, MIN(CGRectGetMaxY(bounds) - half, center.y));

        self.center = center;
        [self resetFadeTimer];
    }

    [super touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (self.dragging) {
        self.ignoreNextTap = YES;
        [self snapToNearestEdgeAnimated:YES];
    }

    [super touchesEnded:touches withEvent:event];
    [UIView animateWithDuration:0.18 animations:^{
        self.transform = CGAffineTransformIdentity;
    }];
    [self resetFadeTimer];
}

- (CGRect)positionBounds {
    // The placement view mirrors the guest's coordinates even when UIKit
    // does not rotate our non-key overlay window.
    UIView *container = self.superview;
    CGRect bounds = container.bounds;
    UIEdgeInsets safe = self.positionSafeAreaInsets;
    CGFloat half = self.bounds.size.width / 2.0;
    CGFloat leftX = CGRectGetMinX(bounds) + safe.left + half + RTLCMargin;
    CGFloat rightX = MAX(leftX, CGRectGetMaxX(bounds) - safe.right - half - RTLCMargin);
    CGFloat topY = CGRectGetMinY(bounds) + safe.top + half + RTLCMargin;
    CGFloat bottomY = MAX(topY, CGRectGetMaxY(bounds) - safe.bottom - half - RTLCMargin);
    return CGRectMake(leftX, topY, rightX - leftX, bottomY - topY);
}

- (void)restorePosition {
    if (!self.overlayWindow || self.dragging) return;
    CGRect bounds = [self positionBounds];
    self.center = CGPointMake(self.positionOnRight ? CGRectGetMaxX(bounds) : CGRectGetMinX(bounds),
                              CGRectGetMinY(bounds) + self.positionYFraction * CGRectGetHeight(bounds));
}

- (void)snapToNearestEdgeAnimated:(BOOL)animated {
    UIWindow *window = self.overlayWindow;
    if (!window) return;

    CGRect bounds = [self positionBounds];
    self.positionOnRight = self.center.x >= CGRectGetMidX(self.superview.bounds);
    CGPoint target = CGPointMake(self.positionOnRight ? CGRectGetMaxX(bounds) : CGRectGetMinX(bounds),
                                 MAX(CGRectGetMinY(bounds), MIN(CGRectGetMaxY(bounds), self.center.y)));
    self.positionYFraction = CGRectGetHeight(bounds) > 0.0
        ? (target.y - CGRectGetMinY(bounds)) / CGRectGetHeight(bounds) : 0.0;
    self.dragging = NO;

    // Write the destination immediately so returning to the host during the
    // animation cannot lose it. Store relative height to support rotation.
    NSDictionary *position = @{@"right": @(self.positionOnRight),
                               @"yFraction": @(self.positionYFraction)};
    NSError *error = nil;
    BOOL directoryReady = [NSFileManager.defaultManager
        createDirectoryAtPath:self.positionPath.stringByDeletingLastPathComponent
        withIntermediateDirectories:YES attributes:nil error:&error];
    if (!directoryReady || ![position writeToFile:self.positionPath atomically:YES]) {
        NSLog(@"[ReturnToLiveContainer] Could not save arrow position: %@", error ?: @"File write failed");
    }

    void (^animations)(void) = ^{
        self.center = target;
    };

    if (animated) {
        [UIView animateWithDuration:0.28
                              delay:0
             usingSpringWithDamping:0.82
              initialSpringVelocity:0.25
                            options:UIViewAnimationOptionBeginFromCurrentState |
                                    UIViewAnimationOptionAllowUserInteraction
                         animations:animations
                         completion:nil];
    } else {
        animations();
    }
}

- (void)resetFadeTimer {
    [self.fadeTimer invalidate];

    self.fadeTimer = [NSTimer scheduledTimerWithTimeInterval:RTLCFadeDelay
                                                       target:self
                                                     selector:@selector(fadeButton)
                                                     userInfo:nil
                                                      repeats:NO];
}

- (void)fadeButton {
    [UIView animateWithDuration:0.35
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionAllowUserInteraction |
                                UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.alpha = RTLCIdleAlpha;
    } completion:nil];
}

#pragma mark - Return action

- (void)confirmReturnToLiveContainer {
    if (self.returnConfirmation) return;

    // Present in the guest window: the overlay only accepts button touches
    // and cannot become key, so an alert in that window would not work.
    UIWindow *guestWindow = nil;
    for (UIWindow *candidate in self.overlayWindow.windowScene.windows) {
        if (candidate == self.overlayWindow || candidate.hidden || candidate.alpha == 0.0 ||
            !candidate.rootViewController) continue;
        if (candidate.isKeyWindow) {
            guestWindow = candidate;
            break;
        }
        if (!guestWindow && candidate.windowLevel == UIWindowLevelNormal) {
            guestWindow = candidate;
        }
    }
    UIViewController *presenter = guestWindow.rootViewController;
    while (presenter.presentedViewController) {
        presenter = presenter.presentedViewController;
    }
    if (!presenter.viewIfLoaded.window || presenter.isBeingDismissed || presenter.isBeingPresented) {
        [self resetFadeTimer];
        return;
    }

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Return to LiveContainer?"
        message:@"Are you sure you would like to return to LiveContainer?"
        preferredStyle:UIAlertControllerStyleAlert];
    __weak RTLCButton *weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel
        handler:^(UIAlertAction *action) {
            [weakSelf resetFadeTimer];
        }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Return" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *action) {
            [weakSelf returnToLiveContainer];
        }]];
    self.returnConfirmation = alert;
    [presenter presentViewController:alert animated:YES completion:nil];
}

- (void)returnToLiveContainer {
    [self.fadeTimer invalidate];

    // This is LiveContainer's own LC+SideStore return/relaunch bridge. It
    // starts the host with the required launch configuration and terminates
    // the old guest only from its completion handler. TweakLoader itself uses
    // this selector when it switches from a guest into built-in SideStore.
    Class sharedUtils = NSClassFromString(@"LCSharedUtils");
    SEL launchGuest = NSSelectorFromString(@"launchToGuestAppWithClassicMode:");
    if (sharedUtils && [sharedUtils respondsToSelector:launchGuest]) {
        BOOL accepted = ((BOOL (*)(id, SEL, NSUInteger))objc_msgSend)(sharedUtils, launchGuest, 0);
        if (accepted) {
            return;
        }
    }

    NSString *scheme = nil;

    // LiveContainer exposes this helper through its guest process.
    if ([NSUserDefaults respondsToSelector:@selector(lcAppUrlScheme)]) {
        scheme = [NSUserDefaults lcAppUrlScheme];
    }

    // Fallback for older builds.
    if (scheme.length == 0) {
        scheme = @"livecontainer";
    }

    NSString *urlString = [NSString stringWithFormat:@"%@://", scheme];
    NSURL *url = [NSURL URLWithString:urlString];

    // A LiveProcess guest can share UIApplication with a retained host scene.
    // Prefer returning to that scene; this is the public equivalent of the
    // host-side activation path and does not terminate the guest process.
    UISceneSession *currentSession = self.overlayWindow.windowScene.session;
    for (UISceneSession *session in UIApplication.sharedApplication.openSessions) {
        if ([session.persistentIdentifier isEqualToString:currentSession.persistentIdentifier]) {
            continue;
        }

        [UIApplication.sharedApplication requestSceneSessionActivation:session
                                                            userActivity:nil
                                                                  options:nil
                                                             errorHandler:^(NSError *error) {
            NSLog(@"[ReturnToLiveContainer] Host scene activation failed: %@", error);
        }];
        break;
    }

    if (url) {
        // LiveContainer itself uses LSApplicationWorkspace to cross the process
        // boundary. The guest UIApplication is often unable to route its host's
        // scheme, even though the host application is installed and active.
        Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
        SEL defaultWorkspace = NSSelectorFromString(@"defaultWorkspace");
        SEL openURL = NSSelectorFromString(@"openURL:");
        if (workspaceClass && [workspaceClass respondsToSelector:defaultWorkspace]) {
            id workspace = ((id (*)(id, SEL))objc_msgSend)(workspaceClass, defaultWorkspace);
            if (workspace && [workspace respondsToSelector:openURL]) {
                BOOL opened = ((BOOL (*)(id, SEL, id))objc_msgSend)(workspace, openURL, url);
                if (opened) {
                    return;
                }
            }
        }

        [UIApplication.sharedApplication openURL:url options:@{} completionHandler:^(BOOL success) {
            if (!success) [self resetFadeTimer];
        }];
    } else {
        [self resetFadeTimer];
    }
}

@end

#pragma mark - Overlay controller

@interface RTLCOverlayViewController : UIViewController
@property(nonatomic, strong) RTLCButton *button;
@property(nonatomic, strong) UIView *placementView;
@property(nonatomic, strong) NSTimer *geometryTimer;
@property(nonatomic, assign) BOOL hasGuestGeometry;
- (void)syncGuestGeometry;
@end

@implementation RTLCOverlayViewController

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (CGPoint)overlayPoint:(CGPoint)point fromGuestView:(UIView *)guestView {
    UIWindow *guestWindow = guestView.window;
    UIWindow *overlayWindow = self.view.window;
    CGPoint windowPoint = [guestView convertPoint:point toView:guestWindow];
    CGPoint overlayPoint = [guestWindow convertPoint:windowPoint toWindow:overlayWindow];
    return [self.view convertPoint:overlayPoint fromView:overlayWindow];
}

- (void)syncGuestGeometry {
    UIWindow *overlayWindow = self.view.window;
    UIWindowScene *scene = overlayWindow.windowScene;
    if (!scene || scene.activationState != UISceneActivationStateForegroundActive) return;

    UIWindow *guestWindow = nil;
    for (UIWindow *candidate in scene.windows) {
        if (candidate == overlayWindow || candidate.hidden || candidate.alpha == 0.0 ||
            !candidate.rootViewController) continue;
        if (candidate.isKeyWindow) {
            guestWindow = candidate;
            break;
        }
        if (!guestWindow && candidate.windowLevel == UIWindowLevelNormal) {
            guestWindow = candidate;
        }
    }
    UIViewController *guestController = guestWindow.rootViewController;
    UIView *guestView = guestController.viewIfLoaded;
    // Full-screen presentations (including video players) can detach the
    // root view or rotate independently. Follow the visible full-screen view;
    // a smaller sheet must not shrink the button's available screen area.
    for (UIViewController *presented = guestController.presentedViewController;
         presented; presented = presented.presentedViewController) {
        UIView *presentedView = presented.viewIfLoaded;
        if (presentedView.window != guestWindow || presentedView.hidden) continue;
        CGRect coverage = [presentedView convertRect:presentedView.bounds toView:guestWindow];
        if (CGRectContainsRect(coverage, CGRectInset(guestWindow.bounds, 1.0, 1.0))) {
            guestView = presentedView;
        }
    }
    if (!guestView.window || CGRectIsEmpty(guestView.bounds)) return;

    CGRect bounds = guestView.bounds;
    UIEdgeInsets safe = guestView.safeAreaInsets;
    // Convert basis vectors across the two windows. This captures rotation
    // and also compensates if UIKit DOES rotate the overlay (no double turn).
    CGPoint origin = [self overlayPoint:bounds.origin fromGuestView:guestView];
    CGPoint x = [self overlayPoint:CGPointMake(CGRectGetMinX(bounds) + 1.0, CGRectGetMinY(bounds))
                     fromGuestView:guestView];
    CGPoint y = [self overlayPoint:CGPointMake(CGRectGetMinX(bounds), CGRectGetMinY(bounds) + 1.0)
                     fromGuestView:guestView];
    CGAffineTransform transform = CGAffineTransformMake(x.x - origin.x, x.y - origin.y,
                                                       y.x - origin.x, y.y - origin.y, 0, 0);
    CGPoint center = [self overlayPoint:CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds))
                          fromGuestView:guestView];
    if (self.hasGuestGeometry && CGRectEqualToRect(self.placementView.bounds, bounds) &&
        CGPointEqualToPoint(self.placementView.center, center) &&
        CGAffineTransformEqualToTransform(self.placementView.transform, transform) &&
        UIEdgeInsetsEqualToEdgeInsets(self.button.positionSafeAreaInsets, safe)) return;

    // Preserve a drag in the previous coordinate system before replacing it.
    if (self.button.dragging) {
        [self.button snapToNearestEdgeAnimated:NO];
    }
    if (self.button.tracking) {
        [self.button cancelTrackingWithEvent:nil];
        self.button.transform = CGAffineTransformIdentity;
    }

    BOOL animated = self.hasGuestGeometry;
    self.hasGuestGeometry = YES;
    void (^update)(void) = ^{
        self.placementView.bounds = bounds;
        self.placementView.center = center;
        self.placementView.transform = transform;
        self.button.positionSafeAreaInsets = safe;
        [self.button restorePosition];
    };
    if (animated) {
        [UIView animateWithDuration:0.25 delay:0
                            options:UIViewAnimationOptionBeginFromCurrentState |
                                    UIViewAnimationOptionAllowUserInteraction
                         animations:update completion:nil];
    } else {
        update();
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self syncGuestGeometry];
}

- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
    [self syncGuestGeometry];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.clearColor;
    self.view.userInteractionEnabled = YES;
    self.placementView = [[UIView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:self.placementView];
    self.button = [[RTLCButton alloc] initWithFrame:CGRectMake(0, 0, RTLCDiameter, RTLCDiameter)];
    [self.placementView addSubview:self.button];

    // Non-key overlays may receive neither rotation nor layout callbacks.
    // Observe actual guest geometry independently, including programmatic
    // rotations and changes while scrolling; ignore unchanged geometry.
    __weak RTLCOverlayViewController *weakSelf = self;
    self.geometryTimer = [NSTimer timerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *timer) {
        [weakSelf syncGuestGeometry];
    }];
    [[NSRunLoop mainRunLoop] addTimer:self.geometryTimer forMode:NSRunLoopCommonModes];
}

- (void)dealloc {
    [self.geometryTimer invalidate];
}

@end

#pragma mark - Startup

static RTLCOverlayWindow *rtlOverlayWindow = nil;

static UIWindowScene *rtlcActiveWindowScene(void) {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive &&
                [scene isKindOfClass:UIWindowScene.class]) {
                return (UIWindowScene *)scene;
            }
        }

        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if ([scene isKindOfClass:UIWindowScene.class]) {
                return (UIWindowScene *)scene;
            }
        }
    }

    return nil;
}

static void rtlcInstallOverlay(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (rtlOverlayWindow) return;

        // Do not inject into LiveContainer's own UI if the tweak is ever loaded there.
        if ([NSUserDefaults respondsToSelector:@selector(isLiveProcess)] &&
            [NSUserDefaults isLiveProcess]) {
            return;
        }

        UIWindowScene *scene = rtlcActiveWindowScene();
        if (!scene) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                rtlcInstallOverlay();
            });
            return;
        }

        RTLCOverlayViewController *controller = [RTLCOverlayViewController new];
        rtlOverlayWindow = [[RTLCOverlayWindow alloc] initWithWindowScene:scene];
        rtlOverlayWindow.rootViewController = controller;
        [controller view]; // Create the button before the window can receive touches.
        rtlOverlayWindow.backgroundColor = UIColor.clearColor;
        rtlOverlayWindow.windowLevel = UIWindowLevelAlert + 1.0;
        rtlOverlayWindow.opaque = NO;
        rtlOverlayWindow.userInteractionEnabled = YES;

        controller.button.overlayWindow = rtlOverlayWindow;
        rtlOverlayWindow.returnButton = controller.button;
        rtlOverlayWindow.hidden = NO;
        [controller.view layoutIfNeeded];
        [controller syncGuestGeometry];
    });
}

%ctor {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Give UIApplication/scenes time to exist before creating the overlay.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.75 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            rtlcInstallOverlay();
        });
    });
}
