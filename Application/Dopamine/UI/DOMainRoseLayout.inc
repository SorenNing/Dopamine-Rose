// Dusty Rose homepage. Included inside DOMainViewController's implementation.
- (UILabel *)roseLabelWithText:(NSString *)text size:(CGFloat)size color:(UIColor *)color
{
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = [UIFont systemFontOfSize:size weight:UIFontWeightRegular];
    label.textColor = color;
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

- (UIView *)roseSpacer:(CGFloat)height
{
    UIView *space = [[UIView alloc] init];
    space.translatesAutoresizingMaskIntoConstraints = NO;
    [space.heightAnchor constraintEqualToConstant:height].active = YES;
    return space;
}

- (void)setupRoseStack
{
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    self.view.backgroundColor = [UIColor colorWithRed:240/255.0 green:218/255.0 blue:222/255.0 alpha:1];
    self.view.tintColor = [DOGlobalAppearance accentColor];
    UIImageView *background = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Background_DustyRose"]];
    background.contentMode = UIViewContentModeScaleToFill;
    background.userInteractionEnabled = NO;
    background.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:background];
    self.roseBackdrop = background;
    [NSLayoutConstraint activateConstraints:@[
        [background.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [background.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [background.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [background.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    UIView *frame = [[UIView alloc] init];
    frame.userInteractionEnabled = NO;
    frame.translatesAutoresizingMaskIntoConstraints = NO;
    frame.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.7].CGColor;
    frame.layer.borderWidth = 1;
    frame.layer.cornerRadius = 28;
    frame.layer.cornerCurve = kCACornerCurveContinuous;
    [self.view addSubview:frame];
    self.roseFrame = frame;
    [NSLayoutConstraint activateConstraints:@[
        [frame.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [frame.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-8],
        [frame.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [frame.widthAnchor constraintLessThanOrEqualToConstant:UI_IPAD_MAX_WIDTH + 48]
    ]];
    NSLayoutConstraint *frameWidth = [frame.widthAnchor constraintEqualToAnchor:self.view.widthAnchor constant:-28];
    frameWidth.priority = UILayoutPriorityDefaultHigh;
    frameWidth.active = YES;

    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.showsVerticalScrollIndicator = NO;
    scroll.alwaysBounceVertical = NO;
    [self.view addSubview:scroll];
    self.roseScrollView = scroll;
    [NSLayoutConstraint activateConstraints:@[
        [scroll.leadingAnchor constraintEqualToAnchor:frame.leadingAnchor constant:14],
        [scroll.trailingAnchor constraintEqualToAnchor:frame.trailingAnchor constant:-14],
        [scroll.topAnchor constraintEqualToAnchor:frame.topAnchor constant:12],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-84]
    ]];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentFill;
    stack.spacing = 0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:stack];
    self.roseStack = stack;
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:14],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-14],
        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-28],
        [stack.heightAnchor constraintGreaterThanOrEqualToAnchor:scroll.frameLayoutGuide.heightAnchor]
    ]];
    [stack addArrangedSubview:[self roseSpacer:22]];
    UILabel *brand = [self roseLabelWithText:@"Dopamine" size:31 color:[DOGlobalAppearance primaryTextColor]];
    brand.font = [UIFont systemFontOfSize:31 weight:UIFontWeightSemibold];
    brand.accessibilityTraits = UIAccessibilityTraitHeader;
    [stack addArrangedSubview:brand];
    [stack setCustomSpacing:7 afterView:brand];
    UILabel *caption = [self roseLabelWithText:@"JAILBREAK" size:9 color:[DOGlobalAppearance secondaryTextColor]];
    [stack addArrangedSubview:caption];
    UIView *topBreathing = [[UIView alloc] init];
    topBreathing.translatesAutoresizingMaskIntoConstraints = NO;
    [stack addArrangedSubview:topBreathing];
    [topBreathing.heightAnchor constraintGreaterThanOrEqualToConstant:28].active = YES;
    NSLayoutConstraint *preferredBreathing = [topBreathing.heightAnchor constraintEqualToConstant:66];
    preferredBreathing.priority = UILayoutPriorityDefaultLow;
    preferredBreathing.active = YES;

    UIView *dotHost = [[UIView alloc] init];
    dotHost.translatesAutoresizingMaskIntoConstraints = NO;
    [dotHost.heightAnchor constraintEqualToConstant:14].active = YES;
    UIView *dot = [[UIView alloc] init];
    dot.translatesAutoresizingMaskIntoConstraints = NO;
    dot.layer.cornerRadius = 4;
    dot.backgroundColor = [DOGlobalAppearance accentColor];
    [dotHost addSubview:dot];
    [NSLayoutConstraint activateConstraints:@[
        [dot.widthAnchor constraintEqualToConstant:8], [dot.heightAnchor constraintEqualToConstant:8],
        [dot.centerXAnchor constraintEqualToAnchor:dotHost.centerXAnchor],
        [dot.centerYAnchor constraintEqualToAnchor:dotHost.centerYAnchor]
    ]];
    [stack addArrangedSubview:dotHost];
    [stack setCustomSpacing:22 afterView:dotHost];
    self.roseStateLabel = [self roseLabelWithText:@"" size:23 color:[DOGlobalAppearance primaryTextColor]];
    self.roseStateLabel.font = [UIFont systemFontOfSize:23 weight:UIFontWeightSemibold];
    self.roseStateLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [stack addArrangedSubview:self.roseStateLabel];
    [stack setCustomSpacing:26 afterView:self.roseStateLabel];
    UIView *support = [[UIView alloc] init];
    support.translatesAutoresizingMaskIntoConstraints = NO;
    support.backgroundColor = [UIColor colorWithRed:250/255.0 green:240/255.0 blue:241/255.0 alpha:1];
    support.layer.cornerRadius = 21;
    support.layer.cornerCurve = kCACornerCurveContinuous;
    self.roseSupportLabel = [self roseLabelWithText:@"" size:11 color:[DOGlobalAppearance secondaryTextColor]];
    [support addSubview:self.roseSupportLabel];
    [NSLayoutConstraint activateConstraints:@[
        [self.roseSupportLabel.leadingAnchor constraintEqualToAnchor:support.leadingAnchor constant:14],
        [self.roseSupportLabel.trailingAnchor constraintEqualToAnchor:support.trailingAnchor constant:-14],
        [self.roseSupportLabel.topAnchor constraintEqualToAnchor:support.topAnchor constant:12],
        [self.roseSupportLabel.bottomAnchor constraintEqualToAnchor:support.bottomAnchor constant:-12],
        [support.heightAnchor constraintGreaterThanOrEqualToConstant:42]
    ]];
    [stack addArrangedSubview:support];
    [stack setCustomSpacing:24 afterView:support];

    __weak typeof(self) weakSelf = self;
    DOActionMenuView *menu = [[DOActionMenuView alloc] initWithActions:@[
        [UIAction actionWithTitle:DOLocalizedString(@"Menu_Settings_Title") image:[UIImage systemImageNamed:@"gearshape"] identifier:@"settings" handler:^(__kindof UIAction *action) {
            [weakSelf.navigationController pushViewController:[[DOSettingsController alloc] init] animated:YES];
        }],
        [UIAction actionWithTitle:DOLocalizedString(@"Menu_Restart_SpringBoard_Title") image:[UIImage systemImageNamed:@"arrow.clockwise"] identifier:@"respring" handler:^(__kindof UIAction *action) {
            [weakSelf fadeToBlack:^{ [[DOEnvironmentManager sharedManager] respring]; }];
        }],
        [UIAction actionWithTitle:DOLocalizedString(@"Menu_Reboot_Userspace_Title") image:[UIImage systemImageNamed:@"arrow.clockwise.circle"] identifier:@"reboot-userspace" handler:^(__kindof UIAction *action) {
            [weakSelf fadeToBlack:^{ [[DOEnvironmentManager sharedManager] rebootUserspace]; }];
        }],
        [UIAction actionWithTitle:DOLocalizedString(@"Menu_Credits_Title") image:[UIImage systemImageNamed:@"info.circle"] identifier:@"credits" handler:^(__kindof UIAction *action) {
            [weakSelf.navigationController pushViewController:[[DOCreditsViewController alloc] init] animated:YES];
        }]
    ] delegate:self];
    menu.translatesAutoresizingMaskIntoConstraints = NO;
    self.roseActionMenu = menu;
    [stack addArrangedSubview:menu];
    [stack setCustomSpacing:24 afterView:menu];
    self.roseUptimeLabel = [self roseLabelWithText:@"" size:10 color:[DOGlobalAppearance secondaryTextColor]];
    self.roseUptimeLabel.font = [UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightRegular];
    [stack addArrangedSubview:self.roseUptimeLabel];
    [stack setCustomSpacing:10 afterView:self.roseUptimeLabel];
    UILabel *credits = [self roseLabelWithText:DOLocalizedString(@"Credits_Made_By") size:10 color:[DOGlobalAppearance secondaryTextColor]];
    [stack addArrangedSubview:credits];
    [stack addArrangedSubview:[self roseSpacer:18]];

    UIAction *jailbreakAction = [UIAction actionWithTitle:[self jailbreakButtonTitle] image:[UIImage systemImageNamed:@"lock.open"] identifier:@"jailbreak" handler:^(__kindof UIAction *action) {
        __strong typeof(weakSelf) controller = weakSelf;
        if (!controller || controller.jailbreakBtn.didExpand) return;
        controller.roseScrollView.scrollEnabled = NO;
        [controller.roseUptimeTimer invalidate];
        controller.roseUptimeTimer = nil;
        [controller.view bringSubviewToFront:controller.jailbreakBtn];
        [controller.roseActionMenu hide];
        [controller.jailbreakBtn expandButton:controller.jailbreakButtonConstraints];
        controller.updateButton.userInteractionEnabled = NO;
        [UIView animateWithDuration:0.45 animations:^{
            controller.roseScrollView.alpha = 0;
            controller.roseFrame.alpha = 0;
            controller.updateButton.alpha = 0;
        }];
        [controller startJailbreak];
    }];
    self.jailbreakBtn = [[DOJailbreakButton alloc] initWithAction:jailbreakAction];
    [self.view addSubview:self.jailbreakBtn];
    self.jailbreakButtonConstraints = @[
        [self.jailbreakBtn.leadingAnchor constraintEqualToAnchor:frame.leadingAnchor constant:16],
        [self.jailbreakBtn.trailingAnchor constraintEqualToAnchor:frame.trailingAnchor constant:-16],
        [self.jailbreakBtn.heightAnchor constraintEqualToConstant:60],
        [self.jailbreakBtn.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16]
    ];
    [NSLayoutConstraint activateConstraints:self.jailbreakButtonConstraints];
    [self refreshRoseState];
    [self updateRoseUptime];
    // Keep the exact upstream check order; the update screen and its handlers are unchanged.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        BOOL environmentUpdate = [[DOUIManager sharedInstance] environmentUpdateAvailable];
        BOOL appUpdate = !environmentUpdate && [[DOUIManager sharedInstance] isUpdateAvailable];
        if (environmentUpdate || appUpdate) {
            dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf setupUpdateAvailable:environmentUpdate]; });
        }
    });
}

