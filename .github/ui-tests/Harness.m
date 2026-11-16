// Simulator-only fixture pages. All shared appearance, theme and navigation code is production code.
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <math.h>
#import "DOGlobalAppearance.h"
#import "DOThemeManager.h"
#import "DONavigationController.h"
#import "Theseus/DOTheseusBridge.h"

static NSMutableArray<NSDictionary *> *DOChecks;
static NSMutableArray<NSDictionary *> *DOShots;
static NSString *DOContext;
static UIViewController *DOHost;
static UIWindow *DOWindow;
static BOOL DOPublished;
static char DODataSourceKey;
static NSMutableArray<NSDictionary *> *DOSteps;
static NSUInteger DOStepIndex;

// Forward declarations keep the standalone clang build independent of declaration order.
static void DORecord(NSString *name, BOOL passed, NSDictionary *details);
static NSDictionary *DORect(CGRect rect);
static UIView *DOFind(UIView *root, NSString *identifier);
static NSArray<UIView *> *DODescendants(UIView *root, Class type);
static BOOL DOContains(CGRect outer, CGRect inner);
static BOOL DONearRect(CGRect lhs, CGRect rhs);
static BOOL DOVisible(UIView *view);
static BOOL DOPillHasRoundedPixels(UIView *pill);
static BOOL DOTransitionBackdropHasCorrectLayering(DONavigationController *nav);
static BOOL DOIsSettled(DONavigationController *nav);
static void DOCheckAmbiguity(UIView *root);
static void DOCapture(UIView *view, NSString *name);
static void DOInstallFixturePage(UIViewController *controller, NSString *title);
static void DOInstallHomeFixture(UIViewController *controller);
static void DOCheckRows(UIViewController *controller, UIView *content);
static void DOCheckNavigation(DONavigationController *nav, NSInteger tab);
static void DOBrandCases(DOTheme *theme);
static void DONavigationCases(DOTheme *theme);
static void DOPublish(void);
static void DORun(void);
static void DOEnqueue(NSTimeInterval delay, dispatch_block_t block);
static void DOAdvance(void);
static void DOEnqueueNavigation(DONavigationController *nav, dispatch_block_t block);
static void DOExecuteStep(NSDictionary *step);
static void DOAwaitStep(NSDictionary *step, CFTimeInterval deadline, NSInteger quiet);

@implementation DOThemeManager
+ (instancetype)sharedInstance
{
    static DOThemeManager *manager;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        manager = [DOThemeManager new];
        NSArray *dictionaries = [NSArray arrayWithContentsOfURL:[NSBundle.mainBundle URLForResource:@"Themes" withExtension:@"plist"]];
        NSMutableArray *themes = [NSMutableArray array];
        for (NSDictionary *dictionary in dictionaries) [themes addObject:[[DOTheme alloc] initWithDictionary:dictionary]];
        manager.themes = themes;
    });
    return manager;
}
- (DOTheme *)enabledTheme { return self.themes[self.selectedIndex]; }
@end

NSString *DOLocalizedString(NSString *key)
{
    return [key isEqualToString:@"Menu_Settings_Title"] ? @"Settings" : key;
}

@interface DOHarnessTableSource : NSObject <UITableViewDataSource>
@end
@implementation DOHarnessTableSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 3; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.accessibilityIdentifier = [NSString stringWithFormat:@"DOFixtureRow%ld", (long)indexPath.row];
    cell.textLabel.text = @[@"Enable feature", @"Theme preview", @"Version information"][indexPath.row];
    cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    cell.detailTextLabel.text = @"UIKit fixture";
    cell.detailTextLabel.font = [UIFont systemFontOfSize:11];
    if (indexPath.row == 0) {
        UISwitch *toggle = [UISwitch new];
        toggle.on = YES;
        toggle.accessibilityIdentifier = @"DOFixtureSwitch";
        cell.accessoryView = toggle;
    } else {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    [DOGlobalAppearance styleTableCell:cell];
    return cell;
}
@end

@implementation DOMainViewController
- (void)viewDidLoad { [super viewDidLoad]; DOInstallHomeFixture(self); }
@end
@implementation DOSettingsController
- (void)viewDidLoad { [super viewDidLoad]; DOInstallFixturePage(self, @"Settings"); }
@end
@implementation DOCreditsViewController
- (void)viewDidLoad { [super viewDidLoad]; DOInstallFixturePage(self, @"About"); }
@end

