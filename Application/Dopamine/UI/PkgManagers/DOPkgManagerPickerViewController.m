//
//  DOPkgManagerPickerViewController.m
//  Dopamine
//
//  Created by tomt000 on 11/02/2024.
//

#import "DOPkgManagerPickerViewController.h"
#import "DOPkgManagerPickerView.h"
#import "DOEnvironmentManager.h"
#import "DOPSListController.h"
#import "DOGlobalAppearance.h"


@interface DOPkgManagerPickerViewController ()

@end

@implementation DOPkgManagerPickerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [DOPSListController setupViewControllerStyle:self];
    UIView *pageContent = [DOGlobalAppearance contentViewForController:self];
    DOPkgManagerPickerView *picker = [[DOPkgManagerPickerView alloc] initWithCallback:^(BOOL success) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [[DOEnvironmentManager sharedManager] reinstallPackageManagers];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.navigationController popViewControllerAnimated:YES];
            });
        });
    }];
    picker.translatesAutoresizingMaskIntoConstraints = NO;
    [pageContent addSubview:picker];
    [NSLayoutConstraint activateConstraints:@[
        [picker.leadingAnchor constraintEqualToAnchor:pageContent.leadingAnchor],
        [picker.trailingAnchor constraintEqualToAnchor:pageContent.trailingAnchor],
        [picker.topAnchor constraintEqualToAnchor:pageContent.topAnchor],
        [picker.bottomAnchor constraintEqualToAnchor:pageContent.bottomAnchor]
    ]];
}


@end
