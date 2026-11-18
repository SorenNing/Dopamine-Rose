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
    UIView *pageContent = [DOGlobalAppearance contentViewForController:self];

    UIView *header = [DOPSListItemsController makeHeader:DOLocalizedString(@"Credits_Button_License") withTarget:self];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    [pageContent addSubview:header];

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:pageContent.topAnchor constant:5],
        [header.leadingAnchor constraintEqualToAnchor:pageContent.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:pageContent.trailingAnchor],
        [header.heightAnchor constraintEqualToConstant:70]
    ]];
    
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [pageContent addSubview:self.scrollView];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:header.bottomAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:pageContent.leadingAnchor constant:25],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:pageContent.trailingAnchor],
        [self.scrollView.heightAnchor constraintEqualToConstant:30]
    ]];

    [self setupLicenseButtons];
    
    self.license = [[UITextView alloc] init];
    self.license.translatesAutoresizingMaskIntoConstraints = NO;
    self.license.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;

    [pageContent addSubview:self.license];

    [NSLayoutConstraint activateConstraints:@[
        [self.license.topAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor constant:10],
        [self.license.leadingAnchor constraintEqualToAnchor:pageContent.leadingAnchor constant:20],
        [self.license.trailingAnchor constraintEqualToAnchor:pageContent.trailingAnchor constant:-20],
        [self.license.bottomAnchor constraintEqualToAnchor:pageContent.bottomAnchor]
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

    UILayoutGuide *contentGuide = self.scrollView.contentLayoutGuide;
    NSLayoutXAxisAnchor *lastAnchor = contentGuide.leadingAnchor;
    for (NSUInteger index = 0; index < licenses.count; index++)
    {
        NSDictionary *license = licenses[index];
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = (NSInteger)index;
        [button setTitle:license[@"name"] forState:UIControlStateNormal];
        [button setTitleColor:[DOGlobalAppearance primaryTextColor] forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        [DOGlobalAppearance bindSurfaceColor:@selector(tileColor) toView:button];
        button.tintColor = [DOGlobalAppearance accentColor];
        button.layer.borderWidth = 1;
        button.layer.borderColor = [DOGlobalAppearance glassHighlightColor].CGColor;
        button.layer.cornerRadius = 8;
        button.layer.cornerCurve = kCACornerCurveContinuous;
        button.clipsToBounds = YES;
        button.translatesAutoresizingMaskIntoConstraints = NO;
        [button addTarget:self action:@selector(licenseButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

        [self.scrollView addSubview:button];

        NSString *buttonTitle = license[@"name"];
        CGSize textSize = [buttonTitle sizeWithAttributes:@{NSFontAttributeName: button.titleLabel.font}];
        CGFloat buttonWidth = textSize.width + 20;

        [NSLayoutConstraint activateConstraints: @[
            [button.topAnchor constraintEqualToAnchor:contentGuide.topAnchor],
            [button.bottomAnchor constraintEqualToAnchor:contentGuide.bottomAnchor],
            [button.heightAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.heightAnchor],
            [button.widthAnchor constraintEqualToConstant:buttonWidth],
            [button.leadingAnchor constraintEqualToAnchor:lastAnchor constant:index == 0 ? 0 : 5]
        ]];
        
        lastAnchor = button.trailingAnchor;
    }

    [lastAnchor constraintEqualToAnchor:contentGuide.trailingAnchor constant:-25].active = YES;
}

- (void)licenseButtonTapped:(UIButton *)sender
{
    self.selectedLicense = (int)sender.tag;
    [self.impactGenerator impactOccurred];
}


- (void)setSelectedLicense:(int)selectedLicense
{
    NSArray *licenses = [DOLicenseViewController licenses];
    if (selectedLicense < 0 || (NSUInteger)selectedLicense >= licenses.count) return;
    _selectedLicense = selectedLicense;
    self.license.text = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:licenses[_selectedLicense][@"file"] ofType:@"md"] encoding:NSUTF8StringEncoding error:nil];
    for (UIView *view in self.scrollView.subviews) {
        if (![view isKindOfClass:UIButton.class]) continue;
        UIButton *button = (UIButton *)view;
        button.selected = button.tag == self.selectedLicense;
        [DOGlobalAppearance bindSurfaceColor:button.selected ? @selector(selectedColor) : @selector(tileColor) toView:button];
        [button setTitleColor:[DOGlobalAppearance primaryTextColor] forState:UIControlStateNormal];
    }
}

- (void)dismiss
{
    [self.navigationController popViewControllerAnimated:YES];
}

@end
