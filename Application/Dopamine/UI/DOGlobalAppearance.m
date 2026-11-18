//
//  DOGlobalAppearance.m
//  Dopamine
//

#import "DOGlobalAppearance.h"
#import <CoreGraphics/CoreGraphics.h>
#import "DOThemeManager.h"
#import "DOTheme.h"
#import "DOPreferenceManager.h"
#import <objc/runtime.h>
#import <math.h>

static char kDOPageContentKey;
static char kDOSurfaceColorKey;
static NSHashTable<UIImageView *> *DOBackgroundViews;
static NSHashTable<UIView *> *DOSurfaceViews;
static NSHashTable<UIVisualEffectView *> *DOIndependentEffects;

static NSInteger const kDOThemeEffectTag = 0xD027;

static CGFloat DOInterfaceTransparency(void)
{
    id saved = [[DOPreferenceManager sharedManager] preferenceValueForKey:@"interfaceTransparency"];
    if (![saved isKindOfClass:NSNumber.class] || !isfinite([saved doubleValue])) return 0.5;
    return MAX(0.0, MIN(100.0, [saved doubleValue])) / 100.0;
}

static UIColor *DOAdjustedSurfaceColor(UIColor *color, BOOL reduced)
{
    if (reduced) return [color colorWithAlphaComponent:1];
    CGFloat red = 0, green = 0, blue = 0, alpha = 0;
    if (![color getRed:&red green:&green blue:&blue alpha:&alpha]) return color;
    CGFloat retainedAlpha = 1.0 - DOInterfaceTransparency();
    return [UIColor colorWithRed:red green:green blue:blue alpha:retainedAlpha];
}

static UIVisualEffect *DOCreateSurfaceEffect(DOTheme *theme)
{
    if (UIAccessibilityIsReduceTransparencyEnabled()) return nil;
    return [UIBlurEffect effectWithStyle:theme.darkTheme ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemUltraThinMaterialLight];
}

@interface DOThemeEffectView : UIVisualEffectView
@property (nonatomic, copy) NSString *appearanceKey;
@end

@implementation DOThemeEffectView
- (void)layoutSubviews
{
    [super layoutSubviews];
    self.layer.cornerRadius = self.superview.layer.cornerRadius;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.layer.masksToBounds = YES;
}
@end

@interface DOGlobalAppearance ()
+ (DOTheme *)theme;
@end

static DOThemeEffectView *DOFindSurfaceEffect(UIView *view)
{
    for (UIView *subview in view.subviews) {
        if (subview.tag == kDOThemeEffectTag && [subview isKindOfClass:DOThemeEffectView.class])
            return (DOThemeEffectView *)subview;
    }
    return nil;
}

@interface DOPageSurfaceView : UIView
@property (nonatomic, strong) UIView *clippedContent;
@end

@implementation DOPageSurfaceView
- (instancetype)init
{
    if ((self = [super init])) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.layer.cornerRadius = 27;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        [DOGlobalAppearance applyThemeSurfaceToView:self];
        _clippedContent = [[UIView alloc] init];
        _clippedContent.accessibilityIdentifier = @"DOPageContent";
        _clippedContent.translatesAutoresizingMaskIntoConstraints = NO;
        _clippedContent.layer.cornerRadius = 27;
        _clippedContent.layer.cornerCurve = kCACornerCurveContinuous;
        _clippedContent.clipsToBounds = YES;
        [self addSubview:_clippedContent];
        [NSLayoutConstraint activateConstraints:@[
            [_clippedContent.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_clippedContent.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_clippedContent.topAnchor constraintEqualToAnchor:self.topAnchor],
            [_clippedContent.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
        ]];
    }
    return self;
}
@end

@interface DORowSurfaceView : UIView
@property (nonatomic, strong) UIView *fillView;
@end

@implementation DORowSurfaceView
- (instancetype)init
{
    if ((self = [super init])) {
        self.userInteractionEnabled = NO;
        _fillView = [[UIView alloc] init];
        _fillView.layer.cornerRadius = 14;
        _fillView.layer.cornerCurve = kCACornerCurveContinuous;
        [self addSubview:_fillView];
    }
    return self;
}
- (void)layoutSubviews
{
    [super layoutSubviews];
    self.fillView.frame = UIEdgeInsetsInsetRect(self.bounds, UIEdgeInsetsMake(3, 0, 3, 0));
}
@end

