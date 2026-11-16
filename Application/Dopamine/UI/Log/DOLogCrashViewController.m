//
//  DOLogCrashViewController.m
//  Dopamine
//
//  Created by tomt000 on 14/02/2024.
//

#import "DOLogCrashViewController.h"
#import "DOPSListController.h"
#import "DOPSListItemsController.h"
#import "DOActionMenuButton.h"
#import "DOGlobalAppearance.h"
#import "DOUIManager.h"

@interface DOLogCrashViewController ()

@property (nonatomic, retain) NSString *title;

@end

@implementation DOLogCrashViewController

- (id)initWithTitle:(NSString*)title
{
    if (self = [super init])
    {
        self.title = title;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [DOPSListController setupViewControllerStyle:self];
    UIView *pageContent = [DOGlobalAppearance contentViewForController:self];

    UIView *header = [DOPSListItemsController makeHeader:DOLocalizedString(@"Log_Error") withTarget:self];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    [pageContent addSubview:header];

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:pageContent.topAnchor constant:5],
        [header.leadingAnchor constraintEqualToAnchor:pageContent.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:pageContent.trailingAnchor],
        [header.heightAnchor constraintEqualToConstant:70]
    ]];
    
    __block DOActionMenuButton *shareButton;
    UIAction *shareAction = [UIAction actionWithTitle:DOLocalizedString(@"Button_Share") image:[UIImage systemImageNamed:@"square.and.arrow.up" withConfiguration:[DOGlobalAppearance smallIconImageConfiguration]] identifier:@"share" handler:^(__kindof UIAction * _Nonnull action) {
        [[DOUIManager sharedInstance] shareLogRecordFromView:shareButton];
    }];
    shareButton = [DOActionMenuButton buttonWithAction:shareAction chevron:NO];
    
    shareButton.translatesAutoresizingMaskIntoConstraints = NO;
    [pageContent addSubview:shareButton];

    [NSLayoutConstraint activateConstraints:@[
        [shareButton.centerXAnchor constraintEqualToAnchor:pageContent.centerXAnchor],
        [shareButton.heightAnchor constraintEqualToConstant:30],
        [shareButton.bottomAnchor constraintEqualToAnchor:pageContent.bottomAnchor constant:-30]
    ]];
    
    if (@available(iOS 16.0, *)) {
        _logView = [UITextView textViewUsingTextLayoutManager:false];
    }
    else {
        _logView = [[UITextView alloc] init];
    }
    _logView.translatesAutoresizingMaskIntoConstraints = NO;
    _logView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;

    [pageContent addSubview:_logView];

    [NSLayoutConstraint activateConstraints:@[
        [_logView.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:-12],
        [_logView.leadingAnchor constraintEqualToAnchor:pageContent.leadingAnchor constant:20],
        [_logView.trailingAnchor constraintEqualToAnchor:pageContent.trailingAnchor constant:-20],
        [_logView.bottomAnchor constraintEqualToAnchor:shareButton.topAnchor constant:-10]
    ]];

    NSArray *reverseLog = [[[DOUIManager sharedInstance] logRecord] reverseObjectEnumerator].allObjects;
    _logView.text = [reverseLog componentsJoinedByString:@"\n"];
    _logView.editable = NO;
    _logView.font = [UIFont systemFontOfSize:14];
    _logView.textColor = [DOGlobalAppearance primaryTextColor];
    _logView.tintColor = [DOGlobalAppearance accentColor];
    _logView.backgroundColor = [UIColor clearColor];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    if (!self.isMovingFromParentViewController && !self.navigationController.isBeingDismissed) return;
    [[UIApplication sharedApplication] performSelector:@selector(suspend)];
    [NSThread sleepForTimeInterval:0.3];
    exit(0);
}

- (void)dismiss
{
    [self.navigationController popViewControllerAnimated:YES];
}


@end
