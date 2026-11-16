//
//  DOGlobalAppearance.h
//  Dopamine
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#define UI_IPAD_MAX_WIDTH 600
#define UI_MODAL_PADDING 30
#define UI_PADDING 30
#define UI_INNER_PADDING 20
#define UI_INNER_PADDING_TINY 10
#define UI_INNER_TOP_PADDING 5
#define UI_ACTION_HEIGHT 73
#define UI_ACTION_HEIGHT_HOME_BTN 65
#define UI_ACTION_HEIGHT_TINY 52
#define SE_PHONE_SIZE_CONST 568

@interface DOGlobalAppearance : NSObject

// Kept as a source-compatible alias for older UI units. The redesigned app
// always routes these calls through the active Liquid Glass theme.
+ (BOOL)isRoseStyle;
+ (BOOL)isLiquidGlassStyle;
+ (UIUserInterfaceStyle)interfaceStyle;
+ (UIImage *)backgroundImage;
+ (UIColor *)primaryTextColor;
+ (UIColor *)secondaryTextColor;
+ (UIColor *)accentColor;
+ (UIColor *)separatorColor;
+ (UIColor *)panelColor;
+ (UIColor *)informationPanelColor;
+ (UIColor *)statusGreenColor;
+ (nullable UIWindow *)activeWindow;
+ (UIColor *)glassColor;
+ (UIColor *)tileColor;
+ (UIColor *)selectedColor;
+ (UIColor *)glassHighlightColor;
+ (UIColor *)buttonTextColor;
+ (void)styleTableCell:(UITableViewCell *)cell;
+ (void)applyLiquidGlassToView:(UIView *)view;
+ (void)styleViewController:(UIViewController *)viewController;
+ (UIView *)contentViewForController:(UIViewController *)viewController;
+ (UIView *)brandCardView;
+ (UIImageSymbolConfiguration *)smallIconImageConfiguration;
+ (UIButtonConfiguration *)defaultButtonConfiguration;
+ (UIButtonConfiguration *)defaultButtonConfigurationWithImagePadding:(CGFloat)imagePadding;
+ (NSAttributedString *)mainSubtitleString:(NSString *)string;
+ (NSAttributedString *)secondarySubtitleString:(NSString *)string;
+ (BOOL)isHomeButtonDevice;
+ (UIColor *)windowColorWithAlpha:(float)alpha;
+ (BOOL)isRTL;
+ (BOOL)isSmallDevice;

@end

NS_ASSUME_NONNULL_END
