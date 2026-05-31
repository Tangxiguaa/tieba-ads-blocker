#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma mark - Configuration

static NSSet<NSString *> *adClassPrefixes(void) {
    return [NSSet setWithObjects: @"BDNAd", @"TBAd", nil];
}

#pragma mark - URL Level: Block ad requests

%hook NSMutableURLRequest
- (void)setURL:(NSURL *)url {
    NSString *host = url.host.lowercaseString;
    NSArray *domains = @[@"cscdn.baidu.com", @"gsp0.baidu.com",
        @"eclick.baidu.com", @"nsclick.baidu.com", @"wk.baidu.com",
        @"cb.baidu.com", @"baidutv.baidu.com", @"dup.baidustatic.com",
        @"c.baidu.com", @"pos.baidu.com", @"cbjs.baidu.com",
        @"spcode.baidu.com", @"baidustatic.com", @"bdimg.com",
        @"bcebos.com", @"appsimg.baidu.com", @"adland.baidu.com",
        @"union.baidu.com", @"adm.baidu.com", @"mobads.baidu.com", nil];
    for (NSString *adDomain in domains) {
        if ([host containsString:adDomain] || [host hasSuffix:adDomain]) {
            url = [NSURL URLWithString:@"about:blank"];
            break;
        }
    }
    %orig(url);
}
%end

#pragma mark - Splash Ads: Skip launch ads

%hook UIWindow
- (void)didAddSubview:(UIView *)subview {
    %orig;
    NSString *cn = NSStringFromClass([subview class]);
    if ([cn containsString:@"Splash"] || [cn containsString:@"LaunchAd"]) {
        subview.hidden = YES;
    }
}
%end

#pragma mark - Feed Ads: Filter ad cells

%hook UITableViewCell
- (void)layoutSubviews {
    %orig;
    static dispatch_once_t once;
    static NSMutableSet *cache = nil;
    dispatch_once(&once, ^{ cache = [NSMutableSet set]; });
    NSString *rid = self.reuseIdentifier;
    if (rid && [cache containsObject:rid]) { self.hidden = YES; self.frame = CGRectZero; return; }
    if ([TiebaAdsBlockerUtils detectAdInView:self]) {
        [cache addObject:rid ?: @""];
        self.hidden = YES;
        self.frame = CGRectZero;
    }
}
%end

%hook UICollectionViewCell
- (void)layoutSubviews {
    %orig;
    if ([TiebaAdsBlockerUtils detectAdInView:self]) {
        self.hidden = YES;
        self.frame = CGRectZero;
    }
}
%end

#pragma mark - VC Level: Dismiss ad pages

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    NSString *cn = NSStringFromClass([self class]);
    if ([cn containsString:@"Splash"] || [cn containsString:@"AdPage"]) {
        [self dismissViewControllerAnimated:NO completion:nil];
    }
}
%end

#pragma mark - Periodic Cleanup

%hook UIView
- (void)didMoveToWindow {
    %orig;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        [NSTimer scheduledTimerWithTimeInterval:3.0 repeats:YES block:^(NSTimer *t) {
            for (UIWindow *w in UIApplication.sharedApplication.windows) {
                [TiebaAdsBlockerUtils cleanView:w];
            }
        }];
    });
}
%end

@interface TiebaAdsBlockerUtils : NSObject
+ (BOOL)detectAdInView:(UIView *)view;
+ (void)cleanView:(UIView *)view;
@end

@implementation TiebaAdsBlockerUtils

+ (BOOL)detectAdInView:(UIView *)view {
    NSString *aid = view.accessibilityIdentifier;
    if (aid && ([aid containsString:@"ad"] || [aid containsString:@"Ad"] || [aid containsString:@"广告"]))
        return YES;
    NSString *cn = NSStringFromClass([view class]);
    if ([cn containsString:@"Ad"] || [cn containsString:@"ad"]) return YES;
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:[UILabel class]]) {
            NSString *t = [(UILabel *)sub text];
            if (t && ([t containsString:@"广告"] || [t containsString:@"AD"])) return YES;
        }
    }
    for (UIView *sub in view.subviews) {
        if ([self detectAdInView:sub]) return YES;
    }
    return NO;
}

+ (void)cleanView:(UIView *)view {
    if ([self detectAdInView:view]) {
        view.hidden = YES;
        return;
    }
    for (UIView *sub in [view.subviews copy]) {
        [self cleanView:sub];
    }
}

@end

%ctor {
    NSLog(@"[TiebaAdsBlocker] Loaded — blocking Tieba ads");
}