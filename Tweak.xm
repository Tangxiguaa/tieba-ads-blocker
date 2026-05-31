// == SplashSkipper ==
// Generic splash/launch ad skipper for any iOS app
// Injects into any app to auto-dismiss splash ads

#import <UIKit/UIKit.h>

#pragma mark - Helpers

static NSSet *splashKeywords(void) {
    static NSSet *kw;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        kw = [NSSet setWithObjects:
            @"Splash", @"LaunchAd", @"BootAd", @"StartUp",
            @"AdPage", @"AdView", @"FlashAd", @"FlashView",
            @"GuideView", @"GuidePage", @"WelcomeAd",
            @"SplashAd", @"LaunchView", @"AdLaunch",
            nil];
    });
    return kw;
}

static BOOL isSplashClass(NSString *cn) {
    if (cn.length == 0) return NO;
    for (NSString *kw in splashKeywords()) {
        if ([cn containsString:kw]) return YES;
    }
    return NO;
}

static void removeView(UIView *view) {
    if (!view || view.hidden) return;
    view.hidden = YES;
    [view removeFromSuperview];
}

// Scan and remove any splash views in the hierarchy
static void scanAndRemove(UIView *view) {
    if (!view) return;
    if (isSplashClass(NSStringFromClass([view class]))) {
        removeView(view);
        return;
    }
    for (UIView *sub in [view.subviews copy]) {
        scanAndRemove(sub);
    }
}

// Try to find and tap skip/countdown buttons
static void tryTapSkip(UIView *view) {
    if (!view) return;
    
    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *btn = (UIButton *)view;
        NSString *title = btn.titleLabel.text;
        if (title.length > 0) {
            NSString *lower = title.lowercaseString;
            if ([lower containsString:@"skip"] ||
                [lower containsString:@"\u8df3\u8fc7"] ||
                [lower containsString:@"\u8df3\u904e"] ||
                [lower containsString:@"\u5e7f\u544a"] ||
                [title rangeOfString:@"\u79d2"].location != NSNotFound) {
                [btn sendActionsForControlEvents:UIControlEventTouchUpInside];
                return;
            }
        }
    }
    
    for (UIView *sub in view.subviews) {
        tryTapSkip(sub);
    }
}

#pragma mark - Hooks

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    NSString *cn = NSStringFromClass([self class]);
    if (isSplashClass(cn)) {
        self.view.hidden = YES;
        [self dismissViewControllerAnimated:NO completion:nil];
    }
}
%end

%hook UIWindow
- (void)didAddSubview:(UIView *)subview {
    %orig;
    if (!subview.hidden && isSplashClass(NSStringFromClass([subview class]))) {
        removeView(subview);
    }
}
%end

#pragma mark - Network-level ad blocking via NSURLProtocol

@interface SplashBlockerProtocol : NSURLProtocol
@end

@implementation SplashBlockerProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    NSString *host = request.URL.host.lowercaseString;
    if (host.length == 0) return NO;
    
    static NSArray *adDomains;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        adDomains = @[
            @"gdt.qq.com", @"adash.qq.com", @"adsmind.qq.com",
            @"e.click.taobao.com", @"mobads.baidu.com",
            @"adm.baidu.com", @"splash", @"launchad",
            @"adsservice", @"admaterial",
        ];
    });
    
    for (NSString *d in adDomains) {
        if ([host containsString:d]) return YES;
    }
    return NO;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    NSHTTPURLResponse *resp = [[NSHTTPURLResponse alloc]
        initWithURL:self.request.URL statusCode:204
        HTTPVersion:@"HTTP/1.1" headerFields:@{}];
    [self.client URLProtocol:self didReceiveResponse:resp
          cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)stopLoading {}

@end

%ctor {
    [NSURLProtocol registerClass:[SplashBlockerProtocol class]];
    NSLog(@"[SplashSkipper] v1 loaded - generic splash ad skipper");
    
    // Post-launch cleanup passes at 1s, 3s, and 5s
    NSArray *delays = @[@1.0, @3.0, @5.0];
    for (NSNumber *d in delays) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
            (int64_t)(d.doubleValue * NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{
                for (UIWindow *w in UIApplication.sharedApplication.windows) {
                    tryTapSkip(w);
                    scanAndRemove(w);
                }
            });
    }
}