#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSArray<NSString *> *adDomains(void) {
    return @[
        @"cscdn.baidu.com", @"gsp0.baidu.com",
        @"eclick.baidu.com", @"nsclick.baidu.com",
        @"wk.baidu.com", @"cb.baidu.com",
        @"baidutv.baidu.com", @"dup.baidustatic.com",
        @"c.baidu.com", @"wenku.baidu.com",
        @"pos.baidu.com", @"cbjs.baidu.com",
        @"spcode.baidu.com", @"baidustatic.com",
        @"bdimg.com", @"bcebos.com",
        @"appsimg.baidu.com", @"adland.baidu.com",
        @"union.baidu.com", @"adm.baidu.com",
        @"mobads.baidu.com", @"appc.baidu.com",
    ];
}

static NSSet<NSString *> *adClassPrefixes(void) {
    return [NSSet setWithObjects:
        @"BDNAd", @"TBAd", @"NativeAd", @"AdView",
        @"SplashAd", @"FeedAd", @"BannerAd", @"RewardAd",
        @"InsertAd", @"VideoAd", @"ADView", nil
    ];
}

%hook NSMutableURLRequest

- (void)setURL:(NSURL *)url {
    NSString *host = url.host.lowercaseString;
    for (NSString *adDomain in adDomains()) {
        if ([host containsString:adDomain] || [host hasSuffix:adDomain]) {
            url = [NSURL URLWithString:@"about:blank"];
            break;
        }
    }
    %orig(url);
}
%end;

%hook UIApplication
- (void)setDelegate:(id<UIApplicationDelegate>)delegate {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [TiebaAdsBlockerUtils cleanupSplashAd];
    });
}
%end;

%hook UIWindow
- (void)didAddSubview:(UIView *)subview {
    %orig;
    NSString *className = NSStringFromClass([subview class]);
    if ([className containsString:@"Splash"] ||
        [className containsString:@"AdLaunch"] ||
        [className containsString:@"LaunchAd"]) {
        [TiebaAdsBlockerUtils scheduleRemoveAdView:subview afterDelay:0.1];
    }
}
%end;

%hook UITableViewCell
- (void)layoutSubviews {
    %orig;
    static dispatch_once_t once;
    static NSMutableSet<NSString *> *adIdentifierCache = nil;
    dispatch_once(&once, ^{
        adIdentifierCache = [NSMutableSet set];
    });
    NSString *reuseId = self.reuseIdentifier;
    if (reuseId && [adIdentifierCache containsObject:reuseId]) {
        self.hidden = YES;
        self.frame = CGRectZero;
        return;
    }
    if ([TiebaAdsBlockerUtils detectAdInView:self]) {
        [adIdentifierCache addObject:reuseId ?: @""];
        self.hidden = YES;
        self.frame = CGRectZero;
    }
}
%end;

%hook UICollectionViewCell
- (void)layoutSubviews {
    %orig;
    if ([TiebaAdsBlockerUtils detectAdInView:self]) {
        self.hidden = YES;
        self.frame = CGRectZero;
    }
}
%end;

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    NSString *className = NSStringFromClass([self class]);
    if ([className containsString:@"Splash"] ||
        [className containsString:@"AdPage"] ||
        [className containsString:@"Advertise"] ||
        [className containsString:@"ADViewController"]) {
        [self dismissViewControllerAnimated:NO completion:nil];
    }
}
- (void)viewDidLoad {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        [TiebaAdsBlockerUtils removeAdSubviewsFromView:self.view depth:0];
    });
}
%end;