//
//  DOMainViewController.m
//  Dopamine
//
//  Created by tomt000 on 08/01/2024.
//

#import "DOMainViewController.h"
#import "DOUIManager.h"
#import "DOEnvironmentManager.h"
#import "DOJailbreaker.h"
#import "DOGlobalAppearance.h"
#import "DOActionMenuButton.h"
#import "DOUpdateViewController.h"
#import "DOLogCrashViewController.h"
#import "DONavigationController.h"
#import <pthread.h>
#import <sys/sysctl.h>
#import <mach/mach_time.h>
#import <libjailbreak/libjailbreak.h>

// New home-only captions stay local to this controller; existing actions keep their localized titles.
static NSString *DOHomeCaption(NSString *english, NSString *chinese)
{
    NSString *language = NSBundle.mainBundle.preferredLocalizations.firstObject;
    return [language hasPrefix:@"zh"] ? chinese : english;
}

@interface DOMainViewController ()

@property DOJailbreakButton *jailbreakBtn;
@property UIStackView *mainStack;
@property UIView *contentView;
@property UIView *brandCard;
@property UIScrollView *informationScrollView;
@property UIButton *respringButton;
@property UIButton *userspaceButton;
@property UILabel *appBuildInfoLabel;
@property UILabel *appBuildTimeLabel;
@property UILabel *systemVersionLabel;
@property UILabel *systemUptimeLabel;
@property NSTimer *uptimeTimer;
@property(nonatomic) BOOL informationVisible;
@property(nonatomic) BOOL didFade;
@property NSArray<NSLayoutConstraint *> *jailbreakButtonConstraints;
@property DOActionMenuButton *updateButton;
@property(nonatomic) BOOL hideStatusBar;
@property(nonatomic) BOOL hideHomeIndicator;

@end

@implementation DOMainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupStack];
}