static void DOInstallFixturePage(UIViewController *controller, NSString *title)
{
    controller.view.accessibilityIdentifier = @"DOFixtureRoot";
    [DOGlobalAppearance styleViewController:controller];
    UIView *content = [DOGlobalAppearance contentViewForController:controller];
    UILabel *heading = [UILabel new];
    heading.accessibilityIdentifier = @"DOFixtureHeading";
    heading.translatesAutoresizingMaskIntoConstraints = NO;
    heading.text = title;
    heading.font = [UIFont systemFontOfSize:24 weight:UIFontWeightSemibold];
    heading.textColor = [DOGlobalAppearance primaryTextColor];
    [content addSubview:heading];
    UITableView *table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    table.accessibilityIdentifier = @"DOFixtureTable";
    table.translatesAutoresizingMaskIntoConstraints = NO;
    table.backgroundColor = UIColor.clearColor;
    table.separatorStyle = UITableViewCellSeparatorStyleNone;
    table.rowHeight = 72;
    table.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    DOHarnessTableSource *source = [DOHarnessTableSource new];
    objc_setAssociatedObject(table, &DODataSourceKey, source, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    table.dataSource = source;
    [content addSubview:table];
    [NSLayoutConstraint activateConstraints:@[
        [heading.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [heading.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
        [heading.topAnchor constraintEqualToAnchor:content.topAnchor constant:16],
        [heading.heightAnchor constraintEqualToConstant:32],
        [table.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [table.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [table.topAnchor constraintEqualToAnchor:heading.bottomAnchor constant:12],
        [table.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-16]
    ]];
    [table reloadData];
}

static void DOInstallHomeFixture(UIViewController *controller)
{
    controller.view.accessibilityIdentifier = @"DOFixtureHome";
    controller.view.backgroundColor = UIColor.clearColor;
    UIView *card = [DOGlobalAppearance brandCardView];
    [controller.view addSubview:card];
    NSLayoutConstraint *width = [card.widthAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.widthAnchor constant:-36];
    width.priority = UILayoutPriorityDefaultHigh;
    UILabel *caption = [UILabel new];
    caption.translatesAutoresizingMaskIntoConstraints = NO;
    caption.accessibilityIdentifier = @"DOFixtureCaption";
    caption.text = @"Shared UIKit components\nRouting fixture · business actions omitted";
    caption.numberOfLines = 2;
    caption.textAlignment = NSTextAlignmentCenter;
    caption.font = [UIFont systemFontOfSize:12];
    caption.textColor = [DOGlobalAppearance secondaryTextColor];
    [controller.view addSubview:caption];
    [NSLayoutConstraint activateConstraints:@[
        width, [card.widthAnchor constraintLessThanOrEqualToConstant:600],
        [card.centerXAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.centerXAnchor],
        [card.topAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.topAnchor constant:8],
        [card.heightAnchor constraintEqualToConstant:60],
        [caption.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:8],
        [caption.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-8],
        [caption.topAnchor constraintEqualToAnchor:card.bottomAnchor constant:24],
        [caption.heightAnchor constraintEqualToConstant:40]
    ]];
}

static void DORecord(NSString *name, BOOL passed, NSDictionary *details)
{
    [DOChecks addObject:@{@"case": DOContext ?: @"startup", @"assertion": name, @"passed": @(passed), @"details": details ?: @{}}];
    if (!passed) NSLog(@"HARNESS_FAILURE %@ / %@ %@", DOContext, name, details ?: @{});
}
static NSDictionary *DORect(CGRect r)
{
    if (!isfinite(r.origin.x) || !isfinite(r.origin.y) || !isfinite(r.size.width) || !isfinite(r.size.height)) return @{@"invalid": @YES};
    return @{@"x": @(r.origin.x), @"y": @(r.origin.y), @"width": @(r.size.width), @"height": @(r.size.height)};
}
static UIView *DOFind(UIView *root, NSString *identifier)
{
    if ([root.accessibilityIdentifier isEqualToString:identifier]) return root;
    for (UIView *child in root.subviews) { UIView *found = DOFind(child, identifier); if (found) return found; }
    return nil;
}
static NSArray<UIView *> *DODescendants(UIView *root, Class type)
{
    NSMutableArray *views = [NSMutableArray array];
    if ([root isKindOfClass:type]) [views addObject:root];
    for (UIView *child in root.subviews) [views addObjectsFromArray:DODescendants(child, type)];
    return views;
}
static BOOL DOContains(CGRect outer, CGRect inner)
{
    return !CGRectIsEmpty(inner) && CGRectContainsRect(CGRectInset(outer, -1.0, -1.0), inner);
}
static BOOL DONearRect(CGRect a, CGRect b)
{
    return fabs(a.origin.x-b.origin.x) <= 1 && fabs(a.origin.y-b.origin.y) <= 1 &&
        fabs(a.size.width-b.size.width) <= 1 && fabs(a.size.height-b.size.height) <= 1;
}
static BOOL DOVisible(UIView *view)
{
    if (!view || !view.window) return NO;
    for (UIView *parent = view; parent; parent = parent.superview) if (parent.hidden || parent.alpha < 0.01) return NO;
    return YES;
}
static BOOL DOPillHasRoundedPixels(UIView *pill)
{
    if (!pill || CGRectGetWidth(pill.bounds) < 48 || CGRectGetHeight(pill.bounds) < 48) return NO;
    const size_t width = (size_t)ceil(CGRectGetWidth(pill.bounds));
    const size_t height = (size_t)ceil(CGRectGetHeight(pill.bounds));
    if (width > 2048 || height > 2048) return NO;
    uint8_t *pixels = calloc(width * height, 4);
    if (!pixels) return NO;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    if (!colorSpace) { free(pixels); return NO; }
    CGContextRef bitmap = CGBitmapContextCreate(pixels, width, height, 8, width * 4, colorSpace,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    BOOL rounded = NO;
    if (bitmap) {
        [pill.layer renderInContext:bitmap];
        size_t center = ((height / 2) * width + width / 2) * 4 + 3;
        size_t topLeft = (width + 1) * 4 + 3;
        size_t topRight = (width + width - 2) * 4 + 3;
        size_t bottomLeft = ((height - 2) * width + 1) * 4 + 3;
        size_t bottomRight = ((height - 2) * width + width - 2) * 4 + 3;
        rounded = pixels[center] > 3 && pixels[topLeft] < 4 && pixels[topRight] < 4 &&
            pixels[bottomLeft] < 4 && pixels[bottomRight] < 4;
        CGContextRelease(bitmap);
    }
    CGColorSpaceRelease(colorSpace);
    free(pixels);
    return rounded;
}
static BOOL DOTransitionBackdropHasCorrectLayering(DONavigationController *nav)
{
    id<UIViewControllerTransitionCoordinator> coordinator = nav.transitionCoordinator;
    UIView *backdrop = DOFind(nav.view, @"DOTransitionBackdrop");
    if (!coordinator || !DOVisible(backdrop)) return NO;
    UIView *container = coordinator.containerView;
    UIView *from = [coordinator viewForKey:UITransitionContextFromViewKey] ?: [coordinator viewControllerForKey:UITransitionContextFromViewControllerKey].view;
    UIView *to = [coordinator viewForKey:UITransitionContextToViewKey] ?: [coordinator viewControllerForKey:UITransitionContextToViewControllerKey].view;
    while (from && from.superview != container) from = from.superview;
    while (to && to.superview != container) to = to.superview;
    if (!from || !to || from == to) return NO;
    NSUInteger fromIndex = [container.subviews indexOfObjectIdenticalTo:from];
    NSUInteger toIndex = [container.subviews indexOfObjectIdenticalTo:to];
    if (fromIndex == NSNotFound || toIndex == NSNotFound) return NO;
    UIView *front = fromIndex > toIndex ? from : to;
    if (front == from) {
        // Pop: the background belongs to the departing front view.
        return backdrop.superview == from && DONearRect(backdrop.frame, from.bounds);
    }
    // Push: a fixed backdrop is above the old page and below the incoming page.
    NSUInteger backdropIndex = [container.subviews indexOfObjectIdenticalTo:backdrop];
    return backdrop.superview == container && backdropIndex != NSNotFound &&
        fromIndex < backdropIndex && backdropIndex < toIndex;
}
static BOOL DOIsSettled(DONavigationController *nav)
{
    [DOHost.view layoutIfNeeded]; [nav.view layoutIfNeeded]; [nav.topViewController.view layoutIfNeeded];
    return !nav.transitionCoordinator && !nav.topViewController.transitionCoordinator &&
        !nav.topViewController.isMovingToParentViewController && !nav.topViewController.isMovingFromParentViewController;
}
static void DOEnqueue(NSTimeInterval delay, dispatch_block_t block)
{
    [DOSteps addObject:@{@"delay": @(delay), @"block": [block copy]}];
}
static void DOEnqueueNavigation(DONavigationController *nav, dispatch_block_t block)
{
    [DOSteps addObject:@{@"delay": @0.04, @"navigation": nav, @"block": [block copy]}];
}
static void DOExecuteStep(NSDictionary *step)
{
    @try {
        dispatch_block_t block = step[@"block"];
        block();
        DOAdvance();
    } @catch (NSException *exception) {
        DORecord(@"no_unhandled_exception", NO, @{@"name": exception.name, @"reason": exception.reason ?: @"", @"stack": exception.callStackSymbols ?: @[]});
        DOPublish();
    }
}
static void DOAwaitStep(NSDictionary *step, CFTimeInterval deadline, NSInteger quiet)
{
    DONavigationController *nav = step[@"navigation"];
    quiet = DOIsSettled(nav) ? quiet+1 : 0;
    if (quiet >= 3 || CACurrentMediaTime() >= deadline) {
        DOExecuteStep(step);
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.02*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        DOAwaitStep(step, deadline, quiet);
    });
}
static void DOAdvance(void)
{
    if (DOPublished) return;
    if (DOStepIndex >= DOSteps.count) {
        DOContext = @"completion";
        DORecord(@"all_required_screenshots_captured", DOShots.count == 85, @{@"actual": @(DOShots.count), @"expected": @85});
        DOPublish();
        return;
    }
    NSDictionary *step = DOSteps[DOStepIndex++];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)([step[@"delay"] doubleValue]*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (step[@"navigation"]) DOAwaitStep(step, CACurrentMediaTime()+3.0, 0);
        else DOExecuteStep(step);
    });
}
static void DOCheckAmbiguity(UIView *root)
{
    NSMutableArray *ambiguous = [NSMutableArray array];
    for (UIView *view in DODescendants(root, UIView.class)) {
        if ([view.accessibilityIdentifier hasPrefix:@"DO"] && DOVisible(view) && view.hasAmbiguousLayout)
            [ambiguous addObject:view.accessibilityIdentifier];
    }
    DORecord(@"identified_production_and_fixture_views_have_determined_layout", ambiguous.count == 0, @{@"ambiguous": ambiguous});
}

static void DOCapture(UIView *view, NSString *name)
{
    [view layoutIfNeeded]; [CATransaction flush];
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.scale = 2; format.opaque = YES;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:view.bounds.size format:format];
    __block BOOL drawn = NO;
    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        drawn = [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:YES];
    }];
    uint8_t samples[24 * 24 * 4] = {0};
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmap = CGBitmapContextCreate(samples, 24, 24, 8, 24 * 4, space,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    NSMutableSet *colors = [NSMutableSet set];
    if (bitmap && image.CGImage) {
        CGContextDrawImage(bitmap, CGRectMake(0, 0, 24, 24), image.CGImage);
        for (NSInteger i = 0; i < 24 * 24; i++)
            [colors addObject:@((samples[i*4] << 16) | (samples[i*4+1] << 8) | samples[i*4+2])];
    }
    if (bitmap) CGContextRelease(bitmap);
    CGColorSpaceRelease(space);
    NSString *file = [name stringByAppendingPathExtension:@"png"];
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSData *png = UIImagePNGRepresentation(image);
    BOOL saved = [png writeToFile:[documents stringByAppendingPathComponent:file] atomically:YES];
    BOOL valid = drawn && saved && colors.count > 4 && png.length > 128;
    NSDictionary *entry = @{@"file": file, @"case": DOContext ?: @"startup", @"passed": @(valid),
        @"pixelWidth": @(CGImageGetWidth(image.CGImage)), @"pixelHeight": @(CGImageGetHeight(image.CGImage)),
        @"sampledColors": @(colors.count), @"bytes": @(png.length), @"capture": @"UIGraphicsImageRenderer/drawViewHierarchyInRect"};
    [DOShots addObject:entry];
    DORecord(@"native_screenshot_saved_and_nonblank", valid, entry);
}

static void DOBrandCases(DOTheme *theme)
{
    for (NSNumber *widthNumber in @[@320, @390, @430]) {
        for (NSNumber *large in @[@NO, @YES]) {
            DOEnqueue(0.05, ^{
            CGFloat width = widthNumber.doubleValue;
            DOContext = [NSString stringWithFormat:@"%@-brand-%@-%@", theme.key, widthNumber, large.boolValue ? @"large" : @"default"];
            DOMainViewController *home = [DOMainViewController new];
            [DOHost addChildViewController:home];
            [DOHost.view addSubview:home.view];
            home.view.frame = CGRectMake((DOHost.view.bounds.size.width-width)/2, 0, width, 250);
            [home didMoveToParentViewController:DOHost];
            UIImageView *backdrop = [[UIImageView alloc] initWithImage:theme.image];
            backdrop.frame = home.view.bounds;
            backdrop.contentMode = UIViewContentModeScaleAspectFill;
            backdrop.clipsToBounds = YES;
            backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [home.view insertSubview:backdrop atIndex:0];
            UILabel *label = (UILabel *)DOFind(home.view, @"DOBrandLabel");
            UIView *card = DOFind(home.view, @"DOBrandCard");
            BOOL components = [label isKindOfClass:UILabel.class] && card != nil;
            DORecord(@"production_brand_factory_has_required_identifiers", components, nil);
            if (components) {
                if (large.boolValue) {
                    UITraitCollection *traits = [UITraitCollection traitCollectionWithPreferredContentSizeCategory:UIContentSizeCategoryAccessibilityExtraExtraExtraLarge];
                    [DOHost setOverrideTraitCollection:traits forChildViewController:home];
                    // Fixed brand fonts still receive an explicit 28pt override to exercise compression.
                    label.font = [label.font fontWithSize:MAX(28.0, label.font.pointSize)];
                    [label invalidateIntrinsicContentSize];
                }
                [home.view setNeedsLayout]; [home.view layoutIfNeeded];
                CGRect labelRect = [label convertRect:label.bounds toView:card];
                CGFloat natural = ceil([label.text sizeWithAttributes:@{NSFontAttributeName:label.font}].width);
                CGFloat available = CGRectGetWidth(label.bounds);
                CGFloat scale = label.adjustsFontSizeToFitWidth ? MAX(0.01, label.minimumScaleFactor) : 1;
                BOOL naturalWidth = large.boolValue ? available >= natural*scale-1 && available <= natural+2 : fabs(available-natural) <= 2;
                DORecord(@"brand_single_line_natural_width_and_approved_compression", label.numberOfLines == 1 && naturalWidth,
                    @{@"naturalWidth": @(natural), @"actualWidth": @(available), @"fontPoints": @(label.font.pointSize), @"minimumScale": @(scale)});
                DORecord(@"brand_text_bounded_by_real_card", DOContains(card.bounds, labelRect) &&
                    CGRectGetMinX(labelRect) >= 12 && CGRectGetMaxX(labelRect) <= CGRectGetWidth(card.bounds)-12 &&
                    CGRectGetHeight(label.bounds) >= label.font.lineHeight*MIN(1, available/MAX(1,natural))-1,
                    @{@"label": DORect(labelRect), @"card": DORect(card.bounds)});
                DORecord(@"brand_card_matches_requested_viewport", fabs(CGRectGetWidth(home.view.bounds)-width) < 0.5 &&
                    fabs(CGRectGetWidth(card.bounds)-(width-36)) < 1, @{@"viewport": DORect(home.view.bounds), @"card": DORect(card.frame)});
                DOCheckAmbiguity(home.view);
                DOCapture(home.view, DOContext);
            }
            [home willMoveToParentViewController:nil];
            [home.view removeFromSuperview]; [home removeFromParentViewController];
            });
        }
    }
}

static void DOCheckRows(UIViewController *controller, UIView *content)
{
    UITableView *table = (UITableView *)DOFind(content, @"DOFixtureTable");
    UITableViewCell *cell = [table cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    UISwitch *toggle = (UISwitch *)cell.accessoryView;
    DORecord(@"real_table_switch_row_exists", table && cell && [toggle isKindOfClass:UISwitch.class], nil);
    if (!table || !cell || ![toggle isKindOfClass:UISwitch.class]) return;
    [cell layoutIfNeeded];
    UIView *background = cell.backgroundView;
    CGRect switchRect = [toggle convertRect:toggle.bounds toView:cell];
    CGRect backgroundRect = [background convertRect:background.bounds toView:cell];
    CGRect labelRect = [cell.textLabel convertRect:cell.textLabel.bounds toView:cell];
    BOOL coversSwitch = background && DOContains(backgroundRect, switchRect) &&
        fabs(CGRectGetWidth(backgroundRect)-CGRectGetWidth(cell.bounds)) < 1;
    BOOL coloredFill = NO;
    for (UIView *view in DODescendants(background, UIView.class)) {
        CGFloat alpha = view.backgroundColor ? CGColorGetAlpha(view.backgroundColor.CGColor) : 0;
        CGRect fillRect = [view convertRect:view.bounds toView:cell];
        if (alpha > 0 && DOContains(fillRect, switchRect) && DOContains(fillRect, labelRect)) coloredFill = YES;
    }
    DORecord(@"single_full_row_background_encloses_label_and_switch", coversSwitch && coloredFill,
        @{@"background": DORect(backgroundRect), @"switch": DORect(switchRect), @"cell": DORect(cell.bounds)});
    DORecord(@"cell_content_remains_transparent", !cell.contentView.backgroundColor || CGColorGetAlpha(cell.contentView.backgroundColor.CGColor) < 0.001, nil);
    UIColor *thumb = [toggle.thumbTintColor resolvedColorWithTraitCollection:toggle.traitCollection];
    CGFloat r=0,g=0,b=0,a=0; [thumb getRed:&r green:&g blue:&b alpha:&a];
    DORecord(@"switch_thumb_is_white_in_all_themes", r > 0.99 && g > 0.99 && b > 0.99 && a > 0.99, nil);
    DORecord(@"row_label_does_not_overlap_accessory", CGRectGetMaxX(labelRect) <= CGRectGetMinX(switchRect)+1 && DOContains(cell.bounds, switchRect),
        @{@"label": DORect(labelRect), @"switch": DORect(switchRect)});
    for (NSString *identifier in @[@"DOFixtureHeading", @"DOFixtureTable", @"DOFixtureSwitch"]) {
        UIView *view = DOFind(content, identifier);
        CGRect rect = [view convertRect:view.bounds toView:content];
        DORecord([identifier stringByAppendingString:@"_inside_clipped_content"], view && DOVisible(view) && DOContains(content.bounds, rect), @{@"rect": DORect(rect)});
    }
    // Reapplying the production style must not add a second row surface.
    UIView *firstBackground = cell.backgroundView;
    [DOGlobalAppearance styleTableCell:cell]; [cell layoutIfNeeded];
    DORecord(@"styling_is_idempotent_for_row_background", cell.backgroundView == firstBackground, nil);
}

static void DOCheckNavigation(DONavigationController *nav, NSInteger tab)
{
    UIViewController *page = nav.topViewController;
    UIView *bar = DOFind(nav.view, @"DOTopLevelBar");
    CGRect rootRect = [page.view convertRect:page.view.bounds toView:nav.view];
    DORecord(@"navigation_child_root_fills_entire_navigation_bounds", DONearRect(rootRect, nav.view.bounds),
        @{@"childRoot": DORect(rootRect), @"navigation": DORect(nav.view.bounds)});
    DORecord(@"transition_settled_without_alpha_or_transform_residue", page == nav.visibleViewController &&
        CGAffineTransformIsIdentity(page.view.transform) && page.view.alpha > 0.99 && !nav.transitionCoordinator, nil);
    DORecord(@"transition_backdrop_removed_after_completion", !DOFind(nav.view, @"DOTransitionBackdrop"), nil);
    DORecord(@"real_top_level_capsule_visible", bar && DOVisible(bar) && bar.userInteractionEnabled, nil);
    if (!bar) return;
    CGRect barRect = [bar convertRect:bar.bounds toView:nav.view];
    CGRect safe = nav.view.safeAreaLayoutGuide.layoutFrame;
    DORecord(@"navigation_capsule_inside_safe_area", DOContains(safe, barRect) && fabs(barRect.size.height-(DOThemeManager.sharedInstance.enabledTheme.usesTheseus ? 63 : 64))<1 &&
        fabs(CGRectGetMaxY(barRect)-(CGRectGetMaxY(safe)-8))<1, @{@"bar": DORect(barRect), @"safeArea": DORect(safe)});
    BOOL isTheseus = DOThemeManager.sharedInstance.enabledTheme.usesTheseus;
    NSInteger selected = 0;
    if (isTheseus) {
        UIView *stock = DOFind(bar, @"DOStockTheseusTabBar");
        NSArray *items = stock.accessibilityElements;
        DORecord(@"real_theseus_tab_component_and_three_items", stock && [NSStringFromClass(stock.class) containsString:@"TheseusTabBar"] && items.count == 3, nil);
        DORecord(@"theseus_selection_matches_actual_page", [(id<DOTheseusTabSurface>)bar selectedIndex] == tab, @{@"expected": @(tab)});
        for (NSInteger index = 0; index < 3; index++) {
            UIView *item = index < items.count ? items[index] : nil;
            BOOL active = (item.accessibilityTraits & UIAccessibilityTraitSelected) != 0;
            if (active) selected++;
            CGRect rect = [item convertRect:item.bounds toView:bar];
            DORecord(@"theseus_item_visible_with_valid_selection", item && DOVisible(item) && active == (index == tab) && rect.size.width >= 44 && rect.size.height >= 44, @{@"rect": DORect(rect), @"index": @(index)});
            DORecord(@"theseus_theme_has_no_legacy_selection_pills", !DOFind(bar, [NSString stringWithFormat:@"DOTabPill%ld", (long)index]), nil);
        }
        DORecord(@"theseus_actual_glass_surface_linked", DODescendants(page.view, NSClassFromString(@"DOTheseusGlassView")).count > 0, nil);
    } else for (NSInteger index = 0; index < 3; index++) {
        UIButton *button = (UIButton *)DOFind(bar, [NSString stringWithFormat:@"DOTab%ld", (long)index]);
        if (!button) {
            for (UIButton *candidate in DODescendants(bar, UIButton.class)) if (candidate.tag == index) { button = candidate; break; }
        }
        BOOL active = (button.accessibilityTraits & UIAccessibilityTraitSelected) != 0;
        if (active) selected++;
        UIView *pill = DOFind(bar, [NSString stringWithFormat:@"DOTabPill%ld", (long)index]);
        CGRect pillRect = [pill convertRect:pill.bounds toView:bar];
        CGRect buttonRect = [button convertRect:button.bounds toView:bar];
        BOOL clearButton = !button.backgroundColor || CGColorGetAlpha(button.backgroundColor.CGColor) < 0.001;
        BOOL roundedPixels = !active || DOPillHasRoundedPixels(pill);
        DORecord(@"tab_selection_has_one_clipped_surface", pill && button.configuration == nil && !button.selected &&
            clearButton && pill.hidden == !active && pill.layer.masksToBounds && pill.layer.cornerRadius > 0 &&
            DONearRect(pillRect, buttonRect) && roundedPixels,
            @{@"buttonConfigurationIsNil": @(button.configuration == nil), @"buttonSelected": @(button.selected),
              @"buttonClear": @(clearButton), @"pillFound": @(pill != nil), @"pillHidden": @(pill.hidden),
              @"pillMasks": @(pill.layer.masksToBounds), @"pillRadius": @(pill.layer.cornerRadius),
              @"sameFrame": @(DONearRect(pillRect, buttonRect)), @"roundedPixels": @(roundedPixels)});
        CGRect rect = [button convertRect:button.bounds toView:bar];
        CGPoint center = [button convertPoint:CGPointMake(CGRectGetMidX(button.bounds), CGRectGetMidY(button.bounds)) toView:nav.view];
        UIView *hit = [nav.view hitTest:center withEvent:nil];
        BOOL targetReachable = hit == button || [hit isDescendantOfView:button];
        DORecord([NSString stringWithFormat:@"tab_%ld_has_bounds_selection_and_reachable_hit_target", (long)index],
            button && DOVisible(button) && DOContains(bar.bounds, rect) && active == (index == tab) &&
            rect.size.width >= 44 && rect.size.height >= 44 && targetReachable,
            @{@"rect": DORect(rect), @"active": @(active), @"expectedActive": @(index == tab), @"reachable": @(targetReachable)});
    }
    DORecord(@"exactly_one_selected_top_level_tab", selected == 1, @{@"selectedCount": @(selected), @"expectedTab": @(tab)});
    if ([page isKindOfClass:DOMainViewController.class]) {
        DORecord(@"home_root_has_brand_and_no_secondary_content_panel", DOFind(page.view, @"DOBrandCard") && !DOFind(page.view, @"DOPageContent"), nil);
    } else {
        UIView *content = DOFind(page.view, @"DOPageContent");
        CGRect rect = [content convertRect:content.bounds toView:page.view];
        CGRect pageSafe = page.view.safeAreaLayoutGuide.layoutFrame;
        CGFloat expectedWidth = MIN(600, pageSafe.size.width-36);
        CGRect expected = CGRectMake(CGRectGetMidX(pageSafe)-expectedWidth/2, CGRectGetMinY(pageSafe)+8,
            expectedWidth, pageSafe.size.height-93);
        DORecord(@"internal_page_panel_is_clipped_and_has_approved_insets", content && content != page.view &&
            content.clipsToBounds && DOContains(page.view.bounds, rect) && DONearRect(rect, expected),
            @{@"content": DORect(rect), @"expected": DORect(expected), @"clipsToBounds": @(content.clipsToBounds)});
        CGRect panelInNav = [content convertRect:content.bounds toView:nav.view];
        DORecord(@"internal_content_stays_above_real_navigation_capsule", content && CGRectGetMaxY(panelInNav) <= CGRectGetMinY(barRect)-12,
            @{@"contentBottom": @(CGRectGetMaxY(panelInNav)), @"barTop": @(CGRectGetMinY(barRect))});
        UIView *first = [DOGlobalAppearance contentViewForController:page];
        [DOGlobalAppearance styleViewController:page];
        DORecord(@"repeated_page_styling_reuses_same_internal_content", first == content &&
            [DOGlobalAppearance contentViewForController:page] == content, nil);
        DOCheckRows(page, content);
    }
    DOCheckAmbiguity(nav.view);
}

@interface DOHarnessDetailController : UIViewController
@end
@implementation DOHarnessDetailController
- (void)viewDidLoad { [super viewDidLoad]; DOInstallFixturePage(self, @"Detail"); }
@end

static void DONavigationCases(DOTheme *theme)
{
    for (NSNumber *widthNumber in @[@320, @390, @430]) {
        DONavigationController *nav = [DONavigationController new];
        DOEnqueue(0.02, ^{
            CGFloat width = widthNumber.doubleValue;
            [DOHost addChildViewController:nav];
            [DOHost.view addSubview:nav.view];
            nav.view.frame = CGRectMake((DOHost.view.bounds.size.width-width)/2, 0, width, DOHost.view.bounds.size.height);
            [nav didMoveToParentViewController:DOHost];
            DOContext = [NSString stringWithFormat:@"%@-navigation-%@", theme.key, widthNumber];
        });
        DOEnqueueNavigation(nav, ^{ DORecord(@"initial_navigation_settles", DOIsSettled(nav), nil); });
        NSMutableSet *captured = [NSMutableSet set];
        NSArray<Class> *classes = @[DOMainViewController.class, DOSettingsController.class, DOCreditsViewController.class];
        NSInteger step = 0;
        for (NSNumber *tabNumber in @[@0, @1, @2, @1, @0, @2, @0]) {
            NSInteger tab = tabNumber.integerValue;
            NSString *context = [NSString stringWithFormat:@"%@-navigation-%@-switch%ld-tab%ld", theme.key, widthNumber, (long)step++, (long)tab];
            DOEnqueueNavigation(nav, ^{ DOContext = context; [nav selectTopLevelTab:tab]; });
            DOEnqueueNavigation(nav, ^{
                DORecord(@"top_level_switch_settles", DOIsSettled(nav), nil);
                DORecord(@"top_level_switch_routes_to_expected_real_UIKit_fixture", [nav.topViewController isKindOfClass:classes[tab]] && nav.viewControllers.count == 1,
                    @{@"visibleClass": NSStringFromClass(nav.topViewController.class), @"stackCount": @(nav.viewControllers.count)});
                DOCheckNavigation(nav, tab);
                if (![captured containsObject:tabNumber]) {
                    NSString *pageName = @[@"home", @"settings", @"about"][tab];
                    DOCapture(nav.view, [NSString stringWithFormat:@"%@-%@-%@", theme.key, widthNumber, pageName]);
                    [captured addObject:tabNumber];
                }
            });
        }
        for (NSInteger tab = 0; tab < 3; tab++) {
            __block UIViewController *root;
            DOHarnessDetailController *detail = [DOHarnessDetailController new];
            DOEnqueueNavigation(nav, ^{ [nav selectTopLevelTab:tab]; });
            DOEnqueueNavigation(nav, ^{
                root = nav.topViewController;
                DOContext = [NSString stringWithFormat:@"%@-navigation-%@-animated-push-tab%ld", theme.key, widthNumber, (long)tab];
                id<UIViewControllerAnimatedTransitioning> animator = [nav navigationController:nav animationControllerForOperation:UINavigationControllerOperationPush fromViewController:root toViewController:detail];
                DORecord(@"nested_navigation_uses_UIKit_standard_transition", animator == nil, nil);
                [nav pushViewController:detail animated:YES];
                DORecord(@"animated_push_has_transition_coordinator", nav.transitionCoordinator != nil, nil);
            });
            if (tab == 1 && widthNumber.integerValue == 390) {
                DOEnqueue(0.12, ^{
                    UIView *backdrop = DOFind(nav.view, @"DOTransitionBackdrop");
                    DORecord(@"push_transition_has_isolating_backdrop", nav.transitionCoordinator != nil && DOVisible(backdrop), nil);
                    DORecord(@"push_backdrop_separates_page_layers", DOTransitionBackdropHasCorrectLayering(nav), nil);
                    DOCapture(nav.view, [NSString stringWithFormat:@"%@-390-push-transition", theme.key]);
                });
            }
            DOEnqueueNavigation(nav, ^{
                DORecord(@"animated_push_finishes", DOIsSettled(nav) && nav.topViewController == detail && nav.viewControllers.count == 2, nil);
                DOCheckNavigation(nav, tab);
            });
            if (tab == 1) {
                DOEnqueueNavigation(nav, ^{ [nav selectTopLevelTab:2]; });
                DOEnqueueNavigation(nav, ^{ [nav selectTopLevelTab:1]; });
                DOEnqueueNavigation(nav, ^{
                    DORecord(@"switching_tabs_preserves_nested_stack", DOIsSettled(nav) && nav.topViewController == detail && nav.viewControllers.count == 2, nil);
                    DOCheckNavigation(nav, 1);
                });
            }
            DOEnqueueNavigation(nav, ^{
                DOContext = [NSString stringWithFormat:@"%@-navigation-%@-animated-pop-tab%ld", theme.key, widthNumber, (long)tab];
                [nav popViewControllerAnimated:YES];
                DORecord(@"animated_pop_has_transition_coordinator", nav.transitionCoordinator != nil, nil);
            });
            if (tab == 1 && widthNumber.integerValue == 390) {
                DOEnqueue(0.12, ^{
                    UIView *backdrop = DOFind(nav.view, @"DOTransitionBackdrop");
                    DORecord(@"pop_transition_has_isolating_backdrop", nav.transitionCoordinator != nil && DOVisible(backdrop), nil);
                    DORecord(@"pop_backdrop_attached_to_front_page", DOTransitionBackdropHasCorrectLayering(nav), nil);
                    DOCapture(nav.view, [NSString stringWithFormat:@"%@-390-pop-transition", theme.key]);
                });
            }
            DOEnqueueNavigation(nav, ^{
                DORecord(@"animated_pop_restores_tab_root", DOIsSettled(nav) && nav.topViewController == root && nav.viewControllers.count == 1, nil);
                DOCheckNavigation(nav, tab);
            });
        }
        DOEnqueueNavigation(nav, ^{
            DOContext = [NSString stringWithFormat:@"%@-navigation-%@-enabled-and-action", theme.key, widthNumber];
            UIViewController *beforeDisable = nav.topViewController;
            [nav setNavigationEnabled:NO]; [nav selectTopLevelTab:0];
            DORecord(@"disabled_navigation_hides_bar_and_blocks_switch", DOFind(nav.view, @"DOTopLevelBar").hidden && nav.topViewController == beforeDisable, nil);
            [nav setNavigationEnabled:YES];
            UIButton *homeButton = (UIButton *)DOFind(nav.view, @"DOTab0");
            if (theme.usesTheseus) {
                UIView *stock = DOFind(nav.view, @"DOStockTheseusTabBar");
                UIView *item = stock.accessibilityElements.firstObject;
                DORecord(@"theseus_original_accessibility_action_routes_selection", [item accessibilityActivate], nil);
            } else [homeButton sendActionsForControlEvents:UIControlEventTouchUpInside];
        });
        DOEnqueueNavigation(nav, ^{
            UIButton *homeButton = (UIButton *)DOFind(nav.view, @"DOTab0");
            DORecord(@"real_tab_control_action_routes_home", DOIsSettled(nav) && (homeButton || theme.usesTheseus) && [nav.topViewController isKindOfClass:DOMainViewController.class], nil);
            DOCheckNavigation(nav, 0);
            BOOL last = DOThemeManager.sharedInstance.selectedIndex == DOThemeManager.sharedInstance.themes.count-1 && widthNumber.integerValue == 430;
            if (!last) {
                [nav willMoveToParentViewController:nil]; [nav.view removeFromSuperview]; [nav removeFromParentViewController];
            }
        });
    }
}

static void DOPublish(void)
{
    if (DOPublished) return;
    DOPublished = YES;
    NSInteger failures = 0;
    for (NSDictionary *check in DOChecks) if (![check[@"passed"] boolValue]) failures++;
    NSURL *manifestURL = [NSBundle.mainBundle URLForResource:@"source-manifest" withExtension:@"json"];
    NSDictionary *manifest = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:manifestURL] options:0 error:nil] ?: @{};
    NSDictionary *report = @{@"schemaVersion": @1, @"complete": @YES, @"passed": @(failures == 0),
        @"failureCount": @(failures), @"assertionCount": @(DOChecks.count), @"checks": DOChecks ?: @[], @"screenshots": DOShots ?: @[],
        @"environment": @{@"platform": @"iOS Simulator", @"systemVersion": UIDevice.currentDevice.systemVersion,
            @"screenBounds": DORect(UIScreen.mainScreen.bounds), @"screenScale": @(UIScreen.mainScreen.scale),
            @"viewports": @[@320, @390, @430], @"minimumOS": @"15.0"},
        @"coverage": @{@"production": @[@"DOGlobalAppearance.m", @"DOTheme.m", @"DONavigationController.m", @"DOModalTransitionScale.m", @"DOModalTransitionPush.m", @"DOModalBackAction.m", @"UIImage+Blur.m"],
            @"themes": @5, @"routingPages": @[@"home", @"settings", @"about"], @"expectedScreenshots": @85,
            @"largeFont": @"AX XXXL trait plus explicit 28pt brand font override",
            @"notTested": @[@"Native Preferences/PSListController", @"jailbreak/business actions", @"complete production home/settings/about page implementations", @"physical-device rendering", @"interactive edge-swipe cancellation"]},
        @"sourceManifest": manifest};
    NSError *error;
    NSData *json = [NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:&error];
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    BOOL saved = json && [json writeToFile:[documents stringByAppendingPathComponent:@"report.json"] atomically:YES];
    NSLog(@"HARNESS_COMPLETE passed=%d failures=%ld screenshots=%lu reportSaved=%d %@", failures == 0, (long)failures, (unsigned long)DOShots.count, saved, error ?: @"");
}

