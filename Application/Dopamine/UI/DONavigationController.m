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
        [DOGlobalAppearance registerBackgroundImageView:backdrop];
        backdrop.accessibilityIdentifier = @"DOTransitionBackdrop";
        backdrop.userInteractionEnabled = NO;
        backdrop.backgroundColor = background.superview.backgroundColor;
        backdrop.contentMode = background.contentMode;
        backdrop.clipsToBounds = YES;
        if (front == to) {
            // During a push, hide the previous page behind the entering page.
            backdrop.frame = [background convertRect:background.bounds toView:container];
            [container insertSubview:backdrop belowSubview:to];
        } else {
            // During a pop, move the backdrop with the departing page so the
            // destination is revealed instead of being covered by a blank view.
            backdrop.frame = from.bounds;
            backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [from insertSubview:backdrop atIndex:0];
        }
    } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [backdrop removeFromSuperview];
    }];
}

@interface DONavigationController ()

@property (nonatomic) UIImageView *backgroundImageView;
@property (nonatomic) DOMainViewController *mainView;
@property (nonatomic) UIView *secondaryBar;
@property (nonatomic) NSArray<UIButton *> *secondaryTabs;
@property (nonatomic) NSArray<UIView *> *secondarySelectionPills;
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
    [DOGlobalAppearance registerTextRoot:self.secondaryBar];
    [DOGlobalAppearance registerTextRoot:self.navigationBar];
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
    [DOGlobalAppearance registerBackgroundImageView:self.backgroundImageView];
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
    UIView *bar = self.secondaryBar = [[UIView alloc] initWithFrame:CGRectZero];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    bar.layer.cornerRadius = 32;
    [DOGlobalAppearance applyThemeSurfaceToView:bar];
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
    NSMutableArray *pills = [NSMutableArray array];
    for (NSInteger index = 0; index < 3; index++) {
        UIView *slot = [[UIView alloc] init];
        slot.backgroundColor = UIColor.clearColor;
        UIView *pill = [[UIView alloc] init];
        pill.translatesAutoresizingMaskIntoConstraints = NO;
        pill.userInteractionEnabled = NO;
        pill.accessibilityIdentifier = [NSString stringWithFormat:@"DOTabPill%ld", (long)index];
        pill.layer.cornerRadius = 27;
        pill.layer.cornerCurve = kCACornerCurveContinuous;
        pill.layer.masksToBounds = YES;
        [slot addSubview:pill];
        UIButton *tab = [UIButton buttonWithType:UIButtonTypeCustom];
        tab.tag = index;
        tab.translatesAutoresizingMaskIntoConstraints = NO;
        tab.backgroundColor = UIColor.clearColor;
        // Use plain content views, not UIButtonConfiguration's state-driven
        // background: the rounded sibling pill is the only selection layer.
        UIImageView *symbol = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbols[index] withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightRegular]]];
        symbol.contentMode = UIViewContentModeScaleAspectFit;
        symbol.tintColor = [DOGlobalAppearance primaryTextColor];
        symbol.isAccessibilityElement = NO;
        [symbol.widthAnchor constraintEqualToConstant:20].active = YES;
        [symbol.heightAnchor constraintEqualToConstant:20].active = YES;
        UILabel *caption = [[UILabel alloc] init];
        caption.text = titles[index];
        caption.textColor = [DOGlobalAppearance primaryTextColor];
        caption.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
        caption.textAlignment = NSTextAlignmentCenter;
        caption.numberOfLines = 1;
        caption.adjustsFontSizeToFitWidth = YES;
        caption.minimumScaleFactor = 0.8;
        caption.isAccessibilityElement = NO;
        UIStackView *content = [[UIStackView alloc] initWithArrangedSubviews:@[symbol, caption]];
        content.axis = UILayoutConstraintAxisVertical;
        content.alignment = UIStackViewAlignmentCenter;
        content.spacing = 4;
        content.translatesAutoresizingMaskIntoConstraints = NO;
        content.userInteractionEnabled = NO;
        [tab addSubview:content];
        [NSLayoutConstraint activateConstraints:@[
            [content.centerXAnchor constraintEqualToAnchor:tab.centerXAnchor],
            [content.centerYAnchor constraintEqualToAnchor:tab.centerYAnchor],
            [content.widthAnchor constraintLessThanOrEqualToAnchor:tab.widthAnchor constant:-4]
        ]];
        tab.isAccessibilityElement = YES;
        tab.accessibilityLabel = titles[index];
        tab.accessibilityIdentifier = [NSString stringWithFormat:@"DOTab%ld", (long)index];
        [tab addTarget:self action:@selector(topLevelTabPressed:) forControlEvents:UIControlEventTouchUpInside];
        [slot addSubview:tab];
        [NSLayoutConstraint activateConstraints:@[
            [pill.leadingAnchor constraintEqualToAnchor:slot.leadingAnchor],
            [pill.trailingAnchor constraintEqualToAnchor:slot.trailingAnchor],
            [pill.topAnchor constraintEqualToAnchor:slot.topAnchor],
            [pill.bottomAnchor constraintEqualToAnchor:slot.bottomAnchor],
            [tab.leadingAnchor constraintEqualToAnchor:slot.leadingAnchor],
            [tab.trailingAnchor constraintEqualToAnchor:slot.trailingAnchor],
            [tab.topAnchor constraintEqualToAnchor:slot.topAnchor],
            [tab.bottomAnchor constraintEqualToAnchor:slot.bottomAnchor]
        ]];
        [stack addArrangedSubview:slot];
        [tabs addObject:tab];
        [pills addObject:pill];
    }
    self.secondaryTabs = tabs;
    self.secondarySelectionPills = pills;
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
        // The separate rounded sibling is the only selected surface.
        tab.selected = NO;
        UIView *pill = self.secondarySelectionPills[tab.tag];
        pill.hidden = !active;
        [DOGlobalAppearance bindSurfaceColor:@selector(selectedColor) toView:pill];
        pill.layer.borderWidth = active ? 0.5 : 0;
        pill.layer.borderColor = [DOGlobalAppearance glassHighlightColor].CGColor;
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
