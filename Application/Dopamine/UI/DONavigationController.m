//
//  DONavigationController.m
//  Dopamine
//
//  Created by tomt000 on 04/01/2024.
//

#import "DONavigationController.h"
#import <objc/runtime.h>
#import "DOModalBackAction.h"
#import "DOGlobalAppearance.h"
#import "DOThemeManager.h"
#import "DOUIManager.h"

// UIKit can wrap transition views; find the actual sibling inside its container.
static UIView *DOTransitionContainerChild(UIView *view, UIView *container)
{
    while (view && view.superview != container) view = view.superview;
    return view;
}

static void DOInstallTransitionBackdrop(id<UIViewControllerTransitionCoordinator> coordinator, UIImageView *background)
{
    if (!coordinator || !background) return;
    __block UIImageView *backdrop = nil;
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        UIView *container = context.containerView;
        UIView *fromView = [context viewForKey:UITransitionContextFromViewKey] ?: [context viewControllerForKey:UITransitionContextFromViewControllerKey].view;
        UIView *toView = [context viewForKey:UITransitionContextToViewKey] ?: [context viewControllerForKey:UITransitionContextToViewControllerKey].view;
        UIView *from = DOTransitionContainerChild(fromView, container);
        UIView *to = DOTransitionContainerChild(toView, container);
        if (!from || !to || from == to || !background.superview) return;
        NSUInteger fromIndex = [container.subviews indexOfObjectIdenticalTo:from];
        NSUInteger toIndex = [container.subviews indexOfObjectIdenticalTo:to];
        if (fromIndex == NSNotFound || toIndex == NSNotFound) return;
        UIView *front = fromIndex > toIndex ? from : to;
        backdrop = [[UIImageView alloc] initWithImage:background.image];
        backdrop.accessibilityIdentifier = @"DOTransitionBackdrop";
        backdrop.userInteractionEnabled = NO;
        backdrop.backgroundColor = background.superview.backgroundColor;
        backdrop.contentMode = background.contentMode;
        backdrop.clipsToBounds = YES;
        backdrop.frame = [background convertRect:background.bounds toView:container];
        [container insertSubview:backdrop belowSubview:front];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [backdrop removeFromSuperview];
    }];
}

@interface DONavigationController ()

@property (nonatomic) UIImageView *backgroundImageView;
@property (nonatomic) DOMainViewController *mainView;
@property (nonatomic) UIView *secondaryBar;
@property (nonatomic) NSArray<UIButton *> *secondaryTabs;
@property (nonatomic) NSMutableDictionary<NSNumber *, NSArray<UIViewController *> *> *tabStacks;
@property (nonatomic) NSInteger selectedTab;
@property (nonatomic) BOOL navigationEnabled;
@property (nonatomic) BOOL switchingTabs;

@end

@implementation DONavigationController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tabStacks = [NSMutableDictionary dictionary];
    self.selectedTab = 0;
    self.navigationEnabled = YES;
    [self setupBackground];
    [self setupSecondaryBar];
    self.delegate = self;
    [self setNavigationBarHidden:YES];
    self.mainView = [[DOMainViewController alloc] init];
    [self setViewControllers:@[self.mainView] animated:NO];
    self.tabStacks[@0] = @[self.mainView];
    self.overrideUserInterfaceStyle = [DOGlobalAppearance interfaceStyle];
    self.view.tintColor = [DOGlobalAppearance accentColor];
    [self updateNavigationForController:self.mainView];
}

- (void)setupBackground
{
    self.view.backgroundColor = [DOGlobalAppearance panelColor];
    self.backgroundImageView = [[UIImageView alloc] init];
    self.backgroundImageView.image = [DOGlobalAppearance backgroundImage];
    self.backgroundImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.backgroundImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundImageView.userInteractionEnabled = NO;
    self.backgroundImageView.clipsToBounds = YES;

    [self.view insertSubview:self.backgroundImageView atIndex:0];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.backgroundImageView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.backgroundImageView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.backgroundImageView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.backgroundImageView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)setupSecondaryBar
{
    UIView *bar = self.secondaryBar = [[UIView alloc] init];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    bar.layer.cornerRadius = 32;
    [DOGlobalAppearance applyLiquidGlassToView:bar];
    bar.accessibilityIdentifier = @"DOTopLevelBar";
    bar.hidden = NO;
    [self.view addSubview:bar];
    NSLayoutConstraint *width = [bar.widthAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.widthAnchor constant:-50];
    width.priority = UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        width,
        [bar.widthAnchor constraintLessThanOrEqualToConstant:UI_IPAD_MAX_WIDTH - 14],
        [bar.centerXAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerXAnchor],
        [bar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-8],
        [bar.heightAnchor constraintEqualToConstant:64]
    ]];
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.distribution = UIStackViewDistributionFillEqually;
    stack.spacing = 3;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [bar addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor constant:5],
        [stack.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor constant:-5],
        [stack.topAnchor constraintEqualToAnchor:bar.topAnchor constant:5],
        [stack.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor constant:-5]
    ]];
    BOOL chinese = [NSBundle.mainBundle.preferredLocalizations.firstObject hasPrefix:@"zh"];
    NSArray *titles = @[chinese ? @"主页" : @"Home", DOLocalizedString(@"Menu_Settings_Title"), chinese ? @"关于" : @"About"];
    NSArray *symbols = @[@"house", @"slider.horizontal.3", @"info.circle"];
    NSMutableArray *tabs = [NSMutableArray array];
    for (NSInteger index = 0; index < 3; index++) {
        UIButton *tab = [UIButton buttonWithType:UIButtonTypeCustom];
        tab.tag = index;
        tab.layer.cornerRadius = 27;
        tab.layer.cornerCurve = kCACornerCurveContinuous;
        tab.clipsToBounds = YES;
        // Selection is drawn once by updateNavigationForController:, not by
        // UIButtonConfiguration's additional selected-state background.
        tab.automaticallyUpdatesConfiguration = NO;
        UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
        configuration.background = [UIBackgroundConfiguration clearConfiguration];
        configuration.title = titles[index];
        configuration.image = [UIImage systemImageNamed:symbols[index] withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightRegular]];
        configuration.imagePlacement = NSDirectionalRectEdgeTop;
        configuration.imagePadding = 4;
        configuration.baseForegroundColor = [DOGlobalAppearance primaryTextColor];
        configuration.titleTextAttributesTransformer = ^NSDictionary *(NSDictionary *attributes) {
            NSMutableDictionary *result = attributes.mutableCopy;
            result[NSFontAttributeName] = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
            return result;
        };
        tab.configuration = configuration;
        tab.accessibilityIdentifier = [NSString stringWithFormat:@"DOTab%ld", (long)index];
        [tab addTarget:self action:@selector(topLevelTabPressed:) forControlEvents:UIControlEventTouchUpInside];
        [stack addArrangedSubview:tab];
        [tabs addObject:tab];
    }
    self.secondaryTabs = tabs;
}

