//
//  DOGlobalAppearance.m
//  Dopamine
//

#import "DOGlobalAppearance.h"
#import <CoreGraphics/CoreGraphics.h>
#import "DOThemeManager.h"
#import "DOTheme.h"
#import <objc/runtime.h>

static char kDOPageContentKey;

static NSInteger const kDOLiquidGlassEffectTag = 0xD027;
static NSInteger const kDOLiquidGlassBackgroundTag = 0xD028;

// These are public iOS 26 selectors. Runtime lookup keeps the iOS 15/16 SDK
// fallback buildable without linking a new UIKit class into older systems.
@protocol DOPublicGlassEffect
+ (UIVisualEffect *)effectWithStyle:(NSInteger)style;
- (void)setTintColor:(UIColor *)color;
@end

static UIVisualEffect *DOCreateSurfaceEffect(DOTheme *theme)
{
    if (UIAccessibilityIsReduceTransparencyEnabled()) return nil;
    if (@available(iOS 26.0, *)) {
        Class glassClass = NSClassFromString(@"UIGlassEffect");
        if ([glassClass respondsToSelector:@selector(effectWithStyle:)]) {
            UIVisualEffect *glass = [(Class<DOPublicGlassEffect>)glassClass effectWithStyle:0];
            if ([glass isKindOfClass:UIVisualEffect.class]) {
                if ([glass respondsToSelector:@selector(setTintColor:)])
                    [(id<DOPublicGlassEffect>)glass setTintColor:theme.glassColor];
                return glass;
            }
        }
    }
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

static UIVisualEffectView *DOFindGlassEffect(UIView *view)
{
    for (UIView *subview in view.subviews) {
        if (subview.tag == kDOLiquidGlassEffectTag && [subview isKindOfClass:UIVisualEffectView.class])
            return (UIVisualEffectView *)subview;
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
        [DOGlobalAppearance applyLiquidGlassToView:self];
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

@implementation DOGlobalAppearance

+ (DOTheme *)theme
{
    return [DOThemeManager.sharedInstance enabledTheme];
}

+ (BOOL)isLiquidGlassStyle
{
    return [self theme].liquidGlass;
}

+ (BOOL)isRoseStyle
{
    // Source-compatible name retained for the upstream UI units. All three
    // redesigned themes use the same complete Liquid Glass layout.
    return [self isLiquidGlassStyle];
}

+ (UIUserInterfaceStyle)interfaceStyle
{
    return [self theme].darkTheme ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
}

+ (UIImage *)backgroundImage
{
    return [self theme].image;
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
    return [self theme].panelColor;
}

+ (UIColor *)statusGreenColor
{
    return [self theme].statusGreenColor;
}

+ (UIColor *)glassColor
{
    return [self theme].glassColor;
}

+ (UIColor *)tileColor
{
    return [self theme].tileColor;
}

+ (UIColor *)selectedColor
{
    return [self theme].selectedColor;
}

+ (UIColor *)glassHighlightColor
{
    return [self theme].glassHighlightColor;
}

+ (UIColor *)buttonTextColor
{
    return [self theme].darkTheme ? UIColor.whiteColor : [self primaryTextColor];
}

+ (void)applyLiquidGlassToView:(UIView *)view
{
    if (!view) return;
    DOTheme *theme = [self theme];
    UIVisualEffectView *effect = DOFindGlassEffect(view);
    if (!effect) {
        effect = [[DOThemeEffectView alloc] initWithEffect:nil];
        effect.tag = kDOLiquidGlassEffectTag;
        effect.translatesAutoresizingMaskIntoConstraints = NO;
        effect.userInteractionEnabled = NO;
        UIView *background = [view viewWithTag:kDOLiquidGlassBackgroundTag];
        NSUInteger insertIndex = 0;
        if (background) {
            NSUInteger backgroundIndex = [view.subviews indexOfObject:background];
            if (backgroundIndex != NSNotFound) insertIndex = MIN(backgroundIndex + 1, view.subviews.count);
        }
        [view insertSubview:effect atIndex:insertIndex];
        [NSLayoutConstraint activateConstraints:@[
            [effect.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
            [effect.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
            [effect.topAnchor constraintEqualToAnchor:view.topAnchor],
            [effect.bottomAnchor constraintEqualToAnchor:view.bottomAnchor]
        ]];
    }
    NSString *appearanceKey = [NSString stringWithFormat:@"%@-%d", theme.key, UIAccessibilityIsReduceTransparencyEnabled()];
    if ([effect isKindOfClass:DOThemeEffectView.class]) {
        DOThemeEffectView *themeEffect = (DOThemeEffectView *)effect;
        if (![themeEffect.appearanceKey isEqualToString:appearanceKey]) {
            themeEffect.effect = DOCreateSurfaceEffect(theme);
            themeEffect.appearanceKey = appearanceKey;
        }
    }
    effect.overrideUserInterfaceStyle = [self interfaceStyle];
    Class glassClass = NSClassFromString(@"UIGlassEffect");
    BOOL nativeGlass = glassClass && [effect.effect isKindOfClass:glassClass];
    effect.contentView.backgroundColor = UIAccessibilityIsReduceTransparencyEnabled() ? theme.windowColor : (nativeGlass ? UIColor.clearColor : theme.glassColor);
    effect.alpha = 1.0;
    effect.layer.cornerRadius = view.layer.cornerRadius > 0 ? view.layer.cornerRadius : 22;
    effect.layer.cornerCurve = kCACornerCurveContinuous;
    effect.layer.masksToBounds = YES;
    view.backgroundColor = UIColor.clearColor;
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
    [self applyLiquidGlassToView:card];
    UIView *group = [[UIView alloc] init];
    group.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:group];
    UILabel *mark = [[UILabel alloc] init];
    mark.translatesAutoresizingMaskIntoConstraints = NO;
    mark.text = @"D";
    mark.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    mark.textColor = [self accentColor];
    mark.textAlignment = NSTextAlignmentCenter;
    mark.backgroundColor = [self tileColor];
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

+ (void)styleTableCell:(UITableViewCell *)cell
{
    if (!cell) return;
    cell.backgroundColor = UIColor.clearColor;
    if (cell.backgroundConfiguration) cell.backgroundConfiguration = nil;
    cell.contentView.backgroundColor = UIColor.clearColor;
    cell.contentView.layer.cornerRadius = 0;
    BOOL plain = [cell isKindOfClass:NSClassFromString(@"DOHeaderCell")] || [cell isKindOfClass:NSClassFromString(@"DOCreditsCell")];
    DORowSurfaceView *row = [cell.backgroundView isKindOfClass:DORowSurfaceView.class] ? (DORowSurfaceView *)cell.backgroundView : [[DORowSurfaceView alloc] init];
    row.fillView.backgroundColor = plain ? UIColor.clearColor : [self tileColor];
    cell.backgroundView = row;
    cell.tintColor = [self accentColor];
    cell.textLabel.textColor = cell.userInteractionEnabled ? [self primaryTextColor] : [self secondaryTextColor];
    cell.detailTextLabel.textColor = [self secondaryTextColor];
    if ([cell.accessoryView isKindOfClass:UISwitch.class]) {
        UISwitch *toggle = (UISwitch *)cell.accessoryView;
        toggle.onTintColor = [self accentColor];
        toggle.thumbTintColor = UIColor.whiteColor;
    }
    DORowSurfaceView *selected = [[DORowSurfaceView alloc] init];
    selected.fillView.backgroundColor = plain ? UIColor.clearColor : [self selectedColor];
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
    configuration.background.backgroundColor = [self tileColor];
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
