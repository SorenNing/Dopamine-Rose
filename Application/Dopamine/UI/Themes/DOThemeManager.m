//
//  DOThemeManager.m
//  Dopamine
//

#import "DOThemeManager.h"
#import "DOPreferenceManager.h"

@implementation DOThemeManager

+ (instancetype)sharedInstance
{
    static DOThemeManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[DOThemeManager alloc] init];
    });
    return sharedManager;
}

- (id)init
{
    self = [super init];
    if (self) {
        NSMutableArray *loadedThemes = [NSMutableArray array];
        NSString *path = [[NSBundle mainBundle] pathForResource:@"Themes" ofType:@"plist"];
        for (NSDictionary *themeDictionary in [NSArray arrayWithContentsOfFile:path] ?: @[]) {
            [loadedThemes addObject:[[DOTheme alloc] initWithDictionary:themeDictionary]];
        }
        self.themes = loadedThemes;

        DOPreferenceManager *preferences = [DOPreferenceManager sharedManager];
        NSString *savedTheme = [preferences preferenceValueForKey:@"theme"];
        NSArray *validKeys = [self getAvailableThemeKeys];
        if (![savedTheme isKindOfClass:NSString.class] || ![validKeys containsObject:savedTheme]) {
            // The redesigned app opens on Glaze; existing old theme values are
            // migrated rather than leaving a partially styled legacy screen.
            [preferences setPreferenceValue:@"glaze" forKey:@"theme"];
        }
        // Retain the marker for old installations, but it no longer controls
        // whether the redesign is installed.
        [preferences setPreferenceValue:@YES forKey:@"liquidGlassUIInitialized"];
    }
    return self;
}

- (NSArray *)getAvailableThemeKeys
{
    NSMutableArray *keys = [NSMutableArray array];
    for (DOTheme *theme in self.themes) [keys addObject:theme.key];
    return keys;
}

- (NSArray *)getAvailableThemeNames
{
    NSMutableArray *names = [NSMutableArray array];
    for (DOTheme *theme in self.themes) [names addObject:theme.name];
    return names;
}

- (DOTheme *)getThemeForKey:(NSString *)key
{
    for (DOTheme *theme in self.themes) {
        if ([theme.key isEqualToString:key]) return theme;
    }
    return nil;
}

- (DOTheme *)enabledTheme
{
    NSString *value = [[DOPreferenceManager sharedManager] preferenceValueForKey:@"theme"];
    DOTheme *theme = [self getThemeForKey:value];
    return theme ?: [self getThemeForKey:@"glaze"] ?: self.themes.firstObject;
}

+ (UIColor *)menuColorWithAlpha:(float)alpha
{
    UIColor *color = [self.sharedInstance enabledTheme].glassColor;
    CGFloat red = 0, green = 0, blue = 0, colorAlpha = 1;
    [color getRed:&red green:&green blue:&blue alpha:&colorAlpha];
    return [color colorWithAlphaComponent:MIN(1.0, colorAlpha * alpha)];
}

@end
