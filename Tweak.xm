#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#pragma mark - Settings keys

static NSString * const kDOLBoxEnabledKey       = @"DOL_boxEnabled";
static NSString * const kDOLLineEnabledKey      = @"DOL_lineEnabled";
static NSString * const kDOLAimCircleEnabledKey = @"DOL_aimCircleEnabled";
static NSString * const kDOLAimRadiusKey        = @"DOL_aimRadius";
static NSString * const kDOLMenuOriginKey       = @"DOL_menuOrigin";
static NSString * const kDOLToggleCenterKey     = @"DOL_toggleCenter";

static const NSInteger kDOLMaxPoints     = 32;
static const CGFloat   kDOLDefaultRadius = 150.0f;
static const CGFloat   kDOLMenuWidth     = 230.0f;
static const CGFloat   kDOLMenuHeight    = 296.0f;
static const NSInteger kDOLRadiusLabelTag = 4242;

#pragma mark - Data

typedef struct {
    CGPoint screenPoint;
    BOOL    isValid;
} DOLPoint;

#pragma mark - Render view (pure CAShapeLayer)

@interface DOLRenderView : UIView
@property (nonatomic, strong) CAShapeLayer *aimCircleLayer;
@property (nonatomic, strong) CAShapeLayer *linesLayer;
@property (nonatomic, strong) CAShapeLayer *boxesLayer;
@property (nonatomic, strong) CAShapeLayer *highlightLayer;
@end

@implementation DOLRenderView

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.userInteractionEnabled = NO;
        self.backgroundColor        = UIColor.clearColor;

        _linesLayer = [CAShapeLayer layer];
        _linesLayer.fillColor   = nil;
        _linesLayer.strokeColor = [UIColor colorWithRed:0.30 green:0.95 blue:0.55 alpha:0.85].CGColor;
        _linesLayer.lineWidth   = 1.5;
        _linesLayer.lineCap     = kCALineCapRound;
        _linesLayer.shadowColor   = UIColor.blackColor.CGColor;
        _linesLayer.shadowOpacity = 0.55;
        _linesLayer.shadowRadius  = 1.5;
        _linesLayer.shadowOffset  = CGSizeZero;

        _boxesLayer = [CAShapeLayer layer];
        _boxesLayer.fillColor   = nil;
        _boxesLayer.strokeColor = [UIColor colorWithRed:1.00 green:0.30 blue:0.36 alpha:0.95].CGColor;
        _boxesLayer.lineWidth   = 1.8;
        _boxesLayer.lineJoin    = kCALineJoinRound;
        _boxesLayer.shadowColor   = UIColor.blackColor.CGColor;
        _boxesLayer.shadowOpacity = 0.55;
        _boxesLayer.shadowRadius  = 1.5;
        _boxesLayer.shadowOffset  = CGSizeZero;

        _aimCircleLayer = [CAShapeLayer layer];
        _aimCircleLayer.fillColor       = nil;
        _aimCircleLayer.strokeColor     = [UIColor colorWithWhite:1.0 alpha:0.55].CGColor;
        _aimCircleLayer.lineWidth       = 1.2;
        _aimCircleLayer.lineDashPattern = @[ @6, @4 ];

        _highlightLayer = [CAShapeLayer layer];
        _highlightLayer.fillColor   = nil;
        _highlightLayer.strokeColor = [UIColor colorWithRed:1.00 green:0.92 blue:0.20 alpha:1.00].CGColor;
        _highlightLayer.lineWidth   = 2.4;
        _highlightLayer.lineJoin    = kCALineJoinRound;
        _highlightLayer.shadowColor   = _highlightLayer.strokeColor;
        _highlightLayer.shadowOpacity = 0.85;
        _highlightLayer.shadowRadius  = 4.5;
        _highlightLayer.shadowOffset  = CGSizeZero;

        for (CALayer *layer in @[ _aimCircleLayer, _linesLayer, _boxesLayer, _highlightLayer ]) {
            [self.layer addSublayer:layer];
        }
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    for (CALayer *layer in @[ self.aimCircleLayer, self.linesLayer, self.boxesLayer, self.highlightLayer ]) {
        layer.frame = self.bounds;
    }
}

@end

#pragma mark - Overlay controller

