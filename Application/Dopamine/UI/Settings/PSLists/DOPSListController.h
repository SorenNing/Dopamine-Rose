//
//  DOPSListController.h
//  Dopamine
//
//  Created by tomt000 on 26/01/2024.
//

#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>


NS_ASSUME_NONNULL_BEGIN

@interface DOPSListController : PSListController

+ (void)setupViewControllerStyle:(UIViewController*)vc;
+ (void)layoutTable:(UITableView *)table inController:(UIViewController *)controller;

@end

NS_ASSUME_NONNULL_END
