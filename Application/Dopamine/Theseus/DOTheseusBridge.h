#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol DOTheseusGlassSurface <NSObject>
- (void)configureWithCornerRadius:(CGFloat)cornerRadius tintColor:(UIColor *)tintColor tintIntensity:(CGFloat)tintIntensity;
- (void)setCaptureSourceView:(nullable UIView *)sourceView;
- (void)invalidateBackdrop;
- (void)setRenderingActive:(BOOL)active;
@end

@protocol DOTheseusTabSurface <NSObject>
@property (nonatomic) NSInteger selectedIndex;
- (void)configureWithTitles:(NSArray<NSString *> *)titles symbolNames:(NSArray<NSString *> *)symbolNames selectedIndex:(NSInteger)index;
- (void)setSelectedIndex:(NSInteger)index animated:(BOOL)animated;
- (void)invalidateBackdrop;
- (void)setRenderingActive:(BOOL)active;
@end

@protocol DOTheseusSwitchFactory <NSObject>
- (UIView *)initWithSwitch:(UISwitch *)source;
@end

NS_ASSUME_NONNULL_END