@interface DOLOverlayController : NSObject {
    DOLPoint  _points[kDOLMaxPoints];
    NSInteger _pointCount;
}

@property (nonatomic, strong) UIWindow           *window;
@property (nonatomic, strong) DOLRenderView      *renderView;
@property (nonatomic, strong) UIVisualEffectView *menuView;
@property (nonatomic, strong) UIButton           *toggleButton;
@property (nonatomic, strong) CADisplayLink      *displayLink;

@property (nonatomic, assign) BOOL    boxEnabled;
@property (nonatomic, assign) BOOL    lineEnabled;
@property (nonatomic, assign) BOOL    aimCircleEnabled;
@property (nonatomic, assign) CGFloat aimRadius;

@end

@implementation DOLOverlayController

+ (instancetype)shared {
    static DOLOverlayController *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [DOLOverlayController new]; });
    return s;
}

- (instancetype)init {
    if ((self = [super init])) {
        [self loadSettings];
        [self seedDebugPoints];
    }
    return self;
}

#pragma mark Settings

- (void)loadSettings {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    [d registerDefaults:@{
        kDOLBoxEnabledKey:       @YES,
        kDOLLineEnabledKey:      @YES,
        kDOLAimCircleEnabledKey: @YES,
        kDOLAimRadiusKey:        @(kDOLDefaultRadius),
    }];
    self.boxEnabled       = [d boolForKey:kDOLBoxEnabledKey];
    self.lineEnabled      = [d boolForKey:kDOLLineEnabledKey];
    self.aimCircleEnabled = [d boolForKey:kDOLAimCircleEnabledKey];
    CGFloat r = (CGFloat)[d doubleForKey:kDOLAimRadiusKey];
    self.aimRadius = (r > 0 ? r : kDOLDefaultRadius);
}

- (void)saveSettings {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    [d setBool:self.boxEnabled       forKey:kDOLBoxEnabledKey];
    [d setBool:self.lineEnabled      forKey:kDOLLineEnabledKey];
    [d setBool:self.aimCircleEnabled forKey:kDOLAimCircleEnabledKey];
    [d setDouble:(double)self.aimRadius forKey:kDOLAimRadiusKey];
}

#pragma mark Debug points

- (void)seedDebugPoints {
    _pointCount = 3;
    _points[0] = (DOLPoint){ CGPointMake(150, 300), YES };
    _points[1] = (DOLPoint){ CGPointMake(250, 500), YES };
    _points[2] = (DOLPoint){ CGPointMake(350, 200), YES };
}

#pragma mark Window / scene

- (UIWindowScene *)activeWindowScene {
    UIWindowScene *fallback = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *ws = (UIWindowScene *)scene;
        if (ws.activationState == UISceneActivationStateForegroundActive) return ws;
        if (!fallback) fallback = ws;
    }
    return fallback;
}

- (void)bootstrap {
    if (self.window) return;

    CGRect bounds = UIScreen.mainScreen.bounds;
    UIWindowScene *scene = [self activeWindowScene];
    if (scene) {
        self.window = [[UIWindow alloc] initWithWindowScene:scene];
        self.window.frame = scene.coordinateSpace.bounds;
    } else {
        self.window = [[UIWindow alloc] initWithFrame:bounds];
    }
    self.window.backgroundColor       = UIColor.clearColor;
    self.window.userInteractionEnabled = YES;
    self.window.windowLevel           = UIWindowLevelStatusBar + 200;

    UIViewController *root = [UIViewController new];
    root.view.backgroundColor = UIColor.clearColor;
    self.window.rootViewController = root;
    self.window.hidden = NO;

    self.renderView = [[DOLRenderView alloc] initWithFrame:self.window.bounds];
    self.renderView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [root.view addSubview:self.renderView];

    [self buildMenu];
    [self buildToggleButton];
    [self startDisplayLink];
}

#pragma mark Menu

- (UILabel *)labelWithText:(NSString *)text frame:(CGRect)frame {
    UILabel *l = [[UILabel alloc] initWithFrame:frame];
    l.text      = text;
    l.textColor = UIColor.whiteColor;
    l.font      = [UIFont systemFontOfSize:14];
    return l;
}

