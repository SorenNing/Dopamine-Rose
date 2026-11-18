//
//  DOThemeManager.h
//  Dopamine
//
//  Created by tomt000 on 14/02/2024.
//

#import <Foundation/Foundation.h>
#import "DOTheme.h"

NS_ASSUME_NONNULL_BEGIN

@interface DOThemeManager : NSObject

@property (nonatomic, retain) NSArray<DOTheme*> *themes;

+ (instancetype)sharedInstance;

+ (UIColor*)menuColorWithAlpha:(float)alpha;
- (NSArray*)getAvailableThemeKeys;
- (NSArray*)getAvailableThemeNames;
- (DOTheme*)getThemeForKey:(NSString*)key;
- (DOTheme*)enabledTheme;
- (UIImage *)backgroundImageForTheme:(DOTheme *)theme;
// Called on a background queue while the provider's temporary URL is valid.
- (BOOL)importBackgroundFromURL:(NSURL *)url themeKey:(NSString *)key error:(NSError **)error;
- (BOOL)resetBackgroundForThemeKey:(NSString *)key error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
