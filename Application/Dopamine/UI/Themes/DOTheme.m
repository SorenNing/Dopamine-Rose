//
//  DOTheme.m
//  Dopamine
//

#import "DOTheme.h"
#import "UIImage+Blur.h"

@interface DOTheme ()
@property (nonatomic, retain) NSString *imageName;
@end

@implementation DOTheme

- (id)initWithDictionary:(NSDictionary *)dictionary
{
    self = [super init];
    if (self) {
        self.name = dictionary[@"name"] ?: @"Dopamine";
        self.icon = dictionary[@"icon"];
        self.key = dictionary[@"key"] ?: @"default";
        self.imageName = dictionary[@"image"];
        self.windowColor = [self colorFromHexString:dictionary[@"windowColor"] ?: @"FF202124"];
        self.actionMenuColor = [self colorFromHexString:dictionary[@"actionMenuColor"] ?: @"CC202124"];
        self.blur = [dictionary[@"blur"] floatValue];
        self.titleShadow = [dictionary[@"titleShadow"] boolValue];
        self.primaryTextColor = [self colorFromHexString:dictionary[@"primaryTextColor"] ?: @"FFF0EDE6"];
        self.secondaryTextColor = [self colorFromHexString:dictionary[@"secondaryTextColor"] ?: @"FFA4A4A0"];
        self.accentColor = [self colorFromHexString:dictionary[@"accentColor"] ?: @"FFC4B18D"];
        self.separatorColor = [self colorFromHexString:dictionary[@"separatorColor"] ?: @"22EEEEEE"];
        self.glassColor = [self colorFromHexString:dictionary[@"glassColor"] ?: @"AD202326"];
        self.tileColor = [self colorFromHexString:dictionary[@"tileColor"] ?: @"14E6E6D8"];
        self.selectedColor = [self colorFromHexString:dictionary[@"selectedColor"] ?: @"14E6E6D8"];
        self.glassHighlightColor = [self colorFromHexString:dictionary[@"glassHighlightColor"] ?: @"13EEEEEE"];
        self.darkTheme = [dictionary[@"darkTheme"] boolValue];
        self.liquidGlass = dictionary[@"liquidGlass"] ? [dictionary[@"liquidGlass"] boolValue] : YES;
        self.glassBlurRadius = dictionary[@"glassBlurRadius"] ? [dictionary[@"glassBlurRadius"] doubleValue] : 22.0;
        self.glassShadowOpacity = dictionary[@"glassShadowOpacity"] ? [dictionary[@"glassShadowOpacity"] doubleValue] : 0.10;
        self.glassShadowRadius = dictionary[@"glassShadowRadius"] ? [dictionary[@"glassShadowRadius"] doubleValue] : 30.0;
    }
    return self;
}

- (UIColor *)colorFromHexString:(NSString *)hexString
{
    if (![hexString isKindOfClass:NSString.class] || hexString.length == 0)
        return UIColor.clearColor;
    unsigned int hexInt = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    [scanner scanHexInt:&hexInt];
    CGFloat alpha = hexString.length > 6 ? ((hexInt & 0xFF000000) >> 24) / 255.0 : 1.0;
    return [UIColor colorWithRed:((hexInt & 0xFF0000) >> 16) / 255.0
                           green:((hexInt & 0xFF00) >> 8) / 255.0
                            blue:(hexInt & 0xFF) / 255.0
                           alpha:alpha];
}

- (UIImage *)image
{
    if (_image == nil)
        _image = [[UIImage imageNamed:self.imageName] imageWithBlur:self.blur];
    return _image;
}

- (UIImage *)generateBootLogo
{
    UIImage *backgroundImage = [self image];
    if (!backgroundImage) return [UIImage imageNamed:@"DopamineLogo"];
    CGSize canvasSize = backgroundImage.size;
    UIImage *overlayImage = [UIImage imageNamed:@"DopamineLogo"];
    CGSize overlaySize = CGSizeMake(350, 350);
    CGPoint overlayOrigin = CGPointMake((canvasSize.width - overlaySize.width) / 2.0,
                                        (canvasSize.height - overlaySize.height) / 2.0);
    UIGraphicsBeginImageContextWithOptions(canvasSize, NO, backgroundImage.scale);
    [backgroundImage drawInRect:CGRectMake(0, 0, canvasSize.width, canvasSize.height)];
    [overlayImage drawInRect:CGRectMake(overlayOrigin.x, overlayOrigin.y, overlaySize.width, overlaySize.height)];
    UIImage *finalImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return finalImage;
}

@end