- (void)addRowAt:(CGFloat)y
           label:(NSString *)text
           value:(BOOL)on
        onChange:(SEL)action
              in:(UIView *)container {
    UILabel *label = [self labelWithText:text frame:CGRectMake(16, y, 130, 30)];
    [container addSubview:label];

    UISwitch *sw = [[UISwitch alloc] init];
    CGRect f = sw.frame;
    f.origin.x = kDOLMenuWidth - f.size.width - 14;
    f.origin.y = y - (f.size.height - 30) / 2.0;
    sw.frame = f;
    sw.on = on;
    sw.onTintColor = [UIColor colorWithRed:0.30 green:0.85 blue:0.55 alpha:1.0];
    [sw addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    [container addSubview:sw];
}

- (void)buildMenu {
    CGPoint origin = [self loadMenuOrigin];
    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *menu = [[UIVisualEffectView alloc] initWithEffect:effect];
    menu.frame = CGRectMake(origin.x, origin.y, kDOLMenuWidth, kDOLMenuHeight);
    menu.layer.cornerRadius  = 16;
    menu.layer.masksToBounds = YES;
    menu.layer.borderWidth   = 1.0 / UIScreen.mainScreen.scale;
    menu.layer.borderColor   = [UIColor colorWithWhite:1 alpha:0.30].CGColor;
    menu.layer.shadowColor   = UIColor.blackColor.CGColor;
    menu.layer.shadowOpacity = 0.0; // shadow does not render with masksToBounds; kept for parity

    UIView *content = menu.contentView;

    UILabel *title = [self labelWithText:@"Debug Overlay" frame:CGRectMake(16, 12, kDOLMenuWidth - 32, 22)];
    title.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [content addSubview:title];

    UIView *separator = [[UIView alloc] initWithFrame:CGRectMake(12, 40, kDOLMenuWidth - 24, 1.0 / UIScreen.mainScreen.scale)];
    separator.backgroundColor = [UIColor colorWithWhite:1 alpha:0.18];
    [content addSubview:separator];

    CGFloat y = 52;
    [self addRowAt:y label:@"Box ESP"    value:self.boxEnabled       onChange:@selector(boxSwitchChanged:)    in:content]; y += 44;
    [self addRowAt:y label:@"Line ESP"   value:self.lineEnabled      onChange:@selector(lineSwitchChanged:)   in:content]; y += 44;
    [self addRowAt:y label:@"Aim circle" value:self.aimCircleEnabled onChange:@selector(circleSwitchChanged:) in:content]; y += 44;

    UILabel *radiusLabel = [self labelWithText:@"Radius" frame:CGRectMake(16, y, 80, 22)];
    [content addSubview:radiusLabel];

    UILabel *radiusValue = [self labelWithText:[NSString stringWithFormat:@"%.0fpt", self.aimRadius]
                                         frame:CGRectMake(kDOLMenuWidth - 70, y, 54, 22)];
    radiusValue.textAlignment = NSTextAlignmentRight;
    radiusValue.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightRegular];
    radiusValue.tag  = kDOLRadiusLabelTag;
    [content addSubview:radiusValue];
    y += 24;

    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(16, y, kDOLMenuWidth - 32, 24)];
    slider.minimumValue = 50;
    slider.maximumValue = 400;
    slider.value        = (float)self.aimRadius;
    slider.minimumTrackTintColor = [UIColor colorWithRed:0.30 green:0.85 blue:0.55 alpha:1.0];
    [slider addTarget:self action:@selector(radiusSliderChanged:) forControlEvents:UIControlEventValueChanged];
    [content addSubview:slider];
    y += 36;

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.frame = CGRectMake(16, kDOLMenuHeight - 50, kDOLMenuWidth - 32, 36);
    closeButton.backgroundColor    = [UIColor colorWithWhite:1 alpha:0.10];
    closeButton.layer.cornerRadius = 10;
    [closeButton setTitle:@"Hide menu" forState:UIControlStateNormal];
    [closeButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    closeButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [closeButton addTarget:self action:@selector(hideMenu) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:closeButton];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(menuPanned:)];
    [menu addGestureRecognizer:pan];

    self.menuView = menu;
    [self.window.rootViewController.view addSubview:menu];
}

- (CGPoint)loadMenuOrigin {
    NSString *str = [NSUserDefaults.standardUserDefaults stringForKey:kDOLMenuOriginKey];
    if (str.length) return CGPointFromString(str);
    return CGPointMake(16, 80);
}