// All three themes share the approved native layout. Only the information area scrolls.
- (void)setupStack
{
    self.overrideUserInterfaceStyle = [DOGlobalAppearance interfaceStyle];
    self.view.backgroundColor = UIColor.clearColor;
    self.view.tintColor = [DOGlobalAppearance accentColor];

    self.brandCard = [DOGlobalAppearance brandCardView];
    [self.view addSubview:self.brandCard];

    self.informationScrollView = [[UIScrollView alloc] init];
    self.informationScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.informationScrollView.showsVerticalScrollIndicator = NO;
    self.informationScrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self.view addSubview:self.informationScrollView];

    NSLayoutConstraint *pageWidth = [self.brandCard.widthAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.widthAnchor constant:-36];
    pageWidth.priority = UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        pageWidth,
        [self.brandCard.widthAnchor constraintLessThanOrEqualToConstant:UI_IPAD_MAX_WIDTH],
        [self.brandCard.centerXAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerXAnchor],
        [self.brandCard.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [self.brandCard.heightAnchor constraintEqualToConstant:60],
        [self.informationScrollView.leadingAnchor constraintEqualToAnchor:self.brandCard.leadingAnchor],
        [self.informationScrollView.trailingAnchor constraintEqualToAnchor:self.brandCard.trailingAnchor],
        [self.informationScrollView.topAnchor constraintEqualToAnchor:self.brandCard.bottomAnchor constant:13]
    ]];

    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.informationScrollView addSubview:self.contentView];
    UIStackView *stackView = self.mainStack = [[UIStackView alloc] init];
    stackView.axis = UILayoutConstraintAxisVertical;
    stackView.alignment = UIStackViewAlignmentFill;
    stackView.spacing = 13;
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:stackView];
    [NSLayoutConstraint activateConstraints:@[
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.informationScrollView.contentLayoutGuide.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.informationScrollView.contentLayoutGuide.trailingAnchor],
        [self.contentView.topAnchor constraintEqualToAnchor:self.informationScrollView.contentLayoutGuide.topAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.informationScrollView.contentLayoutGuide.bottomAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.informationScrollView.frameLayoutGuide.widthAnchor],
        [stackView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [stackView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [stackView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [stackView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8]
    ]];
    [stackView addArrangedSubview:[self makeInformationCard]];
    [self refreshSystemInformation];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(resumeSystemInformationUpdates) name:UIApplicationDidBecomeActiveNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(stopUptimeTimer) name:UIApplicationWillResignActiveNotification object:nil];

    // The original restart handlers and their isJailbroken gate are retained.
    __weak typeof(self) weakSelf = self;
    UIAction *respringAction = [UIAction actionWithTitle:DOLocalizedString(@"Menu_Restart_SpringBoard_Title") image:[UIImage systemImageNamed:@"arrow.clockwise"] identifier:@"respring" handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf fadeToBlack:^{
            [[DOEnvironmentManager sharedManager] respring];
        }];
    }];
    UIAction *userspaceAction = [UIAction actionWithTitle:DOLocalizedString(@"Menu_Reboot_Userspace_Title") image:[UIImage systemImageNamed:@"arrow.clockwise.circle"] identifier:@"reboot-userspace" handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf fadeToBlack:^{
            [[DOEnvironmentManager sharedManager] rebootUserspace];
        }];
    }];
    self.respringButton = [self restartCardWithAction:respringAction subtitle:DOHomeCaption(@"Refresh system interface", @"刷新系统界面")];
    self.userspaceButton = [self restartCardWithAction:userspaceAction subtitle:DOHomeCaption(@"Reload the environment", @"重新加载环境")];
    UIStackView *actionView = [[UIStackView alloc] initWithArrangedSubviews:@[self.respringButton, self.userspaceButton]];
    actionView.axis = UILayoutConstraintAxisHorizontal;
    actionView.distribution = UIStackViewDistributionFillEqually;
    actionView.alignment = UIStackViewAlignmentFill;
    actionView.spacing = 11;
    [stackView addArrangedSubview:actionView];
    [actionView.heightAnchor constraintEqualToConstant:97].active = YES;
    
    //Jailbreak Button
    BOOL isJailbroken = [[DOEnvironmentManager sharedManager] isJailbroken] || [[DOEnvironmentManager sharedManager] isJailbrokenWithOtherJailbreak];
    BOOL isSupported = [[DOEnvironmentManager sharedManager] isSupported];

    NSString *jailbreakButtonTitle = [self jailbreakButtonTitle];
        
    UIImage *jailbreakButtonImage;
    if (isSupported)
        jailbreakButtonImage = [UIImage systemImageNamed:@"lock.open" withConfiguration:[DOGlobalAppearance smallIconImageConfiguration]];
    else
        jailbreakButtonImage = [UIImage systemImageNamed:@"lock.slash" withConfiguration:[DOGlobalAppearance smallIconImageConfiguration]];
    
    self.jailbreakBtn = [[DOJailbreakButton alloc] initWithAction: [UIAction actionWithTitle:jailbreakButtonTitle image:jailbreakButtonImage identifier:@"jailbreak" handler:^(__kindof UIAction * _Nonnull action) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

/********************************** roothide specific ************************************/
        if(otherJailbreakActived(false)) {
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:DOLocalizedString(@"Error") message:DOLocalizedString(@"Your device currently has another jailbreak activated, please reboot device.") preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *rebootAction = [UIAlertAction actionWithTitle:DOLocalizedString(@"Button_Close") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                //exit(0);
            }];
            [alertController addAction:rebootAction];
            [self presentViewController:alertController animated:YES completion:nil];
            return;
        }
/********************************** roothide specific ************************************/


        self.informationScrollView.userInteractionEnabled = NO;
        [(DONavigationController *)self.navigationController setNavigationEnabled:NO];
        self.updateButton.userInteractionEnabled = NO;
        [self.view layoutIfNeeded];
        [self.view bringSubviewToFront:self.jailbreakBtn];
        [self.jailbreakBtn expandButton:self.jailbreakButtonConstraints];
        if (!self.jailbreakBtn.didExpand) return;
        [UIView animateWithDuration:0.75 delay:0 usingSpringWithDamping:0.9 initialSpringVelocity:2.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.informationScrollView.alpha = 0;
            self.informationScrollView.transform = CGAffineTransformMakeTranslation(0, -25);
            self.updateButton.alpha = 0;
        } completion:nil];
        
        [self startJailbreak];
        
    }]];
    self.jailbreakBtn.enabled = !isJailbroken && isSupported;
    [self.view addSubview:self.jailbreakBtn];
    [NSLayoutConstraint activateConstraints:(self.jailbreakButtonConstraints = @[
        [self.jailbreakBtn.leadingAnchor constraintEqualToAnchor:self.brandCard.leadingAnchor],
        [self.jailbreakBtn.trailingAnchor constraintEqualToAnchor:self.brandCard.trailingAnchor],
        [self.jailbreakBtn.heightAnchor constraintEqualToConstant:74],
        [self.jailbreakBtn.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-85]
    ])];
    [self.informationScrollView.bottomAnchor constraintEqualToAnchor:self.jailbreakBtn.topAnchor constant:-13].active = YES;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        if ([[DOUIManager sharedInstance] environmentUpdateAvailable])
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setupUpdateAvailable:YES];
            });
        }
        else if ([[DOUIManager sharedInstance] isUpdateAvailable])
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setupUpdateAvailable:NO];
            });
        }
    });
}

