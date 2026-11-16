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

@interface DONavigationController ()

@property (nonatomic) UIImageView *backgroundImageView;
@property (nonatomic) DOMainViewController *mainView;
@property (nonatomic) DOModalBackAction *backAction;
@property (nonatomic) UIView *secondaryBar;
@property (nonatomic) NSArray<UIButton *> *secondaryTabs;

@end

@implementation DONavigationController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setupBackground];
    [self setupSecondaryBar];
    [self setNavigationBarHidden:YES];
    [self pushViewController:(self.mainView = [[DOMainViewController alloc] init]) animated:NO];
    [self setDelegate:self];
    [self setOverrideUserInterfaceStyle:[DOGlobalAppearance interfaceStyle]];
    self.view.tintColor = [DOGlobalAppearance accentColor];
    self.view.backgroundColor = UIColor.clearColor;
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
        [self.backgroundImageView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-100],
        [self.backgroundImageView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:100],
    ]];

    self.backAction = [[DOModalBackAction alloc] initWithAction:^{
        [self popViewControllerAnimated:YES];
    }];
    self.backAction.translatesAutoresizingMaskIntoConstraints = NO;
    self.backAction.hidden = YES;
    
    [self.view insertSubview:self.backAction aboveSubview:self.backgroundImageView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.backAction.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.backAction.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.backAction.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.backAction.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)setupSecondaryBar
{
    UIView *bar = self.secondaryBar = [[UIView alloc] init];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    bar.layer.cornerRadius = 32;
    [DOGlobalAppearance applyLiquidGlassToView:bar];
    bar.hidden = YES;
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
        UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
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
        [tab addTarget:self action:@selector(selectSecondaryTab:) forControlEvents:UIControlEventTouchUpInside];
        [stack addArrangedSubview:tab];
        [tabs addObject:tab];
    }
    self.secondaryTabs = tabs;
}

- (void)selectSecondaryTab:(UIButton *)sender
{
    if (self.transitionCoordinator) return;
    if (sender.tag == 0) {
        [self popToRootViewControllerAnimated:YES];
        return;
    }
    Class targetClass = sender.tag == 1 ? DOSettingsController.class : DOCreditsViewController.class;
    for (UIViewController *controller in self.viewControllers) {
        if ([controller isKindOfClass:targetClass]) {
            [self popToViewController:controller animated:YES];
            return;
        }
    }
    [self setViewControllers:@[self.mainView, [[targetClass alloc] init]] animated:YES];
}

- (void)setBackgroundDimmed:(BOOL)dimmed
{
    [UIView animateWithDuration:0.3 animations:^{
        self.backgroundImageView.alpha = dimmed ? 0.4 : 1;
    }];
    self.backgroundImageView.userInteractionEnabled = dimmed;
    self.backAction.hidden = !dimmed;
}

#pragma mark - Delegate

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController
           animationControllerForOperation:(UINavigationControllerOperation)operation
                        fromViewController:(UIViewController *)fromVC
                          toViewController:(UIViewController *)toVC {
    
    
    if (fromVC.class == DOMainViewController.class || toVC.class == DOMainViewController.class)
        return [[DOModalTransitionScale alloc] initForwards: operation == UINavigationControllerOperationPush];
    return [[DOModalTransitionPush alloc] initForwards: operation == UINavigationControllerOperationPush];
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    [DOGlobalAppearance styleViewController:viewController];
    [self setBackgroundDimmed:![viewController isKindOfClass:[DOMainViewController class]]];
    [self.backAction setIgnoreFrame:[self contentFrameForViewController:viewController]];
    BOOL main = [viewController isKindOfClass:DOMainViewController.class];
    BOOL result = [viewController isKindOfClass:NSClassFromString(@"DOLogCrashViewController")] || [viewController isKindOfClass:NSClassFromString(@"DODownloadViewController")];
    self.secondaryBar.hidden = main || result;
    NSInteger selected = 1;
    for (UIViewController *controller in self.viewControllers) {
        if ([controller isKindOfClass:DOCreditsViewController.class]) selected = 2;
    }
    for (UIButton *tab in self.secondaryTabs) {
        BOOL active = tab.tag == selected;
        tab.backgroundColor = active ? [DOGlobalAppearance selectedColor] : UIColor.clearColor;
        tab.layer.borderWidth = active ? 0.5 : 0;
        tab.layer.borderColor = [DOGlobalAppearance glassHighlightColor].CGColor;
        tab.accessibilityTraits = UIAccessibilityTraitButton | (active ? UIAccessibilityTraitSelected : 0);
    }
    [self.view bringSubviewToFront:self.secondaryBar];
    [self setNeedsStatusBarAppearanceUpdate];
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

#pragma mark - Overrides

- (CGRect)contentFrameForViewController:(UIViewController *)viewController
{
    if ([viewController isKindOfClass:DOMainViewController.class]) return self.view.bounds;
    CGRect safe = self.view.safeAreaLayoutGuide.layoutFrame;
    CGFloat width = MIN(MAX(0, CGRectGetWidth(safe) - UI_MODAL_PADDING * 2), UI_IPAD_MAX_WIDTH);
    CGFloat availableHeight = MAX(0, CGRectGetHeight(safe) - 93);
    CGFloat height = availableHeight * 0.96;
    return CGRectMake(CGRectGetMidX(safe) - width / 2, CGRectGetMinY(safe) + 8 + (availableHeight - height) / 2, width, height);
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self.view bringSubviewToFront:self.secondaryBar];
    UIViewController *visible = self.visibleViewController;
    if (visible && !self.transitionCoordinator && CGAffineTransformIsIdentity(visible.view.transform)) {
        CGRect frame = [self contentFrameForViewController:visible];
        visible.view.frame = frame;
        [self.backAction setIgnoreFrame:frame];
    }
}


@end