static void DORun(void)
{
    @try {
        DOContext = @"startup";
        DORecord(@"five_production_theme_dictionaries_loaded", DOThemeManager.sharedInstance.themes.count == 5, nil);
        DORecord(@"production_navigation_has_public_tested_API", [DONavigationController instancesRespondToSelector:@selector(selectTopLevelTab:)] &&
            [DONavigationController instancesRespondToSelector:@selector(setNavigationEnabled:)], nil);
        DORecord(@"production_brand_and_content_factories_present", [DOGlobalAppearance respondsToSelector:@selector(brandCardView)] &&
            [DOGlobalAppearance respondsToSelector:@selector(contentViewForController:)], nil);
        DOSteps = [NSMutableArray array]; DOStepIndex = 0;
        for (NSInteger index = 0; index < DOThemeManager.sharedInstance.themes.count; index++) {
            DOTheme *theme = DOThemeManager.sharedInstance.themes[index];
            DOEnqueue(0, ^{
                DOThemeManager.sharedInstance.selectedIndex = index;
                DOContext = theme.key;
                DORecord(@"production_theme_raster_loaded_by_production_image_method", theme.image.CGImage != NULL, @{@"theme": theme.key});
            });
            DOBrandCases(theme);
            DONavigationCases(theme);
        }
        DOAdvance();
        return;
    } @catch (NSException *exception) {
        DORecord(@"no_unhandled_exception", NO, @{@"name": exception.name, @"reason": exception.reason ?: @"", @"stack": exception.callStackSymbols ?: @[]});
    }
    DOPublish();
}

static void DOUncaughtException(NSException *exception)
{
    DORecord(@"no_uncaught_exception", NO, @{@"name": exception.name, @"reason": exception.reason ?: @""});
    DOPublish();
}

@interface DOHarnessSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property(nonatomic, strong) UIWindow *window;
@end
@implementation DOHarnessSceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions
{
    if (![scene isKindOfClass:UIWindowScene.class]) return;
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    DOWindow = self.window;
    DOHost = [UIViewController new];
    DOHost.view.backgroundColor = UIColor.blackColor;
    self.window.rootViewController = DOHost;
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ DORun(); });
}
@end

@interface DOHarnessAppDelegate : UIResponder <UIApplicationDelegate>
@end
@implementation DOHarnessAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions { return YES; }
- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options
{
    UISceneConfiguration *configuration = [[UISceneConfiguration alloc] initWithName:@"Harness" sessionRole:session.role];
    configuration.delegateClass = DOHarnessSceneDelegate.class;
    return configuration;
}
@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        DOChecks = [NSMutableArray array]; DOShots = [NSMutableArray array];
        NSSetUncaughtExceptionHandler(DOUncaughtException);
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(DOHarnessAppDelegate.class));
    }
}