- (UIView *)glassCardWithRadius:(CGFloat)radius
{
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.layer.cornerRadius = radius;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    [DOGlobalAppearance applyLiquidGlassToView:card];
    return card;
}

- (UILabel *)labelWithText:(NSString *)text size:(CGFloat)size weight:(UIFontWeight)weight color:(UIColor *)color
{
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = [UIFont systemFontOfSize:size weight:weight];
    label.textColor = color;
    label.numberOfLines = 0;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

- (UIStackView *)informationFieldWithTitleKey:(NSString *)key valueLabel:(UILabel *)valueLabel
{
    NSString *title = [[NSString stringWithFormat:DOLocalizedString(key), @""] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    UILabel *caption = [self labelWithText:title size:10 weight:UIFontWeightRegular color:[DOGlobalAppearance secondaryTextColor]];
    UIStackView *field = [[UIStackView alloc] initWithArrangedSubviews:@[caption, valueLabel]];
    field.axis = UILayoutConstraintAxisVertical;
    field.alignment = UIStackViewAlignmentFill;
    field.spacing = 3;
    return field;
}

- (UIButton *)restartCardWithAction:(UIAction *)action subtitle:(NSString *)subtitle
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.layer.cornerRadius = 23;
    [DOGlobalAppearance applyLiquidGlassToView:button];
    [button addAction:action forControlEvents:UIControlEventTouchUpInside];
    UIImageView *icon = [[UIImageView alloc] initWithImage:action.image];
    icon.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightRegular];
    icon.tintColor = [DOGlobalAppearance accentColor];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.backgroundColor = [DOGlobalAppearance tileColor];
    icon.layer.cornerRadius = 10;
    icon.layer.masksToBounds = YES;
    UILabel *title = [self labelWithText:action.title size:13 weight:UIFontWeightSemibold color:[DOGlobalAppearance primaryTextColor]];
    title.adjustsFontSizeToFitWidth = YES;
    title.minimumScaleFactor = 0.8;
    title.numberOfLines = 1;
    UILabel *detail = [self labelWithText:subtitle size:10 weight:UIFontWeightRegular color:[DOGlobalAppearance secondaryTextColor]];
    detail.numberOfLines = 1;
    detail.adjustsFontSizeToFitWidth = YES;
    UIStackView *content = [[UIStackView alloc] initWithArrangedSubviews:@[icon, title, detail]];
    content.axis = UILayoutConstraintAxisVertical;
    content.alignment = UIStackViewAlignmentLeading;
    content.spacing = 5;
    content.userInteractionEnabled = NO;
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [button addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [icon.widthAnchor constraintEqualToConstant:28],
        [icon.heightAnchor constraintEqualToConstant:28],
        [content.leadingAnchor constraintEqualToAnchor:button.leadingAnchor constant:13],
        [content.trailingAnchor constraintEqualToAnchor:button.trailingAnchor constant:-13],
        [content.centerYAnchor constraintEqualToAnchor:button.centerYAnchor]
    ]];
    button.enabled = [[DOEnvironmentManager sharedManager] isJailbroken];
    button.alpha = button.enabled ? 1 : 0.55;
    button.accessibilityLabel = action.title;
    button.accessibilityHint = subtitle;
    return button;
}

