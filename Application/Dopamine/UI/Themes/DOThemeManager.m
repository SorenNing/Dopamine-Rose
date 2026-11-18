//
//  DOThemeManager.m
//  Dopamine
//

#import "DOThemeManager.h"
#import "DOPreferenceManager.h"
#import <ImageIO/ImageIO.h>

@interface DOThemeManager ()
@property (nonatomic, strong) NSCache<NSString *, UIImage *> *backgroundCache;
@end

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
        _backgroundCache = [NSCache new];
        _backgroundCache.countLimit = 4;
        _backgroundCache.totalCostLimit = 48 * 1024 * 1024;
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

// Only validated theme keys become filenames; resolve the container anew each launch.
- (NSURL *)backgroundURLForKey:(NSString *)key
{
    if (![self getThemeForKey:key]) return nil;
    NSURL *support = [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
    return [[support URLByAppendingPathComponent:@"ThemeBackgrounds" isDirectory:YES] URLByAppendingPathComponent:[key stringByAppendingPathExtension:@"jpg"]];
}

- (UIImage *)backgroundImageForTheme:(DOTheme *)theme
{
    UIImage *image = [self.backgroundCache objectForKey:theme.key];
    if (!image) {
        image = [UIImage imageWithContentsOfFile:[self backgroundURLForKey:theme.key].path];
        if (image) [self.backgroundCache setObject:image forKey:theme.key cost:(NSUInteger)(image.size.width * image.size.height * 4)];
    }
    return image ?: theme.image;
}

- (void)backgroundDidChangeForKey:(NSString *)key
{
    [self.backgroundCache removeObjectForKey:key];
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:@"DOThemeBackgroundDidChange" object:self];
    });
}

- (BOOL)importBackgroundFromURL:(NSURL *)url themeKey:(NSString *)key error:(NSError **)error
{
    @autoreleasepool {
        NSURL *destination = [self backgroundURLForKey:key];
        if (!destination) return NO;
        CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, (__bridge CFDictionaryRef)@{(id)kCGImageSourceShouldCache: @NO});
        CGImageRef thumbnail = source ? CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)@{
            (id)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
            (id)kCGImageSourceCreateThumbnailWithTransform: @YES,
            (id)kCGImageSourceShouldCacheImmediately: @YES,
            (id)kCGImageSourceThumbnailMaxPixelSize: @2560
        }) : NULL;
        if (source) CFRelease(source);
        if (!thumbnail) {
            if (error) *error = [NSError errorWithDomain:@"DOThemeBackground" code:1 userInfo:nil];
            return NO;
        }
        NSData *data = UIImageJPEGRepresentation([UIImage imageWithCGImage:thumbnail], 0.9);
        CGImageRelease(thumbnail);
        if (!data) return NO;
        if (![NSFileManager.defaultManager createDirectoryAtURL:destination.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:error]) return NO;
        if (![data writeToURL:destination options:NSDataWritingAtomic error:error]) return NO;
        [self backgroundDidChangeForKey:key];
        return YES;
    }
}

- (BOOL)resetBackgroundForThemeKey:(NSString *)key error:(NSError **)error
{
    NSURL *url = [self backgroundURLForKey:key];
    if (!url) return NO;
    if ([NSFileManager.defaultManager fileExistsAtPath:url.path] && ![NSFileManager.defaultManager removeItemAtURL:url error:error]) return NO;
    [self backgroundDidChangeForKey:key];
    return YES;
}

+ (UIColor *)menuColorWithAlpha:(float)alpha
{
    UIColor *color = [self.sharedInstance enabledTheme].glassColor;
    CGFloat red = 0, green = 0, blue = 0, colorAlpha = 1;
    [color getRed:&red green:&green blue:&blue alpha:&colorAlpha];
    return [color colorWithAlphaComponent:MIN(1.0, colorAlpha * alpha)];
}

@end