- (void)saveMenuOrigin:(CGPoint)origin {
    [NSUserDefaults.standardUserDefaults setObject:NSStringFromCGPoint(origin) forKey:kDOLMenuOriginKey];
}

- (void)menuPanned:(UIPanGestureRecognizer *)pan {
    UIView *v = pan.view;
    UIView *parent = v.superview;
    CGPoint t = [pan translationInView:parent];
    CGRect f = v.frame;
    f.origin.x += t.x;
    f.origin.y += t.y;
    CGSize bs = parent.bounds.size;
    f.origin.x = MAX(0, MIN(bs.width  - f.size.width,  f.origin.x));
    f.origin.y = MAX(0, MIN(bs.height - f.size.height, f.origin.y));
    v.frame = f;
    [pan setTranslation:CGPointZero inView:parent];
    if (pan.state == UIGestureRecognizerStateEnded ||
        pan.state == UIGestureRecognizerStateCancelled) {
        [self saveMenuOrigin:f.origin];
    }
}

- (void)hideMenu {
    [UIView animateWithDuration:0.22
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        self.menuView.alpha     = 0;
        self.menuView.transform = CGAffineTransformMakeScale(0.85, 0.85);
    } completion:^(BOOL finished) {
        self.menuView.hidden     = YES;
        self.toggleButton.hidden = NO;
    }];
}