- (UIView *)makeInformationCard
{
    UIView *card = [self glassCardWithRadius:27];
    UIStackView *content = [[UIStackView alloc] init];
    content.axis = UILayoutConstraintAxisVertical;
    content.alignment = UIStackViewAlignmentFill;
    content.spacing = 11;
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:17],
        [content.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-17],
        [content.topAnchor constraintEqualToAnchor:card.topAnchor constant:18],
        [content.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-15]
    ]];
    UILabel *heading = [self labelWithText:DOHomeCaption(@"Device information", @"设备信息") size:11 weight:UIFontWeightMedium color:[DOGlobalAppearance secondaryTextColor]];
    heading.accessibilityTraits = UIAccessibilityTraitHeader;
    [content addArrangedSubview:heading];

    UIView *details = [[UIView alloc] init];
    details.backgroundColor = [DOGlobalAppearance informationPanelColor];
    details.layer.cornerRadius = 19;
    details.layer.cornerCurve = kCACornerCurveContinuous;
    [content addArrangedSubview:details];
    UIStackView *fields = [[UIStackView alloc] init];
    fields.axis = UILayoutConstraintAxisVertical;
    fields.alignment = UIStackViewAlignmentFill;
    fields.spacing = 12;
    fields.translatesAutoresizingMaskIntoConstraints = NO;
    [details addSubview:fields];
    [NSLayoutConstraint activateConstraints:@[
        [fields.leadingAnchor constraintEqualToAnchor:details.leadingAnchor constant:13],
        [fields.trailingAnchor constraintEqualToAnchor:details.trailingAnchor constant:-13],
        [fields.topAnchor constraintEqualToAnchor:details.topAnchor constant:14],
        [fields.bottomAnchor constraintEqualToAnchor:details.bottomAnchor constant:-14]
    ]];
    [fields addArrangedSubview:[self labelWithText:[[DOEnvironmentManager sharedManager] versionSupportString] size:12 weight:UIFontWeightSemibold color:[DOGlobalAppearance primaryTextColor]]];
    [fields addArrangedSubview:[self labelWithText:DOLocalizedString(@"Credits_Made_By") size:11 weight:UIFontWeightMedium color:[DOGlobalAppearance primaryTextColor]]];

    self.systemVersionLabel = [self labelWithText:@"" size:11 weight:UIFontWeightSemibold color:[DOGlobalAppearance primaryTextColor]];
    self.appBuildInfoLabel = [self labelWithText:@"" size:11 weight:UIFontWeightSemibold color:[DOGlobalAppearance primaryTextColor]];
    self.appBuildTimeLabel = [self labelWithText:@"" size:11 weight:UIFontWeightSemibold color:[DOGlobalAppearance primaryTextColor]];
    self.systemUptimeLabel = [self labelWithText:@"" size:11 weight:UIFontWeightSemibold color:[DOGlobalAppearance primaryTextColor]];
    self.systemUptimeLabel.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightSemibold];
    NSArray<UIStackView *> *rows = @[
        [[UIStackView alloc] initWithArrangedSubviews:@[
            [self informationFieldWithTitleKey:@"System version: %@" valueLabel:self.systemVersionLabel],
            [self informationFieldWithTitleKey:@"Build version: %@" valueLabel:self.appBuildInfoLabel]]],
        [[UIStackView alloc] initWithArrangedSubviews:@[
            [self informationFieldWithTitleKey:@"Build time: %@" valueLabel:self.appBuildTimeLabel],
            [self informationFieldWithTitleKey:@"System boot time: %@" valueLabel:self.systemUptimeLabel]]]
    ];
    for (UIStackView *row in rows) {
        row.axis = UILayoutConstraintAxisHorizontal;
        row.distribution = UIStackViewDistributionFillEqually;
        row.alignment = UIStackViewAlignmentTop;
        row.spacing = 10;
        [fields addArrangedSubview:row];
    }
    UIView *separator = [[UIView alloc] init];
    separator.backgroundColor = [DOGlobalAppearance glassHighlightColor];
    [fields addArrangedSubview:separator];
    [separator.heightAnchor constraintEqualToConstant:0.5].active = YES;
    UILabel *notice = [self labelWithText:DOLocalizedString(@"If you encounter any issues, please reproduce them using the official version before reporting.") size:10 weight:UIFontWeightRegular color:[DOGlobalAppearance secondaryTextColor]];
    notice.textAlignment = NSTextAlignmentCenter;
    [fields addArrangedSubview:notice];

    UIView *footer = [[UIView alloc] init];
    UILabel *rootHide = [self labelWithText:@"RootHide" size:10 weight:UIFontWeightMedium color:[DOGlobalAppearance secondaryTextColor]];
    rootHide.textAlignment = NSTextAlignmentCenter;
    rootHide.backgroundColor = [DOGlobalAppearance tileColor];
    rootHide.layer.cornerRadius = 8;
    rootHide.layer.masksToBounds = YES;
    [footer addSubview:rootHide];
    [content addArrangedSubview:footer];
    [NSLayoutConstraint activateConstraints:@[
        [footer.heightAnchor constraintEqualToConstant:22],
        [rootHide.leadingAnchor constraintEqualToAnchor:footer.leadingAnchor],
        [rootHide.topAnchor constraintEqualToAnchor:footer.topAnchor],
        [rootHide.bottomAnchor constraintEqualToAnchor:footer.bottomAnchor],
        [rootHide.widthAnchor constraintEqualToConstant:64]
    ]];
    return card;
}

