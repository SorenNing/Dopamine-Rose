//
//  SceneDelegate.m
//  Dopamine
//
//  Created by Lars Fröder on 23.09.23.
//

#import "DOSceneDelegate.h"
#import "DONavigationController.h"
#import "DOGlobalAppearance.h"

@interface DOSceneDelegate ()

@end

@implementation DOSceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    window.backgroundColor = [DOGlobalAppearance panelColor];
    window.rootViewController = [[DONavigationController alloc] init];
    [window makeKeyAndVisible];
    self.window = window;
}

+ (void)relaunch
{
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self relaunch]; });
        return;
    }
    DOSceneDelegate *instance = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] || ![scene.delegate isKindOfClass:DOSceneDelegate.class]) continue;
        if (scene.activationState == UISceneActivationStateForegroundActive || scene.activationState == UISceneActivationStateForegroundInactive) {
            instance = (DOSceneDelegate *)scene.delegate;
            break;
        }
    }
    UIWindow *oldWindow = instance.window;
    UIWindowScene *windowScene = oldWindow.windowScene;
    if (!instance || !windowScene || oldWindow.alpha < 1) return;
    [UIView animateWithDuration:0.3 animations:^{
        oldWindow.alpha = 0;
    } completion:^(BOOL finished) {
        UIWindow *window = [[UIWindow alloc] initWithWindowScene:windowScene];
        window.backgroundColor = [DOGlobalAppearance panelColor];
        window.alpha = 0;
        window.rootViewController = [[DONavigationController alloc] init];
        instance.window = window;
        [window makeKeyAndVisible];
        oldWindow.hidden = YES;
        [UIView animateWithDuration:0.3 animations:^{ window.alpha = 1; }];
    }];
}

- (void)sceneDidDisconnect:(UIScene *)scene {
    // Called as the scene is being released by the system.
    // This occurs shortly after the scene enters the background, or when its session is discarded.
    // Release any resources associated with this scene that can be re-created the next time the scene connects.
    // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
}


- (void)sceneDidBecomeActive:(UIScene *)scene {
    // Called when the scene has moved from an inactive state to an active state.
    // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
}


- (void)sceneWillResignActive:(UIScene *)scene {
    // Called when the scene will move from an active state to an inactive state.
    // This may occur due to temporary interruptions (ex. an incoming phone call).
}


- (void)sceneWillEnterForeground:(UIScene *)scene {
    // Called as the scene transitions from the background to the foreground.
    // Use this method to undo the changes made on entering the background.
}


- (void)sceneDidEnterBackground:(UIScene *)scene {
    // Called as the scene transitions from the foreground to the background.
    // Use this method to save data, release shared resources, and store enough scene-specific state information
    // to restore the scene back to its current state.
}


@end
