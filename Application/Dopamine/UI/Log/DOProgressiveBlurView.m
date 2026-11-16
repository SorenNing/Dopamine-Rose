//
//  DOProgressiveBlurView.m
//  Dopamine
//
//  Created by tomt000 on 18/01/2024.
//

#import "DOProgressiveBlurView.h"
#import "DOGlobalAppearance.h"

@implementation DOProgressiveBlurView

- (instancetype)initWithGradientMask:(UIImage *)gradientMask maxBlurRadius:(CGFloat)maxBlurRadius {
    UIBlurEffectStyle style = [DOGlobalAppearance interfaceStyle] == UIUserInterfaceStyleDark
        ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemUltraThinMaterialLight;
    self = [super initWithEffect:maxBlurRadius > 0 ? [UIBlurEffect effectWithStyle:style] : nil];
    if (self) {
        self.userInteractionEnabled = NO;
        // UIKit exposes material styles, not a numeric blur radius. Keep the
        // constructor compatible and fade the material with the supplied alpha mask.
        UIImageView *maskView = [[UIImageView alloc] initWithImage:gradientMask];
        maskView.contentMode = UIViewContentModeScaleToFill;
        self.maskView = maskView;
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.maskView.frame = self.bounds;
}

@end
