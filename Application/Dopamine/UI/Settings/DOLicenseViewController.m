//
//  DOLicenseViewController.m
//  Dopamine
//
//  Created by tomt000 on 13/02/2024.
//

#import "DOLicenseViewController.h"
#import "DOPSListController.h"
#import "DOPSListItemsController.h"
#import "DOUIManager.h"
#import "DOGlobalAppearance.h"

@interface DOLicenseViewController ()

@property (nonatomic, strong) UITextView *license;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, assign) int selectedLicense;

@property (nonatomic, strong) UIImpactFeedbackGenerator *impactGenerator;

@end

@implementation DOLicenseViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [DOPSListController setupViewControllerStyle:self];

    UIView *header = [DOPSListItemsController makeHeader:DOLocalizedString(@"Credits_Button_License") withTarget:self];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:header];

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:5],
        [header.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [header.heightAnchor constraintEqualToConstant:70]
    ]]; 
    
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scrollView];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:header.bottomAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:25],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.heightAnchor constraintEqualToConstant:30]
    ]];

    [self setupLicenseButtons];
    
    self.license = [[UITextView alloc] init];
    self.license.translatesAutoresizingMaskIntoConstraints = NO;

    [self.view addSubview:self.license];

    [NSLayoutConstraint activateConstraints:@[
        [self.license.topAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor constant:10],
        [self.license.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.license.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.license.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:0]
    ]];

    self.license.editable = NO;
    self.license.font = [UIFont systemFontOfSize:14];
    self.license.textColor = [DOGlobalAppearance primaryTextColor];
    self.license.tintColor = [DOGlobalAppearance accentColor];
    self.license.indicatorStyle = [DOGlobalAppearance interfaceStyle] == UIUserInterfaceStyleDark ? UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleBlack;
    self.license.backgroundColor = [UIColor clearColor];
    self.selectedLicense = 0;

    self.impactGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
}

+ (NSArray*)licenses
{
    return @[
        @{
            @"name": @"Dopamine",
            @"file": @"LICENSE"
        },
        @{
            @"name": @"kfd",
            @"file": @"LICENSE_kfd"
        },
        @{
            @"name": @"weightBufs",
            @"file": @"LICENSE_weightBufs"
        },
        @{
            @"name": @"libgrabkernel2",
            @"file": @"LICENSE_libgrabkernel2"
        },
        @{
            @"name": @"ElleKit",
            @"file": @"LICENSE_ElleKit"
        },
        @{
            @"name": @"Fugu15",
            @"file": @"LICENSE_Fugu15"
        },
        @{
            @"name": @"Fugu15_Rootful",
            @"file": @"LICENSE_Fugu15_Rootful"
        },
        @{
            @"name": @"libc",
            @"file": @"LICENSE_libc"
        },
        @{
            @"name": @"ChOma",
            @"file": @"LICENSE_ChOma"
        },
        @{
            @"name": @"XPF",
            @"file": @"LICENSE_XPF"
        },
        @{
            @"name": @"opainject",
            @"file": @"LICENSE_opainject"
        },
        @{
            @"name": @"plooshinit",
            @"file": @"LICENSE_plooshinit"
        },
        @{
            @"name": @"dimentio",
            @"file": @"LICENSE_dimentio"
        },
        @{
            @"name": @"Procursus",
            @"file": @"LICENSE_Procursus"
        },
        @{
            @"name": @"Sileo",
            @"file": @"LICENSE_Sileo"
        },
        @{
            @"name": @"Zebra",
            @"file": @"LICENSE_Zebra"
        },
    ];
}

- (void)setupLicenseButtons
{
    NSArray *licenses = [DOLicenseViewController licenses];

    NSLayoutAnchor *lastAnchor = self.scrollView.leadingAnchor;
    for (NSDictionary *license in licenses)
    {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        [button setTitle:license[@"name"] forState:UIControlStateNormal];
        [button setTitleColor:[DOGlobalAppearance primaryTextColor] forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        button.backgroundColor = UIColor.clearColor;
        button.tintColor = [DOGlobalAppearance accentColor];
        button.layer.borderWidth = 1;
        button.layer.borderColor = [DOGlobalAppearance glassHighlightColor].CGColor;
        button.layer.cornerRadius = 8;
        [DOGlobalAppearance applyLiquidGlassToView:button];
        button.layer.cornerCurve = kCACornerCurveContinuous;
        button.translatesAutoresizingMaskIntoConstraints = NO;
        [button addTarget:self action:@selector(licenseButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

        [self.scrollView addSubview:button];

        NSString *buttonTitle = license[@"name"];
        CGSize textSize = [buttonTitle sizeWithAttributes:@{NSFontAttributeName: button.titleLabel.font}];
        CGFloat buttonWidth = textSize.width + 20;
        
        BOOL isFirst = self.scrollView.leadingAnchor == lastAnchor;

        [NSLayoutConstraint activateConstraints: @[
            [button.centerYAnchor constraintEqualToAnchor:self.scrollView.centerYAnchor],
            [button.heightAnchor constraintEqualToConstant:30],
            [button.widthAnchor constraintEqualToConstant:buttonWidth],
            [button.leadingAnchor constraintEqualToAnchor:lastAnchor constant:isFirst ? 0 : 5]
        ]];
        
        lastAnchor = button.trailingAnchor;
    }

    [lastAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor constant:-25].active = YES;
}

- (void)licenseButtonTapped:(UIButton *)sender
{
    NSInteger index = [self.scrollView.subviews indexOfObject:sender];
    self.selectedLicense = (int)index;
    [self.impactGenerator impactOccurred];
}


- (void)setSelectedLicense:(int)selectedLicense
{
    _selectedLicense = selectedLicense;
    self.license.text = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:[DOLicenseViewController licenses][_selectedLicense][@"file"] ofType:@"md"] encoding:NSUTF8StringEncoding error:nil];
    [self.scrollView.subviews enumerateObjectsUsingBlock:^(UIView *view, NSUInteger idx, BOOL *stop) {
        if ([view isKindOfClass:UIButton.class]) {
            UIButton *button = (UIButton *)view;
            BOOL selected = idx == (NSUInteger)self.selectedLicense;
            button.alpha = 1;
            button.backgroundColor = selected ? [DOGlobalAppearance accentColor] : [[DOGlobalAppearance accentColor] colorWithAlphaComponent:0.06];
            [button setTitleColor:selected ? [DOGlobalAppearance buttonTextColor] : [DOGlobalAppearance primaryTextColor] forState:UIControlStateNormal];
        }
        else {
            view.alpha = idx == (NSUInteger)self.selectedLicense ? 1 : 0.2;
        }
    }];
}

- (void)dismiss
{
    [self.navigationController popViewControllerAnimated:YES];
}

@end
