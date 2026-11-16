//
//  DONavigationController.h
//  Dopamine
//
//  Created by tomt000 on 04/01/2024.
//

#import <UIKit/UIKit.h>
#import "UIImage+Blur.h"
#import "DOMainViewController.h"
#import "Transition/DOModalTransitionScale.h"
#import "Transition/DOModalTransitionPush.h"

NS_ASSUME_NONNULL_BEGIN

@interface DONavigationController : UINavigationController <UINavigationControllerDelegate>

- (void)selectTopLevelTab:(NSInteger)index;
- (void)setNavigationEnabled:(BOOL)enabled;
@property (nonatomic, readonly) NSInteger selectedTab;

@end

NS_ASSUME_NONNULL_END