- (void)refreshRoseState
{
    DOEnvironmentManager *environment = [DOEnvironmentManager sharedManager];
    BOOL supported = environment.isSupported;
    BOOL jailbroken = environment.isJailbroken || environment.isJailbrokenWithOtherJailbreak;
    self.roseStateLabel.text = !supported ? DOLocalizedString(@"Unsupported") :
        (jailbroken ? DOLocalizedString(@"Status_Title_Jailbroken") : DOLocalizedString(@"Rose_Status_Not_Jailbroken"));
    self.roseSupportLabel.text = [environment versionSupportString];
    self.jailbreakBtn.enabled = supported && !jailbroken;
    [self.jailbreakBtn.button setTitle:[self jailbreakButtonTitle] forState:UIControlStateNormal];
    [self.jailbreakBtn.button setImage:[UIImage systemImageNamed:supported ? @"lock.open" : @"lock.slash"] forState:UIControlStateNormal];
    [self.roseActionMenu.buttonsView.arrangedSubviews enumerateObjectsUsingBlock:^(UIView *view, NSUInteger index, BOOL *stop) {
        if ([view isKindOfClass:DOActionMenuButton.class] && index < self.roseActionMenu.actions.count) {
            ((DOActionMenuButton *)view).enabled = [self actionMenuActionIsEnabled:self.roseActionMenu.actions[index]];
        }
    }];
}

- (void)updateRoseUptime
{
    struct timespec uptime = {0};
    if (clock_gettime(CLOCK_MONOTONIC_RAW, &uptime) != 0) return;
    long seconds = uptime.tv_sec;
    // The existing localizations use %d. Pass int components instead of long varargs.
    self.roseUptimeLabel.text = [NSString stringWithFormat:DOLocalizedString(@"System_Uptime_Format"),
        (int)(seconds / 86400), (int)((seconds / 3600) % 24),
        (int)((seconds / 60) % 60), (int)(seconds % 60)];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (!self.roseScrollView || self.jailbreakBtn.didExpand) return;
    [self updateRoseUptime];
    [self.roseUptimeTimer invalidate];
    __weak typeof(self) weakSelf = self;
    self.roseUptimeTimer = [NSTimer timerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer) {
        [weakSelf updateRoseUptime];
    }];
    [[NSRunLoop mainRunLoop] addTimer:self.roseUptimeTimer forMode:NSRunLoopCommonModes];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.roseUptimeTimer invalidate];
    self.roseUptimeTimer = nil;
}

- (void)dealloc
{
    [self.roseUptimeTimer invalidate];
}