static void DORefreshSurfaces(void)
{
    for (UIView *view in DOSurfaceViews.allObjects) {
        NSString *name = objc_getAssociatedObject(view, &kDOSurfaceColorKey);
        if (name) {
            SEL selector = NSSelectorFromString(name);
            UIColor *(*colorIMP)(id, SEL) = (void *)[DOGlobalAppearance methodForSelector:selector];
            view.backgroundColor = colorIMP(DOGlobalAppearance.class, selector);
        } else {
            [DOGlobalAppearance applyThemeSurfaceToView:view];
        }
    }
    CGFloat opacity = UIAccessibilityIsReduceTransparencyEnabled() ? 0 : 1 - DOInterfaceTransparency();
    for (UIVisualEffectView *effect in DOIndependentEffects.allObjects) effect.alpha = opacity;
}

@implementation DOGlobalAppearance

+ (void)initialize
{
    if (self != DOGlobalAppearance.class) return;
    DOBackgroundViews = [NSHashTable weakObjectsHashTable];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refreshBackgrounds:) name:@"DOThemeBackgroundDidChange" object:nil];
    DOSurfaceViews = [NSHashTable weakObjectsHashTable];
    DOIndependentEffects = [NSHashTable weakObjectsHashTable];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshTransparency:) name:UIAccessibilityReduceTransparencyStatusDidChangeNotification object:nil];
}

+ (void)refreshTransparency:(NSNotification *)notification
{
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ DORefreshSurfaces(); });
        return;
    }
    DORefreshSurfaces();
}

+ (CGFloat)interfaceTransparency { return DOInterfaceTransparency() * 100; }

+ (void)setInterfaceTransparency:(CGFloat)percentage
{
    if (!isfinite(percentage)) percentage = 50;
    percentage = MAX(0, MIN(100, round(percentage)));
    [[DOPreferenceManager sharedManager] setPreferenceValue:@(percentage) forKey:@"interfaceTransparency"];
    [self refreshTransparency:nil];
}

+ (void)bindSurfaceColor:(SEL)colorSelector toView:(UIView *)view
{
    objc_setAssociatedObject(view, &kDOSurfaceColorKey, NSStringFromSelector(colorSelector), OBJC_ASSOCIATION_COPY_NONATOMIC);
    [DOSurfaceViews addObject:view];
    UIColor *(*colorIMP)(id, SEL) = (void *)[self methodForSelector:colorSelector];
    view.backgroundColor = colorIMP(self, colorSelector);
}

+ (void)registerTransparencyEffect:(UIVisualEffectView *)effect
{
    [DOIndependentEffects addObject:effect];
    effect.alpha = UIAccessibilityIsReduceTransparencyEnabled() ? 0 : 1 - DOInterfaceTransparency();
}
+ (DOTheme *)theme
{
    return [DOThemeManager.sharedInstance enabledTheme];
}

+ (BOOL)isRoseStyle
{
    // All four palettes share the native layout used by these UI units.
    return YES;
}

+ (UIUserInterfaceStyle)interfaceStyle
{
    return [self theme].darkTheme ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
}

+ (void)registerBackgroundImageView:(UIImageView *)view
{
    [DOBackgroundViews addObject:view];
    view.image = [self backgroundImage];
}

+ (void)refreshBackgrounds:(NSNotification *)notification
{
    UIImage *image = [self backgroundImage];
    for (UIImageView *view in DOBackgroundViews.allObjects) view.image = image;
}

+ (UIImage *)backgroundImage
{
    return [DOThemeManager.sharedInstance backgroundImageForTheme:[self theme]];
}

+ (UIColor *)windowColorWithAlpha:(float)alpha
{
    return [[self panelColor] colorWithAlphaComponent:alpha];
}

+ (UIColor *)primaryTextColor
{
    return [self theme].primaryTextColor;
}

+ (UIColor *)secondaryTextColor
{
    return [self theme].secondaryTextColor;
}

+ (UIColor *)accentColor
{
    return [self theme].accentColor;
}

+ (UIColor *)separatorColor
{
    return [self theme].separatorColor;
}

+ (UIColor *)panelColor
{
    return [self theme].windowColor;
}

+ (UIColor *)informationPanelColor
{
    return DOAdjustedSurfaceColor([self theme].panelColor, UIAccessibilityIsReduceTransparencyEnabled());
}