- (void)showMenu {
    self.menuView.hidden     = NO;
    self.toggleButton.hidden = YES;
    [UIView animateWithDuration:0.30
                          delay:0
         usingSpringWithDamping:0.78
          initialSpringVelocity:0.4
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.menuView.alpha     = 1;
        self.menuView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

#pragma mark Toggle (floating) button

- (void)buildToggleButton {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    CGPoint center = [self loadToggleCenter];
    b.frame = CGRectMake(0, 0, 44, 44);
    b.center = center;
    b.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
    b.layer.cornerRadius = 22;
    b.layer.borderWidth  = 1.0 / UIScreen.mainScreen.scale;
    b.layer.borderColor  = [UIColor colorWithWhite:1 alpha:0.4].CGColor;
    [b setTitle:@"D" forState:UIControlStateNormal];
    [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    [b addTarget:self action:@selector(showMenu) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(togglePanned:)];
    [b addGestureRecognizer:pan];

    b.hidden = YES;
    self.toggleButton = b;
    [self.window.rootViewController.view addSubview:b];
}

- (CGPoint)loadToggleCenter {
    NSString *str = [NSUserDefaults.standardUserDefaults stringForKey:kDOLToggleCenterKey];
    if (str.length) return CGPointFromString(str);
    return CGPointMake(40, 110);
}

- (void)togglePanned:(UIPanGestureRecognizer *)pan {
    UIView *v = pan.view;
    UIView *parent = v.superview;
    CGPoint t = [pan translationInView:parent];
    CGPoint c = v.center;
    c.x += t.x;
    c.y += t.y;
    CGSize bs = parent.bounds.size;
    CGFloat halfW = v.bounds.size.width / 2.0;
    CGFloat halfH = v.bounds.size.height / 2.0;
    c.x = MAX(halfW, MIN(bs.width  - halfW, c.x));
    c.y = MAX(halfH, MIN(bs.height - halfH, c.y));
    v.center = c;
    [pan setTranslation:CGPointZero inView:parent];
    if (pan.state == UIGestureRecognizerStateEnded ||
        pan.state == UIGestureRecognizerStateCancelled) {
        [NSUserDefaults.standardUserDefaults setObject:NSStringFromCGPoint(c) forKey:kDOLToggleCenterKey];
    }
}

#pragma mark Switch / slider actions

- (void)boxSwitchChanged:(UISwitch *)sw {
    self.boxEnabled = sw.isOn;
    [self saveSettings];
}

- (void)lineSwitchChanged:(UISwitch *)sw {
    self.lineEnabled = sw.isOn;
    [self saveSettings];
}

- (void)circleSwitchChanged:(UISwitch *)sw {
    self.aimCircleEnabled = sw.isOn;
    [self saveSettings];
}

- (void)radiusSliderChanged:(UISlider *)s {
    self.aimRadius = (CGFloat)s.value;
    UILabel *lbl = (UILabel *)[self.menuView.contentView viewWithTag:kDOLRadiusLabelTag];
    lbl.text = [NSString stringWithFormat:@"%.0fpt", self.aimRadius];
    [self saveSettings];
}

#pragma mark Display link

- (void)startDisplayLink {
    if (self.displayLink) return;
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick)];
    if (@available(iOS 15.0, *)) {
        self.displayLink.preferredFrameRateRange = CAFrameRateRangeMake(30, 120, 60);
    } else {
        self.displayLink.preferredFramesPerSecond = 60;
    }
    [self.displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}

- (void)tick {
    [self render];
}

#pragma mark Rendering

- (CGPoint)closestPointInCircle:(CGPoint)center radius:(CGFloat)radius {
    CGPoint closest = CGPointMake(-FLT_MAX, -FLT_MAX);
    CGFloat minDist = radius;
    for (NSInteger i = 0; i < _pointCount; i++) {
        if (!_points[i].isValid) continue;
        CGFloat dx = _points[i].screenPoint.x - center.x;
        CGFloat dy = _points[i].screenPoint.y - center.y;
        CGFloat d  = hypot(dx, dy);
        if (d < minDist) {
            minDist = d;
            closest = _points[i].screenPoint;
        }
    }
    return closest;
}

- (void)render {
    if (!self.renderView) return;
    CGRect bounds  = self.renderView.bounds;
    CGPoint center = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));

    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    // Aim circle
    if (self.aimCircleEnabled) {
        UIBezierPath *p = [UIBezierPath bezierPathWithOvalInRect:
                           CGRectMake(center.x - self.aimRadius,
                                      center.y - self.aimRadius,
                                      self.aimRadius * 2,
                                      self.aimRadius * 2)];
        self.renderView.aimCircleLayer.path   = p.CGPath;
        self.renderView.aimCircleLayer.hidden = NO;
    } else {
        self.renderView.aimCircleLayer.hidden = YES;
    }

    // Boxes & lines
    UIBezierPath *boxes = [UIBezierPath bezierPath];
    UIBezierPath *lines = [UIBezierPath bezierPath];
    BOOL anyBoxes = NO;
    BOOL anyLines = NO;
    for (NSInteger i = 0; i < _pointCount; i++) {
        if (!_points[i].isValid) continue;
        CGPoint pt = _points[i].screenPoint;
        if (self.boxEnabled) {
            CGRect r = CGRectMake(pt.x - 20, pt.y - 80, 40, 80);
            [boxes appendPath:[UIBezierPath bezierPathWithRoundedRect:r cornerRadius:3]];
            anyBoxes = YES;
        }
        if (self.lineEnabled) {
            [lines moveToPoint:center];
            [lines addLineToPoint:pt];
            anyLines = YES;
        }
    }
    self.renderView.boxesLayer.path   = anyBoxes ? boxes.CGPath : NULL;
    self.renderView.boxesLayer.hidden = !anyBoxes;
    self.renderView.linesLayer.path   = anyLines ? lines.CGPath : NULL;
    self.renderView.linesLayer.hidden = !anyLines;

    // Highlight closest point inside aim circle
    if (self.aimCircleEnabled) {
        CGPoint closest = [self closestPointInCircle:center radius:self.aimRadius];
        if (closest.x > -FLT_MAX) {
            CGRect r = CGRectMake(closest.x - 22, closest.y - 84, 44, 88);
            self.renderView.highlightLayer.path   = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:4].CGPath;
            self.renderView.highlightLayer.hidden = NO;
        } else {
            self.renderView.highlightLayer.hidden = YES;
        }
    } else {
        self.renderView.highlightLayer.hidden = YES;
    }

    [CATransaction commit];
}

@end

#pragma mark - Entry point

%ctor {
    @autoreleasepool {
        // Defensive process gate. The tweak's filter plist already targets SpringBoard,
        // but if someone replaces the filter we still refuse to attach to anything else.
        NSString *processName = NSProcessInfo.processInfo.processName ?: @"";
        if (![processName isEqualToString:@"SpringBoard"]) return;

        dispatch_async(dispatch_get_main_queue(), ^{
            // Defer until UIApplication / window scenes are alive.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [[DOLOverlayController shared] bootstrap];
            });
        });
    }
}
