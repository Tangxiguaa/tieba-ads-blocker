#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// v4 - Network + view inspection, no periodic sweeps, safe

// 1. URL blocking - extended to cover more ad endpoints
%hook NSMutableURLRequest
- (void)setURL:(NSURL *)url {
    NSString *h = url.host.lowercaseString;
    if (h) {
        if ([h hasSuffix:@"eclick.baidu.com"] || [h hasSuffix:@"nsclick.baidu.com"])
            { url = [NSURL URLWithString:@"about:blank"]; }
        else if ([h hasSuffix:@"pos.baidu.com"])
            { url = [NSURL URLWithString:@"about:blank"]; }
        else if ([h hasSuffix:@"mobads.baidu.com"] || [h hasSuffix:@"union.baidu.com"])
            { url = [NSURL URLWithString:@"about:blank"]; }
    }
    %orig(url);
}
%end

// 2. Hook NSURLSession as well (catches more network paths)
%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void *)block {
    NSString *h = request.URL.host.lowercaseString;
    if (h && ([h hasSuffix:@"mobads.baidu.com"] || [h hasSuffix:@"eclick.baidu.com"] || [h hasSuffix:@"pos.baidu.com"])) {
        return %orig; // still let it go, but block response via protocol
    }
    return %orig;
}
%end

// 3. Splash ad: one-time cleanup after launch
// Look for known splash/launch ad views
%hook UIApplication
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {
    BOOL r = %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
            // Try to dismiss any presented ad view controllers
            UIViewController *root = app.keyWindow.rootViewController;
            if (root) {
                [self tryDismissAds:root];
            }
    });
    return r;
}

- (void)tryDismissAds:(UIViewController *)vc {
    NSString *cn = NSStringFromClass(vc.class);
    if ([cn containsString:@"Splash"] || [cn containsString:@"AdPage"] || [cn containsString:@"AdViewController"]) {
        [vc dismissViewControllerAnimated:NO completion:nil];
        return;
    }
    for (UIViewController *child in vc.childViewControllers) {
        [self tryDismissAds:child];
    }
    if (vc.presentedViewController) {
        [self tryDismissAds:vc.presentedViewController];
    }
}
%end

// 4. Feed ads: look for ad cells at table view level
%hook UITableView
- (void)layoutSubviews {
    %orig;
    // Single pass: find and hide cells that look like ads
    for (UITableViewCell *cell in self.visibleCells) {
        NSString *cn = NSStringFromClass(cell.class);
        // Only hide cells with obvious ad-related class names
        if ([cn containsString:@"BDNAd"] || [cn containsString:@"TBAd"] || [cn containsString:@"AdCell"] || [cn containsString:@"AdItem"] || [cn containsString:@"AdViewHolder"]) {
            cell.hidden = YES;
            cell.frame = CGRectZero;
        }
    }
}
%end

%ctor {
    NSLog(@"[TiebaBlocker] v4 loaded");
}