#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

// ========== НАСТРОЙКИ (сохраняются) ==========
static BOOL boxEnabled = YES;
static BOOL lineEnabled = YES;
static BOOL aimCircleEnabled = YES;
static float aimRadius = 150.0f;

// ========== ДАННЫЕ (заглушки, заменишь позже) ==========
typedef struct {
    CGPoint screenPoint;
    BOOL isValid;
} DebugPoint;

static DebugPoint debugPoints[10] = {0};
static int debugPointCount = 0;

// ========== UI ЭЛЕМЕНТЫ ==========
static UIWindow *overlayWindow = nil;
static UIView *menuView = nil;
static UIView *circleView = nil;

// ========== СОХРАНЕНИЕ НАСТРОЕК ==========
void SaveSettings() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:boxEnabled forKey:@"boxEnabled"];
    [defaults setBool:lineEnabled forKey:@"lineEnabled"];
    [defaults setBool:aimCircleEnabled forKey:@"aimCircleEnabled"];
    [defaults setFloat:aimRadius forKey:@"aimRadius"];
}

void LoadSettings() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    boxEnabled = [defaults boolForKey:@"boxEnabled"];
    lineEnabled = [defaults boolForKey:@"lineEnabled"];
    aimCircleEnabled = [defaults boolForKey:@"aimCircleEnabled"];
    float saved = [defaults floatForKey:@"aimRadius"];
    if (saved > 0) aimRadius = saved;
}

// ========== ВЫБОР БЛИЖАЙШЕЙ ТОЧКИ В КРУГЕ ==========
CGPoint FindClosestPointInCircle(CGPoint center, float radius) {
    CGPoint closest = CGPointMake(-1, -1);
    float minDist = radius;
    
    for (int i = 0; i < debugPointCount; i++) {
        if (!debugPoints[i].isValid) continue;
        
        float dx = debugPoints[i].screenPoint.x - center.x;
        float dy = debugPoints[i].screenPoint.y - center.y;
        float dist = sqrtf(dx*dx + dy*dy);
        
        if (dist < minDist) {
            minDist = dist;
            closest = debugPoints[i].screenPoint;
        }
    }
    return closest;
}

// ========== ОТРИСОВКА БОКСОВ И ЛИНИЙ ==========
void DrawBox(CGContextRef ctx, CGPoint center, float width, float height, UIColor *color) {
    CGRect rect = CGRectMake(center.x - width/2, center.y - height, width, height);
    CGContextSetStrokeColorWithColor(ctx, color.CGColor);
    CGContextSetLineWidth(ctx, 2.0);
    CGContextStrokeRect(ctx, rect);
}

void DrawLine(CGContextRef ctx, CGPoint from, CGPoint to, UIColor *color) {
    CGContextSetStrokeColorWithColor(ctx, color.CGColor);
    CGContextSetLineWidth(ctx, 1.5);
    CGContextMoveToPoint(ctx, from.x, from.y);
    CGContextAddLineToPoint(ctx, to.x, to.y);
    CGContextStrokePath(ctx);
}

// ========== ГЛАВНАЯ ФУНКЦИЯ ОТРИСОВКИ ==========
void DrawOverlay() {
    if (!overlayWindow) return;
    
    UIGraphicsBeginImageContextWithOptions(overlayWindow.bounds.size, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    CGPoint screenCenter = CGPointMake(overlayWindow.bounds.size.width/2,
                                        overlayWindow.bounds.size.height/2);
    
    // Круг аимбота
    if (aimCircleEnabled) {
        CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:1 green:1 blue:1 alpha:0.5].CGColor);
        CGContextSetLineWidth(ctx, 1.5);
        CGContextStrokeEllipseInRect(ctx, CGRectMake(screenCenter.x - aimRadius,
                                                      screenCenter.y - aimRadius,
                                                      aimRadius*2, aimRadius*2));
    }
    
    // Отрисовка точек
    for (int i = 0; i < debugPointCount; i++) {
        if (!debugPoints[i].isValid) continue;
        CGPoint point = debugPoints[i].screenPoint;
        
        // Бокс
        if (boxEnabled) {
            DrawBox(ctx, point, 40, 80, [UIColor redColor]);
        }
        
        // Линия от центра
        if (lineEnabled) {
            DrawLine(ctx, screenCenter, point, [UIColor greenColor]);
        }
    }
    
    // Подсветка ближайшей точки
    CGPoint closest = FindClosestPointInCircle(screenCenter, aimRadius);
    if (closest.x > 0) {
        DrawBox(ctx, closest, 44, 88, [UIColor yellowColor]);
    }
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    UIImageView *imageView = (UIImageView *)[overlayWindow viewWithTag:999];
    if (!imageView) {
        imageView = [[UIImageView alloc] initWithFrame:overlayWindow.bounds];
        imageView.tag = 999;
        imageView.contentMode = UIViewContentModeScaleToFill;
        [overlayWindow addSubview:imageView];
    }
    imageView.image = image;
}

