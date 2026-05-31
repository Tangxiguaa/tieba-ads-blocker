#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#pragma mark - Ad domain list
static NSSet *adDomains(void) {
    static NSSet *domains;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        domains = [NSSet setWithObjects:
            @"cscdn.baidu.com",
            @"gsp0.baidu.com",
            @"eclick.baidu.com",
            @"nsclick.baidu.com",
            @"wk.baidu.com",
            @"cb.baidu.com",
            @"baidutv.baidu.com",
            @"dup.baidustatic.com",
            @"c.baidu.com",
            @"pos.baidu.com",
            @"cbjs.baidu.com",
            @"spcode.baidu.com",
            @"baidustatic.com",
            @"bdimg.com",
            @"bcebos.com",
            @"appsimg.baidu.com",
            @"adland.baidu.com",
            @"union.baidu.com",
            @"adm.baidu.com",
            @"mobads.baidu.com",
            @"afp.baidu.com",
            @"rtax.cdn.cn",
            nil];
    });
    return domains;
}

#pragma mark - NSURLProtocol: intercept & block ad requests
@interface AdBlockerProtocol : NSURLProtocol
@end

@implementation AdBlockerProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    NSString *host = request.URL.host.lowercaseString;
    if (host.length == 0) return NO;
    for (NSString *domain in adDomains()) {
        if ([host containsString:domain] || [host hasSuffix:domain]) {
            return YES;
        }
    }
    return NO;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    id<NSURLProtocolClient> client = self.client;
    NSURL *url = self.request.URL;
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:204 HTTPVersion:@"HTTP/1.1" headerFields:@{}];
    [client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [client URLProtocolDidFinishLoading:self];
}

- (void)stopLoading {}

@end

#pragma mark - Splash ad detection via UIWindow
%hook UIWindow
- (void)didAddSubview:(UIView *)subview {
    %orig;
    NSString *cn = NSStringFromClass([subview class]);
    if ([cn containsString:@"Splash"] || [cn containsString:@"LaunchAd"]) {
        subview.hidden = YES;
    }
}
%end

#pragma mark - ViewController-level splash dismissal
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    NSString *cn = NSStringFromClass([self class]);
    if ([cn containsString:@"Splash"] || [cn containsString:@"AdPage"]) {
        [self dismissViewControllerAnimated:NO completion:nil];
    }
}
%end

#pragma mark - Cell-level ad detection (label text only, never by class name)
%hook UITableViewCell
- (void)layoutSubviews {
    %orig;
    __block BOOL hasAdLabel = NO;
    [self.subviews enumerateObjectsUsingBlock:^(UIView *sub, NSUInteger idx, BOOL *stop) {
        if ([sub isKindOfClass:[UILabel class]]) {
            NSString *t = [(UILabel *)sub text];
            if (t && ([t containsString:@"\u5e7f\u544a"] || [t containsString:@"AD"] || [t containsString:@"ad"])) {
                hasAdLabel = YES;
                *stop = YES;
            }
        }
    }];
    if (hasAdLabel) {
        self.hidden = YES;
        self.frame = CGRectZero;
    }
}
%end

%hook UICollectionViewCell
- (void)layoutSubviews {
    %orig;
    __block BOOL hasAdLabel = NO;
    [self.subviews enumerateObjectsUsingBlock:^(UIView *sub, NSUInteger idx, BOOL *stop) {
        if ([sub isKindOfClass:[UILabel class]]) {
            NSString *t = [(UILabel *)sub text];
            if (t && ([t containsString:@"\u5e7f\u544a"] || [t containsString:@"AD"] || [t containsString:@"ad"])) {
                hasAdLabel = YES;
                *stop = YES;
            }
        }
    }];
    if (hasAdLabel) {
        self.hidden = YES;
        self.frame = CGRectZero;
    }
}
%end

%ctor {
    [NSURLProtocol registerClass:[AdBlockerProtocol class]];
    NSLog(@"[TiebaAdsBlocker v5] Loaded - AdBlockerProtocol registered, %lu domains",
          (unsigned long)[adDomains() count]);
}