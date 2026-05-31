#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Minimal ad blocker - only blocks ad URLs + specific known ad cells
// NO view sweeping to avoid black screen

static BOOL isAdURL(NSString *host) {
    NSArray *list = @[@"eclick.baidu.com", @"nsclick.baidu.com",
        @"pos.baidu.com", @"c.baidu.com", @"cb.baidu.com",
        @"dup.baidustatic.com", @"baidustatic.com", @"mobads.baidu.com",
        @"union.baidu.com", @"adm.baidu.com", @"appc.baidu.com",
        @"cscdn.baidu.com", @"gsp0.baidu.com", @"wk.baidu.com",
        @"cbjs.baidu.com", @"spcode.baidu.com", @"bdimg.com",
        @"bcebos.com", @"adland.baidu.com"];
    for (NSString *d in list) {
        if ([host containsString:d]) return YES;
    }
    return NO;
}

// Block ad network requests
%hook NSMutableURLRequest
- (void)setURL:(NSURL *)url {
    if (isAdURL(url.host.lowercaseString)) {
        url = [NSURL URLWithString:@"about:blank"];
    }
    %orig(url);
}
%end

// Also hook NSURL to catch URL-based ad loading
%hook NSURL
+ (instancetype)URLWithString:(NSString *)URLString {
    NSURL *url = %orig;
    if (url && isAdURL(url.host.lowercaseString)) {
        return [NSURL URLWithString:@"about:blank"];
    }
    return url;
}
%end

// Splash ad: hook known splash dismissal paths
// Attempt to find and close splash window
%hook UIApplication
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {
    BOOL r = %orig;
    // Delayed splash cleanup - lightweight, just looks for windows with Splash in class name
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
            for (UIWindow *w in app.windows) {
                NSString *cn = NSStringFromClass([w class]);
                if ([cn containsString:@"Splash"] || [cn containsString:@"LaunchAd"]) {
                    w.hidden = YES;
                    w.windowLevel = UIWindowLevelNormal - 10;
                }
            }
    });
    return r;
}
%end

%ctor {
    NSLog(@"[TiebaBlocker] URL blocker loaded");
}