#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static UIWindow *findKeyWin(void) {
    if (@available(iOS 13, *)) {
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]] && ((UIWindowScene *)s).activationState == UISceneActivationStateForegroundActive)
                return ((UIWindowScene *)s).keyWindow;
        }
    }
    return UIApplication.sharedApplication.windows.firstObject;
}

static void dismissAds(UIViewController *vc) {
    if (!vc) return;
    NSString *cn = NSStringFromClass(vc.class);
    if ([cn containsString:@"Splash"] || [cn containsString:@"AdPage"] || [cn containsString:@"AdViewController"]) {
        [vc dismissViewControllerAnimated:NO completion:nil];
        return;
    }
    for (UIViewController *child in vc.childViewControllers) dismissAds(child);
    if (vc.presentedViewController) dismissAds(vc.presentedViewController);
}

%hook NSMutableURLRequest
- (void)setURL:(NSURL *)url {
    NSString *h = url.host.lowercaseString;
    if (h && ([h hasSuffix:@"eclick.baidu.com"] || [h hasSuffix:@"nsclick.baidu.com"] || [h hasSuffix:@"pos.baidu.com"] || [h hasSuffix:@"mobads.baidu.com"] || [h hasSuffix:@"union.baidu.com"])) url = [NSURL URLWithString:@"about:blank"];
    %orig(url);
}
%end

%hook UIApplication
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {
    BOOL r = %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        dismissAds(findKeyWin().rootViewController);
    });
    return r;
}
%end

%hook UITableView
- (void)layoutSubviews {
    %orig;
    for (UITableViewCell *c in self.visibleCells) {
        NSString *cn = NSStringFromClass(c.class);
        if ([cn containsString:@"BDNAd"] || [cn containsString:@"TBAd"] || [cn containsString:@"AdCell"] || [cn containsString:@"AdItem"]) {
            c.hidden = YES; c.frame = CGRectZero;
        }
    }
}
%end

%ctor { NSLog(@"[TiebaBlocker] v4 loaded"); }