- (NSString *)jailbreakButtonTitle
{
    BOOL isJailbroken = [[DOEnvironmentManager sharedManager] isJailbroken];
    BOOL isSupported = [[DOEnvironmentManager sharedManager] isSupported];
    BOOL removeJailbreakEnabled = [[DOPreferenceManager sharedManager] boolPreferenceValueForKey:@"removeJailbreakEnabled" fallback:NO];

    NSString *jailbreakButtonTitle = DOLocalizedString(@"Button_Jailbreak_Title");
    if (!isSupported)
        jailbreakButtonTitle = DOLocalizedString(@"Unsupported");
    else if (isJailbroken)
        jailbreakButtonTitle = DOLocalizedString(@"Status_Title_Jailbroken");
    else if (removeJailbreakEnabled)
        jailbreakButtonTitle = DOLocalizedString(@"Button_Remove_Jailbreak");
    
    return jailbreakButtonTitle;
}

// 读取含休眠时间的系统运行时长，不受修改日期或定时器延迟影响。
- (NSString *)systemUptimeDescription
{
    static mach_timebase_info_data_t timebase;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ mach_timebase_info(&timebase); });
    if (timebase.denom == 0) return DOLocalizedString(@"Unknown");
    uint64_t seconds = (uint64_t)((double)mach_continuous_time() * timebase.numer / timebase.denom / NSEC_PER_SEC);
    return [NSString stringWithFormat:DOLocalizedString(@"Uptime_Format"),
        (unsigned long long)(seconds / 86400), (unsigned long long)(seconds / 3600 % 24),
        (unsigned long long)(seconds / 60 % 60), (unsigned long long)(seconds % 60)];
}

// 将包内记录的实际构建时间转换为设备当前时区。
- (NSString *)appBuildTimeDescription
{
    NSTimeInterval timestamp = [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"DOBuildTimestamp"] doubleValue];
    if (timestamp <= 0) return DOLocalizedString(@"Unknown");
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.timeZone = [NSTimeZone localTimeZone];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:timestamp]];
}

