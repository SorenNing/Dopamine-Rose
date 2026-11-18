//
//  DOTheme.h
//  Dopamine
//
//  Palette model for the native application UI.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DOTheme : NSObject

@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain, nullable) NSString *icon;
@property (nonatomic, retain) NSString *key;
@property (nonatomic, retain) UIColor *actionMenuColor;
@property (nonatomic, retain) UIColor *windowColor;
@property (nonatomic, retain) UIColor *panelColor;
@property (nonatomic, retain) UIColor *statusGreenColor;
@property (nonatomic, retain) UIImage *image;
@property (nonatomic, assign) float blur;
@property (nonatomic, assign) BOOL titleShadow;

@property (nonatomic, retain) UIColor *primaryTextColor;
@property (nonatomic, retain) UIColor *secondaryTextColor;
@property (nonatomic, retain) UIColor *accentColor;
@property (nonatomic, retain) UIColor *separatorColor;
@property (nonatomic, retain) UIColor *glassColor;
@property (nonatomic, retain) UIColor *tileColor;
@property (nonatomic, retain) UIColor *selectedColor;
@property (nonatomic, retain) UIColor *glassHighlightColor;
@property (nonatomic, assign) BOOL darkTheme;
@property (nonatomic, assign) CGFloat glassShadowOpacity;
@property (nonatomic, assign) CGFloat glassShadowRadius;

- (id)initWithDictionary:(NSDictionary *)dictionary;
- (UIImage *)generateBootLogo;

@end

NS_ASSUME_NONNULL_END