- (void)topLevelTabPressed:(UIButton *)sender
{
    [self selectTopLevelTab:sender.tag];
}

- (void)selectTopLevelTab:(NSInteger)index
{
    if (!self.navigationEnabled || self.transitionCoordinator || index < 0 || index > 2) return;
    if (index == self.selectedTab) {
        [self updateNavigationForController:self.topViewController];
        return;
    }
    self.tabStacks[@(self.selectedTab)] = [self.viewControllers copy];
    NSArray<UIViewController *> *stack = self.tabStacks[@(index)];
    if (!stack) {
        Class target = index == 1 ? DOSettingsController.class : DOCreditsViewController.class;
        stack = index == 0 ? @[self.mainView] : @[[[target alloc] init]];
    }
    self.switchingTabs = YES;
    self.selectedTab = index;
    [self setViewControllers:stack animated:NO];
    self.switchingTabs = NO;
    self.tabStacks[@(index)] = [self.viewControllers copy];
    [self updateNavigationForController:self.topViewController];
}

- (void)setNavigationEnabled:(BOOL)enabled
{
    _navigationEnabled = enabled;
    self.secondaryBar.userInteractionEnabled = enabled;
    self.secondaryBar.hidden = !enabled;
}

- (void)updateNavigationForController:(UIViewController *)controller
{
    NSInteger targetTab = self.selectedTab;
    if ([controller isKindOfClass:DOMainViewController.class]) targetTab = 0;
    else if ([controller isKindOfClass:DOSettingsController.class]) targetTab = 1;
    else if ([controller isKindOfClass:DOCreditsViewController.class] || [controller isKindOfClass:NSClassFromString(@"DOLicenseViewController")]) targetTab = 2;
    self.selectedTab = targetTab;
    BOOL result = [controller isKindOfClass:NSClassFromString(@"DOLogCrashViewController")] || [controller isKindOfClass:NSClassFromString(@"DODownloadViewController")];
    self.secondaryBar.hidden = !self.navigationEnabled || result;
    self.secondaryBar.userInteractionEnabled = self.navigationEnabled && !result;
    for (UIButton *tab in self.secondaryTabs) {
        BOOL active = tab.tag == targetTab;
        tab.selected = active;
        tab.backgroundColor = active ? [DOGlobalAppearance selectedColor] : UIColor.clearColor;
        tab.layer.borderWidth = active ? 0.5 : 0;
        tab.layer.borderColor = [DOGlobalAppearance glassHighlightColor].CGColor;
        tab.accessibilityTraits = UIAccessibilityTraitButton | (active ? UIAccessibilityTraitSelected : 0);
    }
    [self.view bringSubviewToFront:self.secondaryBar];
    [self setNeedsStatusBarAppearanceUpdate];
}

#pragma mark - Delegate

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController
           animationControllerForOperation:(UINavigationControllerOperation)operation
                        fromViewController:(UIViewController *)fromVC
                          toViewController:(UIViewController *)toVC {
    // UIKit owns the root frames and transition cancellation. The glass card
    // lives inside each full-sized page and is never a navigation root frame.
    return nil;
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    [DOGlobalAppearance styleViewController:viewController];
    [self updateNavigationForController:viewController];
    if (animated && self.transitionCoordinator) {
        DOInstallTransitionBackdrop(self.transitionCoordinator, self.backgroundImageView);
        __weak typeof(self) weakSelf = self;
        [self.transitionCoordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            DONavigationController *owner = weakSelf;
            [owner updateNavigationForController:owner.topViewController];
        }];
    }
}

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    [self updateNavigationForController:viewController];
    if (!self.switchingTabs) self.tabStacks[@(self.selectedTab)] = [self.viewControllers copy];
}

- (UIViewController *)childViewControllerForStatusBarStyle
{
    return self.visibleViewController;
}

- (UIViewController *)childViewControllerForStatusBarHidden
{
    return self.visibleViewController;
}

- (UIViewController *)childViewControllerForHomeIndicatorAutoHidden
{
    return self.visibleViewController;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self.view sendSubviewToBack:self.backgroundImageView];
    [self.view bringSubviewToFront:self.secondaryBar];
}


@end