// 从本地化格式生成独立标题，动态内容由返回的标签负责显示。
- (UILabel *)addInformationRowToHeader:(DOHeaderView *)header titleKey:(NSString *)key
{
    NSString *title = [[NSString stringWithFormat:DOLocalizedString(key), @""] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    return [header addInformationRowWithTitle:[DOGlobalAppearance secondarySubtitleString:title]];
}

// 返回主页或切回应用时刷新系统版本、注入模式与应用构建信息。
- (void)refreshSystemInformation
{
    DOEnvironmentManager *environment = [DOEnvironmentManager sharedManager];
    NSString *versionAndMode = [NSString stringWithFormat:@"%@ (%@)", environment.systemVersion ?: UIDevice.currentDevice.systemVersion, environment.injectionModeDescription];
    self.systemVersionLabel.text = versionAndMode;
    self.appBuildInfoLabel.text = environment.appVersion ?: DOLocalizedString(@"Unknown");
    self.appBuildTimeLabel.text = [self appBuildTimeDescription];
    [self refreshSystemUptime];
}

// 每次直接读取系统时钟刷新时长，避免逐秒累加造成误差。
- (void)refreshSystemUptime
{
    self.systemUptimeLabel.text = [self systemUptimeDescription];
}

// 仅在主页可见且应用活跃时每秒刷新，滚动期间也保持计时。
- (void)resumeSystemInformationUpdates
{
    if (!self.informationVisible) return;
    [self refreshSystemInformation];
    if (self.uptimeTimer || UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
    __weak typeof(self) weakSelf = self;
    self.uptimeTimer = [NSTimer timerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer) {
        [weakSelf refreshSystemUptime];
    }];
    [[NSRunLoop mainRunLoop] addTimer:self.uptimeTimer forMode:NSRunLoopCommonModes];
}

// 离开主页或进入后台时停止无用刷新。
- (void)stopUptimeTimer
{
    [self.uptimeTimer invalidate];
    self.uptimeTimer = nil;
}

// 显示主页时刷新信息及越狱按钮状态。
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.informationVisible = YES;
    [self resumeSystemInformationUpdates];
    BOOL canRestart = [[DOEnvironmentManager sharedManager] isJailbroken];
    self.respringButton.enabled = canRestart;
    self.userspaceButton.enabled = canRestart;
    self.respringButton.alpha = canRestart ? 1 : 0.55;
    self.userspaceButton.alpha = canRestart ? 1 : 0.55;
    [self.jailbreakBtn.button setTitle:[self jailbreakButtonTitle] forState:UIControlStateNormal];
}

// 页面隐藏后停止计时，返回时按系统时钟恢复。
- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    self.informationVisible = NO;
    [self stopUptimeTimer];
}

