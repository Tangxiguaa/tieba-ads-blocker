#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Safe ad blocker v3 - only block safe-to-block ad domains
// Avoid CDN/API domains that would break connectivity

static BOOL isAdHost(NSString *host) {
    // Only block these specific ad endpoints - safe to block without breaking app
    if ([host hasSuffix:@"eclick.baidu.com"]) return YES;  // ad click
    if ([host hasSuffix:@"nsclick.baidu.com"]) return YES; // ad click
    if ([host hasSuffix:@"pos.baidu.com"]) return YES;     // ad position
    if ([host hasSuffix:@"mobads.baidu.com"]) return YES;  // mobile ads SDK
    if ([host hasSuffix:@"union.baidu.com"]) return YES;   // baidu union
    return NO;
}

%hook NSMutableURLRequest
- (void)setURL:(NSURL *)url {
    if (url.host && isAdHost(url.host.lowercaseString)) {
        url = [NSURL URLWithString:@"about:blank"];
    }
    %orig(url);
}
%end

// Gentle splash window hide after app launches
%hook UIApplication
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {
    BOOL r = %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
            for (UIWindow *w in app.windows) {
                NSString *cn = NSStringFromClass([w class]);
                if ([cn containsString:@"Splash"] || [cn containsString:@"LaunchAd"]) {
                    w.hidden = YES;
                }
            }
    });
    return r;
}
%end

%ctor {
    NSLog(@"[TiebaBlocker] v3 loaded");
}