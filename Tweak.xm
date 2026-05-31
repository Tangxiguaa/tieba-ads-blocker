#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// v5: NSURLProtocol based - blocks ad requests at system level

@interface AdBlocker : NSURLProtocol @end
@implementation AdBlocker

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    NSString *host = request.URL.host.lowercaseString;
    if (!host) return NO;
    if ([host hasSuffix:@"eclick.baidu.com"]) return YES;
    if ([host hasSuffix:@"nsclick.baidu.com"]) return YES;
    if ([host hasSuffix:@"pos.baidu.com"]) return YES;
    if ([host hasSuffix:@"mobads.baidu.com"]) return YES;
    if ([host hasSuffix:@"union.baidu.com"]) return YES;
    if ([host hasSuffix:@"adm.baidu.com"]) return YES;
    return NO;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    NSDictionary *h = @{};
    NSHTTPURLResponse *r = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL statusCode:204 HTTPVersion:@"1.1" headerFields:h];
    [self.client URLProtocol:self didReceiveResponse:r cacheStoragePolicy:0];
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)stopLoading {}
@end

// Hook UIApplication to register NSURLProtocol and hide splash
%hook UIApplication
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {
    [NSURLProtocol registerClass:[AdBlocker class]];
    BOOL r = %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIViewController *root = app.keyWindow.rootViewController;
        [self dismissSplash:root];
    });
    return r;
}
- (void)dismissSplash:(UIViewController *)vc {
    if (!vc) return;
    NSString *cn = NSStringFromClass(vc.class);
    if ([cn containsString:@"Splash"] || [cn containsString:@"AdPage"]) {
        [vc dismissViewControllerAnimated:NO completion:nil]; return;
    }
    for (UIViewController *c in vc.childViewControllers) [self dismissSplash:c];
    if (vc.presentedViewController) [self dismissSplash:vc.presentedViewController];
}
%end

%ctor {
    [NSURLProtocol registerClass:[AdBlocker class]];
    NSLog(@"[TiebaBlocker] v5 loaded");
}