// 释放定时器及通知观察，避免页面退出后继续刷新。
- (void)dealloc
{
    [_uptimeTimer invalidate];
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)startJailbreak
{
    DOJailbreaker *jailbreaker = [[DOJailbreaker alloc] init];

    [[DOUIManager sharedInstance] startLogCapture];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        if ([jailbreaker contiguousMappingWorkaroundNeeded]) {
            
            cpu_subtype_t cpuFamily = 0;
            size_t cpuFamilySize = sizeof(cpuFamily);
            sysctlbyname("hw.cpufamily", &cpuFamily, &cpuFamilySize, NULL, 0);
            NSString *workaroundMessage = DOLocalizedString(@"Respring_Required_Message");
            if (cpuFamily == CPUFAMILY_ARM_TYPHOON) {
                workaroundMessage = [workaroundMessage stringByAppendingString:[NSString stringWithFormat:@"\n\n%@", DOLocalizedString(@"Respring_Required_Notice_A8")]];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:DOLocalizedString(@"Respring_Required") message:workaroundMessage preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:DOLocalizedString(@"Respring_Cancel") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) { exit(0); }];
                UIAlertAction *workaroundAction = [UIAlertAction actionWithTitle:DOLocalizedString(@"Apply_Workaround") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                    [jailbreaker applyContiguousMappingWorkaround];
                }];
                [alert addAction:cancelAction];
                [alert addAction:workaroundAction];
                alert.preferredAction = workaroundAction;
                [self presentViewController:alert animated:YES completion:nil];
            });
            return;
        }

        //We need to get the preconfig mutex to start the jailbreak (self.jailbreakBtn.canStartJailbreak)
        [self.jailbreakBtn lockMutex];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.hideHomeIndicator = YES;
        });

        NSError *error;
        BOOL didRemove = NO;
        BOOL showLogs = YES;
        [jailbreaker runWithError:&error didRemoveJailbreak:&didRemove showLogs:&showLogs];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error && showLogs) {
                [[DOUIManager sharedInstance] sendLog:[NSString stringWithFormat:@"Jailbreak failed with error: %@", error] debug:NO];
                [self.jailbreakBtn showResultTitle:DOLocalizedString(@"Log_Error") failed:YES];
                [self.navigationController pushViewController:[[DOLogCrashViewController alloc] initWithTitle:[error localizedDescription]] animated:YES];
            }
            else if (error && !showLogs) {
                [self.jailbreakBtn showResultTitle:DOLocalizedString(@"Log_Error") failed:YES];
                // Used when there is an error that is explainable in such detail that additional logs are not needed
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:DOLocalizedString(@"Log_Error") message:[error localizedDescription] preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *rebootAction = [UIAlertAction actionWithTitle:DOLocalizedString(@"Button_Reboot") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    exec_cmd_trusted(JBROOT_PATH("/sbin/reboot"), NULL);
                }];
                [alertController addAction:rebootAction];
                [self presentViewController:alertController animated:YES completion:nil];
            }
            else if (didRemove) {
                [self.jailbreakBtn showResultTitle:DOLocalizedString(@"Removed_Jailbreak_Alert_Title") failed:NO];
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:DOLocalizedString(@"Removed_Jailbreak_Alert_Title") message:DOLocalizedString(@"Removed_Jailbreak_Alert_Message") preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *rebootAction = [UIAlertAction actionWithTitle:DOLocalizedString(@"Button_Close") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    exit(0);
                }];
                [alertController addAction:rebootAction];
                [self presentViewController:alertController animated:YES completion:nil];
            }
            else {
                // No errors
                [[DOUIManager sharedInstance] completeJailbreak];
                [self.jailbreakBtn showResultTitle:DOLocalizedString(@"Status_Title_Jailbroken") failed:NO];
                [self fadeToBlack: ^{
                    [jailbreaker finalize];
                }];
            }
        });
        [self.jailbreakBtn unlockMutex];
    });
}

-(void)setupUpdateAvailable:(BOOL)environmentUpdate
{
    if (self.jailbreakBtn.didExpand)
        return;

    NSString *title = environmentUpdate ? DOLocalizedString(@"Button_Update_Environment") : DOLocalizedString(@"Button_Update_Available");
    
    NSString *releaseFrom = [[DOUIManager sharedInstance] getLaunchedReleaseTag];
    NSString *releaseTo = [[DOUIManager sharedInstance] getLatestReleaseTag];

    if (environmentUpdate)
    {
/************************************* roothide specfic ***********************************/
        releaseFrom = [[DOEnvironmentManager sharedManager] jailbrokenVersionRootHide];
/************************************* roothide specfic ***********************************/
        releaseTo = [[DOUIManager sharedInstance] getLaunchedReleaseTag];
    }

    self.updateButton = [DOActionMenuButton buttonWithAction:[UIAction actionWithTitle:title image:[UIImage systemImageNamed:@"arrow.down.circle" withConfiguration:[DOGlobalAppearance smallIconImageConfiguration]] identifier:@"update-available" handler:^(__kindof UIAction * _Nonnull action) {
        [self.navigationController pushViewController:[[DOUpdateViewController alloc] initFromTag:releaseFrom toTag:releaseTo] animated:YES];
    }] chevron:NO];

    self.updateButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.mainStack addArrangedSubview:self.updateButton];
    [self.updateButton.heightAnchor constraintEqualToConstant:32].active = YES;

    [self.updateButton setTransform:CGAffineTransformMakeTranslation(0, 25)];
    [self.updateButton setAlpha:0];
    [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.9 initialSpringVelocity:2.0  options: UIViewAnimationOptionCurveEaseInOut animations:^{
        [self.updateButton setTransform:CGAffineTransformIdentity];
        [self.updateButton setAlpha:1];
    } completion:nil];
}

