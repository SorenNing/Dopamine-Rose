//
//  DOGlobalAppearance.m
//  Dopamine
//

#import "DOGlobalAppearance.h"
#import <CoreGraphics/CoreGraphics.h>
#import "DOThemeManager.h"
#import "DOTheme.h"

static NSInteger const kDOLiquidGlassEffectTag = 0xD027;
static NSInteger const kDOLiquidGlassBackgroundTag = 0xD028;

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

static void DOInstallGlassBackdrop(UIView *view)
{
    if (!view) return;
    DOTheme *theme = [DOThemeManager.sharedInstance enabledTheme];
    UIImageView *background = (UIImageView *)[view viewWithTag:kDOLiquidGlassBackgroundTag];
    if (!background) {
        background = [[UIImageView alloc] init];
        background.tag = kDOLiquidGlassBackgroundTag;
        background.translatesAutoresizingMaskIntoConstraints = NO;
        background.contentMode = UIViewContentModeScaleAspectFill;
        background.userInteractionEnabled = NO;
        [view insertSubview:background atIndex:0];
        [NSLayoutConstraint activateConstraints:@[
            [background.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
            [background.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
            [background.topAnchor constraintEqualToAnchor:view.topAnchor],
            [background.bottomAnchor constraintEqualToAnchor:view.bottomAnchor]
        ]];
    }
    background.image = theme.image;
    background.alpha = theme.darkTheme ? 0.94 : 0.86;

    UIVisualEffectView *effect = DOFindGlassEffect(view);
    if (!effect) {
        UIBlurEffectStyle style = theme.darkTheme ? UIBlurEffectStyleSystemChromeMaterialDark : UIBlurEffectStyleSystemChromeMaterialLight;
        effect = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:style]];
        effect.tag = kDOLiquidGlassEffectTag;
        effect.translatesAutoresizingMaskIntoConstraints = NO;
        effect.userInteractionEnabled = NO;
        [view insertSubview:effect aboveSubview:background];
        [NSLayoutConstraint activateConstraints:@[
            [effect.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
            [effect.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
            [effect.topAnchor constraintEqualToAnchor:view.topAnchor],
            [effect.bottomAnchor constraintEqualToAnchor:view.bottomAnchor]
        ]];
    }
    effect.backgroundColor = theme.glassColor;
    effect.alpha = 0.42;
}

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
        UIBlurEffectStyle style = theme.darkTheme ? UIBlurEffectStyleSystemMaterialDark : UIBlurEffectStyleSystemMaterialLight;
        effect = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:style]];
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
    effect.backgroundColor = theme.glassColor;
    effect.alpha = 0.92;
    effect.layer.cornerRadius = view.layer.cornerRadius > 0 ? view.layer.cornerRadius : 22;
    effect.layer.cornerCurve = kCACornerCurveContinuous;
    effect.layer.masksToBounds = YES;
    view.backgroundColor = UIColor.clearColor;
    view.layer.cornerRadius = effect.layer.cornerRadius;
    view.layer.cornerCurve = kCACornerCurveContinuous;
    view.layer.borderWidth = 0.5;
    view.layer.borderColor = theme.glassHighlightColor.CGColor;
    view.layer.shadowColor = [UIColor blackColor].CGColor;
    view.layer.shadowOpacity = theme.glassShadowOpacity;
    view.layer.shadowRadius = theme.glassShadowRadius;
    view.layer.shadowOffset = CGSizeMake(0, 8);
    view.layer.masksToBounds = NO;
}

+ (void)styleViewController:(UIViewController *)viewController
{
    if (!viewController.isViewLoaded) return;
    viewController.overrideUserInterfaceStyle = [self interfaceStyle];
    viewController.view.tintColor = [self accentColor];
    viewController.view.backgroundColor = UIColor.clearColor;
    DOInstallGlassBackdrop(viewController.view);
}

+ (void)styleTableCell:(UITableViewCell *)cell
{
    if (!cell) return;
    cell.backgroundColor = UIColor.clearColor;
    cell.contentView.backgroundColor = UIColor.clearColor;
    [self applyLiquidGlassToView:cell.contentView];
    cell.contentView.layer.cornerRadius = 14;
    cell.contentView.layer.cornerCurve = kCACornerCurveContinuous;
    cell.tintColor = [self accentColor];
    cell.textLabel.textColor = cell.userInteractionEnabled ? [self primaryTextColor] : [self secondaryTextColor];
    cell.detailTextLabel.textColor = [self secondaryTextColor];
    if ([cell.accessoryView isKindOfClass:UISwitch.class]) {
        UISwitch *toggle = (UISwitch *)cell.accessoryView;
        toggle.onTintColor = [self accentColor];
        toggle.thumbTintColor = [self buttonTextColor];
    }
    UIView *selected = [[UIView alloc] init];
    selected.backgroundColor = [self selectedColor];
    selected.layer.cornerRadius = 14;
    selected.layer.cornerCurve = kCACornerCurveContinuous;
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

+ (BOOL)isHomeButtonDevice
{
    return [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone && [UIApplication.sharedApplication.keyWindow safeAreaInsets].bottom == 0;
}

+ (BOOL)isRTL
{
    return UIApplication.sharedApplication.userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
}

+ (BOOL)isSmallDevice
{
    UIWindow *window = UIApplication.sharedApplication.keyWindow;
    return window.frame.size.height < SE_PHONE_SIZE_CONST + 50;
}

@end