+ (UIColor *)statusGreenColor
{
    return [self theme].statusGreenColor;
}

+ (UIColor *)glassColor
{
    return DOAdjustedSurfaceColor([self theme].glassColor, UIAccessibilityIsReduceTransparencyEnabled());
}

+ (UIColor *)tileColor
{
    return DOAdjustedSurfaceColor([self theme].tileColor, UIAccessibilityIsReduceTransparencyEnabled());
}

+ (UIColor *)selectedColor
{
    return DOAdjustedSurfaceColor([self theme].selectedColor, UIAccessibilityIsReduceTransparencyEnabled());
}

+ (UIColor *)glassHighlightColor
{
    return [self theme].glassHighlightColor;
}

+ (UIColor *)buttonTextColor
{
    return [self theme].darkTheme ? UIColor.whiteColor : [self primaryTextColor];
}

+ (void)applyThemeSurfaceToView:(UIView *)view
{
    if (!view) return;
    [DOSurfaceViews addObject:view];
    DOTheme *theme = [self theme];
    BOOL reduced = UIAccessibilityIsReduceTransparencyEnabled();
    DOThemeEffectView *effect = DOFindSurfaceEffect(view);
    if (!effect) {
        effect = [[DOThemeEffectView alloc] initWithEffect:nil];
        effect.tag = kDOThemeEffectTag;
        effect.translatesAutoresizingMaskIntoConstraints = NO;
        effect.userInteractionEnabled = NO;
        [view insertSubview:effect atIndex:0];
        [NSLayoutConstraint activateConstraints:@[
            [effect.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
            [effect.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
            [effect.topAnchor constraintEqualToAnchor:view.topAnchor],
            [effect.bottomAnchor constraintEqualToAnchor:view.bottomAnchor]
        ]];
    }
    NSString *appearanceKey = [NSString stringWithFormat:@"%@-%d", theme.key, reduced];
    if (![effect.appearanceKey isEqualToString:appearanceKey]) {
        effect.effect = DOCreateSurfaceEffect(theme);
        effect.appearanceKey = appearanceKey;
    }
    effect.contentView.backgroundColor = reduced ? [theme.windowColor colorWithAlphaComponent:1] : theme.glassColor;
    // This effect contains only its tint; foreground content is a sibling.
    effect.alpha = reduced ? 1.0 : 1.0 - DOInterfaceTransparency();
    effect.layer.cornerRadius = view.layer.cornerRadius > 0 ? view.layer.cornerRadius : 22;
    effect.layer.cornerCurve = kCACornerCurveContinuous;
    effect.layer.masksToBounds = YES;
    view.backgroundColor = reduced ? [theme.windowColor colorWithAlphaComponent:1] : UIColor.clearColor;
    view.layer.cornerRadius = effect.layer.cornerRadius;
    view.layer.cornerCurve = kCACornerCurveContinuous;
    view.layer.borderWidth = 0.5;
    view.layer.borderColor = theme.separatorColor.CGColor;
    view.layer.shadowColor = [UIColor colorWithRed:20.0/255 green:30.0/255 blue:35.0/255 alpha:1].CGColor;
    view.layer.shadowOpacity = theme.glassShadowOpacity;
    view.layer.shadowRadius = theme.glassShadowRadius;
    view.layer.shadowOffset = CGSizeMake(0, 12);
    view.layer.masksToBounds = NO;
}

+ (UIView *)contentViewForController:(UIViewController *)viewController
{
    DOPageSurfaceView *surface = objc_getAssociatedObject(viewController, &kDOPageContentKey);
    if (!surface) {
        UIView *root = viewController.view;
        surface = [[DOPageSurfaceView alloc] init];
        surface.accessibilityIdentifier = @"DOPageSurface";
        [root insertSubview:surface atIndex:0];
        NSLayoutConstraint *width = [surface.widthAnchor constraintEqualToAnchor:root.safeAreaLayoutGuide.widthAnchor constant:-36];
        width.priority = UILayoutPriorityDefaultHigh;
        [NSLayoutConstraint activateConstraints:@[
            width,
            [surface.widthAnchor constraintLessThanOrEqualToConstant:UI_IPAD_MAX_WIDTH],
            [surface.centerXAnchor constraintEqualToAnchor:root.safeAreaLayoutGuide.centerXAnchor],
            [surface.topAnchor constraintEqualToAnchor:root.safeAreaLayoutGuide.topAnchor constant:8],
            [surface.bottomAnchor constraintEqualToAnchor:root.safeAreaLayoutGuide.bottomAnchor constant:-85]
        ]];
        objc_setAssociatedObject(viewController, &kDOPageContentKey, surface, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return surface.clippedContent;
}

+ (void)styleViewController:(UIViewController *)viewController
{
    if (!viewController.isViewLoaded) return;
    viewController.overrideUserInterfaceStyle = [self interfaceStyle];
    viewController.view.tintColor = [self accentColor];
    viewController.view.backgroundColor = UIColor.clearColor;
    if (![viewController isKindOfClass:NSClassFromString(@"DOMainViewController")])
        [self contentViewForController:viewController];
}

+ (UIView *)brandCardView
{
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.accessibilityIdentifier = @"DOBrandCard";
    card.layer.cornerRadius = 23;
    [self applyThemeSurfaceToView:card];
    UIView *group = [[UIView alloc] init];
    group.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:group];
    UILabel *mark = [[UILabel alloc] init];
    mark.translatesAutoresizingMaskIntoConstraints = NO;
    mark.text = @"D";
    mark.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    mark.textColor = [self accentColor];
    mark.textAlignment = NSTextAlignmentCenter;
    [self bindSurfaceColor:@selector(tileColor) toView:mark];
    mark.layer.cornerRadius = 11;
    mark.layer.cornerCurve = kCACornerCurveContinuous;
    mark.clipsToBounds = YES;
    [group addSubview:mark];
    UILabel *brand = [[UILabel alloc] init];
    brand.accessibilityIdentifier = @"DOBrandLabel";
    brand.translatesAutoresizingMaskIntoConstraints = NO;
    brand.text = @"Dopamine";
    brand.font = [UIFont systemFontOfSize:23 weight:UIFontWeightSemibold];
    brand.textColor = [self primaryTextColor];
    brand.numberOfLines = 1;
    brand.lineBreakMode = NSLineBreakByTruncatingTail;
    brand.adjustsFontSizeToFitWidth = YES;
    brand.minimumScaleFactor = 0.75;
    [brand setContentCompressionResistancePriority:999 forAxis:UILayoutConstraintAxisHorizontal];
    [brand setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [group addSubview:brand];
    CGFloat naturalWidth = ceil([brand.text sizeWithAttributes:@{NSFontAttributeName:brand.font}].width);
    NSLayoutConstraint *desiredWidth = [group.widthAnchor constraintEqualToConstant:41 + naturalWidth];
    desiredWidth.priority = 998;
    [NSLayoutConstraint activateConstraints:@[
        desiredWidth,
        [group.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
        [group.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [group.heightAnchor constraintEqualToConstant:36],
        [group.leadingAnchor constraintGreaterThanOrEqualToAnchor:card.leadingAnchor constant:13],
        [group.trailingAnchor constraintLessThanOrEqualToAnchor:card.trailingAnchor constant:-13],
        [group.topAnchor constraintGreaterThanOrEqualToAnchor:card.topAnchor constant:8],
        [group.bottomAnchor constraintLessThanOrEqualToAnchor:card.bottomAnchor constant:-8],
        [mark.leadingAnchor constraintEqualToAnchor:group.leadingAnchor],
        [mark.centerYAnchor constraintEqualToAnchor:group.centerYAnchor],
        [mark.widthAnchor constraintEqualToConstant:31],
        [mark.heightAnchor constraintEqualToConstant:31],
        [brand.leadingAnchor constraintEqualToAnchor:mark.trailingAnchor constant:10],
        [brand.trailingAnchor constraintEqualToAnchor:group.trailingAnchor],
        [brand.topAnchor constraintEqualToAnchor:group.topAnchor],
        [brand.bottomAnchor constraintEqualToAnchor:group.bottomAnchor]
    ]];
    card.isAccessibilityElement = YES;
    card.accessibilityLabel = @"Dopamine";
    card.accessibilityTraits = UIAccessibilityTraitHeader;
    return card;
}

+ (void)styleSwitch:(UISwitch *)toggle
{
    toggle.onTintColor = [self accentColor];
    toggle.thumbTintColor = UIColor.whiteColor;
}

+ (void)styleTableCell:(UITableViewCell *)cell
{
    if (!cell) return;
    cell.backgroundColor = UIColor.clearColor;
    if (cell.backgroundConfiguration) cell.backgroundConfiguration = nil;
    cell.contentView.backgroundColor = UIColor.clearColor;
    cell.contentView.layer.cornerRadius = 0;
    BOOL plain = [cell isKindOfClass:NSClassFromString(@"DOHeaderCell")] || [cell isKindOfClass:NSClassFromString(@"DOCreditsCell")];
    DORowSurfaceView *row = [cell.backgroundView isKindOfClass:DORowSurfaceView.class] ? (DORowSurfaceView *)cell.backgroundView : [[DORowSurfaceView alloc] init];
    if (!plain) [self bindSurfaceColor:@selector(tileColor) toView:row.fillView];
    else row.fillView.backgroundColor = UIColor.clearColor;
    cell.backgroundView = row;
    cell.tintColor = [self accentColor];
    cell.textLabel.textColor = cell.userInteractionEnabled ? [self primaryTextColor] : [self secondaryTextColor];
    cell.detailTextLabel.textColor = [self secondaryTextColor];
    if ([cell.accessoryView isKindOfClass:UISwitch.class]) {
        [self styleSwitch:(UISwitch *)cell.accessoryView];
    }
    DORowSurfaceView *selected = [[DORowSurfaceView alloc] init];
    if (!plain) [self bindSurfaceColor:@selector(selectedColor) toView:selected.fillView];
    else selected.fillView.backgroundColor = UIColor.clearColor;
    cell.selectedBackgroundView = selected;
}

+ (UIImageSymbolConfiguration *)smallIconImageConfiguration
{
    return [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium];
}

+ (UIButtonConfiguration *)defaultButtonConfiguration
{
    UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
    configuration.imagePadding = 10;
    configuration.baseForegroundColor = [self primaryTextColor];
    configuration.background.backgroundColor = UIColor.clearColor;
    configuration.background.cornerRadius = 18;
    configuration.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey,id> *(NSDictionary<NSAttributedStringKey,id> *attributes) {
        NSMutableDictionary *result = attributes.mutableCopy;
        result[NSFontAttributeName] = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        result[NSForegroundColorAttributeName] = [self primaryTextColor];
        return result;
    };
    configuration.imageColorTransformer = ^UIColor *(UIColor *color) {
        return [self accentColor];
    };
    return configuration;
}

+ (UIButtonConfiguration *)defaultButtonConfigurationWithImagePadding:(CGFloat)imagePadding
{
    UIButtonConfiguration *configuration = [self defaultButtonConfiguration];
    configuration.imagePadding = imagePadding;
    return configuration;
}

+ (NSAttributedString *)mainSubtitleString:(NSString *)string
{
    return [[NSAttributedString alloc] initWithString:string attributes:@{
        NSFontAttributeName:[UIFont systemFontOfSize:14 weight:UIFontWeightMedium],
        NSForegroundColorAttributeName:[self primaryTextColor]
    }];
}

+ (NSAttributedString *)secondarySubtitleString:(NSString *)string
{
    return [[NSAttributedString alloc] initWithString:string attributes:@{
        NSFontAttributeName:[UIFont systemFontOfSize:14 weight:UIFontWeightRegular],
        NSForegroundColorAttributeName:[self secondaryTextColor]
    }];
}

+ (UIWindow *)activeWindow
{
    UIWindow *fallback = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        if (scene.activationState != UISceneActivationStateForegroundActive && scene.activationState != UISceneActivationStateForegroundInactive) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow) return window;
            if (!fallback && !window.hidden && window.windowLevel == UIWindowLevelNormal) fallback = window;
        }
    }
    return fallback;
}

+ (BOOL)isHomeButtonDevice
{
    UIWindow *window = [self activeWindow];
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone && window && window.safeAreaInsets.bottom == 0;
}

+ (BOOL)isRTL
{
    return UIApplication.sharedApplication.userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
}

+ (BOOL)isSmallDevice
{
    UIWindow *window = [self activeWindow];
    CGFloat height = window ? CGRectGetHeight(window.bounds) : CGRectGetHeight(UIScreen.mainScreen.bounds);
    return height < SE_PHONE_SIZE_CONST + 50;
}

@end