// ========== СОЗДАНИЕ МЕНЮ ==========
void CreateMenu() {
    menuView = [[UIView alloc] initWithFrame:CGRectMake(10, 100, 200, 220)];
    menuView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8];
    menuView.layer.cornerRadius = 12;
    menuView.layer.borderWidth = 1;
    menuView.layer.borderColor = [UIColor whiteColor].CGColor;
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:menuView action:@selector(handlePan:)];
    [menuView addGestureRecognizer:pan];
    
    int yOffset = 10;
    
    UISwitch *boxSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(120, yOffset, 50, 30)];
    boxSwitch.on = boxEnabled;
    [boxSwitch addTarget:[NSObject alloc] action:@selector(boxChanged:) forControlEvents:UIControlEventValueChanged];
    [menuView addSubview:boxSwitch];
    
    UILabel *boxLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, yOffset, 100, 30)];
    boxLabel.text = @"Box ESP";
    boxLabel.textColor = [UIColor whiteColor];
    [menuView addSubview:boxLabel];
    yOffset += 45;
    
    UISwitch *lineSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(120, yOffset, 50, 30)];
    lineSwitch.on = lineEnabled;
    [menuView addSubview:lineSwitch];
    
    UILabel *lineLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, yOffset, 100, 30)];
    lineLabel.text = @"Line ESP";
    lineLabel.textColor = [UIColor whiteColor];
    [menuView addSubview:lineLabel];
    yOffset += 45;
    
    UISwitch *circleSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(120, yOffset, 50, 30)];
    circleSwitch.on = aimCircleEnabled;
    [menuView addSubview:circleSwitch];
    
    UILabel *circleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, yOffset, 100, 30)];
    circleLabel.text = @"Aim Circle";
    circleLabel.textColor = [UIColor whiteColor];
    [menuView addSubview:circleLabel];
    yOffset += 45;
    
    UILabel *radiusLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, yOffset, 80, 30)];
    radiusLabel.text = @"Radius:";
    radiusLabel.textColor = [UIColor whiteColor];
    [menuView addSubview:radiusLabel];
    
    UISlider *radiusSlider = [[UISlider alloc] initWithFrame:CGRectMake(80, yOffset+5, 110, 20)];
    radiusSlider.minimumValue = 50;
    radiusSlider.maximumValue = 300;
    radiusSlider.value = aimRadius;
    [menuView addSubview:radiusSlider];
    yOffset += 50;
    
    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.frame = CGRectMake(80, yOffset, 60, 30);
    [closeButton setTitle:@"Close" forState:UIControlStateNormal];
    [closeButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [menuView addSubview:closeButton];
    
    // замыкания для кнопок
    objc_setAssociatedObject(boxSwitch, "key", @(boxEnabled), OBJC_ASSOCIATION_RETAIN);
    objc_setAssociatedObject(lineSwitch, "key", @(lineEnabled), OBJC_ASSOCIATION_RETAIN);
    objc_setAssociatedObject(circleSwitch, "key", @(aimCircleEnabled), OBJC_ASSOCIATION_RETAIN);
    
    [overlayWindow addSubview:menuView];
}

// ========== ТАЙМЕР ОБНОВЛЕНИЯ ==========
void StartUpdateLoop() {
    [NSTimer scheduledTimerWithTimeInterval:0.03 repeats:YES block:^(NSTimer *timer) {
        DrawOverlay();
    }];
}

// ========== ТОЧКА ВХОДА ==========
__attribute__((constructor))
void init_debug_overlay() {
    dispatch_async(dispatch_get_main_queue(), ^{
        LoadSettings();
        
        overlayWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        overlayWindow.backgroundColor = [UIColor clearColor];
        overlayWindow.windowLevel = UIWindowLevelAlert + 100;
        overlayWindow.hidden = NO;
        
        CreateMenu();
        StartUpdateLoop();
        
        // Тестовые точки (для отладки — уберешь потом)
        debugPointCount = 3;
        debugPoints[0] = (DebugPoint){CGPointMake(150, 300), YES};
        debugPoints[1] = (DebugPoint){CGPointMake(250, 500), YES};
        debugPoints[2] = (DebugPoint){CGPointMake(350, 200), YES};
    });
}

// ========== РЕАКЦИЯ НА ИЗМЕНЕНИЯ ==========
static void boxChanged(UISwitch *sender) {
    boxEnabled = sender.isOn;
    SaveSettings();
}

static void lineChanged(UISwitch *sender) {
    lineEnabled = sender.isOn;
    SaveSettings();
}

static void circleChanged(UISwitch *sender) {
    aimCircleEnabled = sender.isOn;
    SaveSettings();
}

static void radiusChanged(UISlider *sender) {
    aimRadius = sender.value;
    SaveSettings();
}

// подключаем методы к контролам
__attribute__((constructor))
static void registerSelectors() {
    Class cls = [NSObject class];
    class_addMethod(cls, @selector(boxChanged:), (IMP)boxChanged, "v@:@");
    class_addMethod(cls, @selector(lineChanged:), (IMP)lineChanged, "v@:@");
    class_addMethod(cls, @selector(circleChanged:), (IMP)circleChanged, "v@:@");
    class_addMethod(cls, @selector(radiusChanged:), (IMP)radiusChanged, "v@:@");
}