-(void)simulateJailbreak
{
    // Let's simulate a "jailbreak" using grand central dispatch

    DOUIManager *uiManager = [DOUIManager sharedInstance];

    static BOOL didFinish = NO; //not thread safe lol
    

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [uiManager completeJailbreak];
        [uiManager sendLog:@"Rebooting Userspace" debug: NO];
        didFinish = YES;
        [self fadeToBlack: ^{

        }];
    });

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NSThread sleepForTimeInterval:0.2];
        [uiManager sendLog:@"Launching kexploitd" debug: NO];
        [NSThread sleepForTimeInterval:0.5];
        [uiManager sendLog:@"Launching oobPCI" debug: NO];
        [NSThread sleepForTimeInterval:0.15];
        [uiManager sendLog:@"Gaining r/w" debug: NO];
        [NSThread sleepForTimeInterval:0.8];
        [uiManager sendLog:@"Patchfinding" debug: NO];
        NSArray *types = @[@"AMFI", @"PAC", @"KTRR", @"KPP", @"PPL", @"KPF", @"APRR", @"AMCC", @"PAN", @"PXN", @"ASLR", @"OPA"]; //Ever heard of the legendary opa bypass
        while (true)
        {
            [NSThread sleepForTimeInterval:0.6 * rand() / RAND_MAX];
            if (didFinish) break;
            NSString *type = types[arc4random_uniform((uint32_t)types.count)];
            [uiManager sendLog:[NSString stringWithFormat:@"Bypassing %@", type] debug: NO];
        }
    });
}

- (void)fadeToBlack:(void (^)(void))completion
{
    if (self.didFade) return;
    self.didFade = YES;
    UIView *mainView = self.parentViewController.view ?: self.view;
    mainView.layer.cornerRadius = mainView.safeAreaInsets.bottom > 0 ? 32 : 0;
    mainView.layer.cornerCurve = kCACornerCurveContinuous;
    mainView.layer.masksToBounds = YES;
    
    self.hideStatusBar = YES;

    [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.9 initialSpringVelocity:2.0 options: UIViewAnimationOptionCurveEaseInOut animations:^{
        mainView.transform = CGAffineTransformMakeScale(0.9, 0.9);
        mainView.alpha = 0.0;
    } completion:^(BOOL success) {
        completion();
    }];
}

#pragma mark - Action Menu Delegate

- (BOOL)actionMenuShowsChevronForAction:(UIAction *)action
{
    if ([action.identifier isEqualToString:@"settings"] || [action.identifier isEqualToString:@"credits"]) return YES;
    return NO;
}

- (BOOL)actionMenuActionIsEnabled:(UIAction *)action
{
    if ([action.identifier isEqualToString:@"respring"] || [action.identifier isEqualToString:@"reboot-userspace"]) {
        return [[DOEnvironmentManager sharedManager] isJailbroken];
    }
    return YES;
}

#pragma mark - Status Bar

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return [DOGlobalAppearance interfaceStyle] == UIUserInterfaceStyleDark ? UIStatusBarStyleLightContent : UIStatusBarStyleDarkContent;
}

- (BOOL)prefersStatusBarHidden
{
    return self.hideStatusBar;
}

- (BOOL)prefersHomeIndicatorAutoHidden
{
    return self.hideHomeIndicator;
}

- (void)setHideStatusBar:(BOOL)hideStatusBar
{
    _hideStatusBar = hideStatusBar;
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)setHideHomeIndicator:(BOOL)hideHomeIndicator
{
    _hideHomeIndicator = hideHomeIndicator;
    [self setNeedsUpdateOfHomeIndicatorAutoHidden];
}

@end
