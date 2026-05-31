#import <Foundation/Foundation.h>
﻿#import <UIKit/UIKit.h>

#pragma mark - Configuration

// 百度贴吧广告相关的域名列表（编译期常量，可用逆向新发现随时扩充）
static NSArray<NSString *> *adDomains(void) {
    return @[
        @"cscdn.baidu.com",
        @"gsp0.baidu.com",
        @"eclick.baidu.com",
        @"nsclick.baidu.com",
        @"wk.baidu.com",
        @"cb.baidu.com",
        @"baidutv.baidu.com",
        @"dup.baidustatic.com",
        @"c.baidu.com",
        @"wenku.baidu.com",
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
        @"appc.baidu.com",
    ];
}

// 广告相关的类名前缀/标识（用于视图层次的扫描）
static NSSet<NSString *> *adClassPrefixes(void) {
    return [NSSet setWithObjects:
        @"BDNAd", @"TBAd", @"NativeAd", @"AdView",
        @"SplashAd", @"FeedAd", @"BannerAd", @"RewardAd",
        @"InsertAd", @"VideoAd", @"ADView", nil
    ];
}

#pragma mark - URL Level: 拦截广告网络请求

%hook NSMutableURLRequest

- (void)setURL:(NSURL *)url {
    NSString *host = url.host.lowercaseString;
    for (NSString *adDomain in adDomains()) {
        if ([host containsString:adDomain] || [host hasSuffix:adDomain]) {
            // 替换为本地回环地址，从源头阻断广告请求
            url = [NSURL URLWithString:@"about:blank"];
            break;
        }
    }
    %orig(url);
}

%end

#pragma mark - Splash Ads: 跳过开屏广告

%hook UIApplication

// 拦截开屏广告窗口
- (void)setDelegate:(id<UIApplicationDelegate>)delegate {
    %orig;
    // 延迟清除开屏广告残留
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [TiebaAdsBlockerUtils cleanupSplashAd];
    });
}

%end

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

%end

#pragma mark - Feed & Timeline Ads: 拦截信息流广告数据

// 通用的 TableView/CollectionView 广告单元过滤
%hook UITableView

- (NSInteger)numberOfRowsInSection:(NSInteger)section {
    return %orig;
}

%end

// 拦截 cell 展示，直接隐藏广告 cell
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

    // 通过子视图特征检测广告
    if ([TiebaAdsBlockerUtils detectAdInView:self]) {
        [adIdentifierCache addObject:reuseId ?: @""];
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

#pragma mark - ViewController Level: 移除广告容器

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    NSString *className = NSStringFromClass([self class]);

    // 针对已识别的广告 ViewController 做跳过处理
    if ([className containsString:@"Splash"] ||
        [className containsString:@"AdPage"] ||
        [className containsString:@"Advertise"] ||
        [className containsString:@"ADViewController"]) {
        [self dismissViewControllerAnimated:NO completion:nil];
    }
}

- (void)viewDidLoad {
    %orig;
    // 递归移除子视图中的广告
    dispatch_async(dispatch_get_main_queue(), ^{
        [TiebaAdsBlockerUtils removeAdSubviewsFromView:self.view depth:0];
    });
}

%end

#pragma mark - UIView Level: 在视图层次中检测并隐藏广告

%hook UIView

- (void)didMoveToWindow {
    %orig;
    if (self.window) {
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            [NSTimer scheduledTimerWithTimeInterval:2.0
                                             repeats:YES
                                               block:^(NSTimer *t) {
                [TiebaAdsBlockerUtils periodicAdCleanup];
            }];
        });
    }
}

%end

#pragma mark - Utility Class

@interface TiebaAdsBlockerUtils : NSObject
+ (BOOL)detectAdInView:(UIView *)view;
+ (void)removeAdSubviewsFromView:(UIView *)view depth:(NSInteger)depth;
+ (void)scheduleRemoveAdView:(UIView *)view afterDelay:(NSTimeInterval)delay;
+ (void)cleanupSplashAd;
+ (void)periodicAdCleanup;
@end

@implementation TiebaAdsBlockerUtils

+ (BOOL)detectAdInView:(UIView *)view {
    // 1. 通过 accessibilityIdentifier 检测
    NSString *aid = view.accessibilityIdentifier;
    if (aid && ([aid containsString:@"ad"] || [aid containsString:@"Ad"] ||
                [aid containsString:@"AD"] || [aid containsString:@"广告"])) {
        return YES;
    }

    // 2. 通过类名检测
    NSString *cls = NSStringFromClass([view class]);
    for (NSString *prefix in adClassPrefixes()) {
        if ([cls hasPrefix:prefix] || [cls containsString:prefix]) {
            return YES;
        }
    }

    // 3. 通过 subview 特征检测（AD 标签、特定图片比例等）
    __block BOOL hasAdTag = NO;
    [view.subviews enumerateObjectsUsingBlock:^(UIView *sub, NSUInteger idx, BOOL *stop) {
        if ([sub isKindOfClass:[UILabel class]]) {
            NSString *text = [(UILabel *)sub text];
            if (text && ([text containsString:@"广告"] || [text isEqualToString:@"AD"])) {
                hasAdTag = YES;
                *stop = YES;
            }
        }
    }];
    if (hasAdTag) return YES;

    // 4. 检测图片叠层中的广告水印
    for (UIView *sub in view.subviews) {
        if ([TiebaAdsBlockerUtils detectAdInView:sub]) {
            return YES;
        }
    }

    return NO;
}

+ (void)removeAdSubviewsFromView:(UIView *)view depth:(NSInteger)depth {
    if (depth > 3 || !view) return;

    if ([self detectAdInView:view] && depth > 0) {
        // 直接标记隐藏
        view.hidden = YES;
        // 约束降级
        for (NSLayoutConstraint *constraint in view.constraints) {
            constraint.active = NO;
        }
        view.frame = CGRectZero;
        return;
    }

    for (UIView *sub in [view.subviews copy]) {
        [self removeAdSubviewsFromView:sub depth:depth + 1];
    }
}

+ (void)scheduleRemoveAdView:(UIView *)view afterDelay:(NSTimeInterval)delay {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        view.hidden = YES;
        [view removeFromSuperview];
    });
}

+ (void)cleanupSplashAd {
    // 扫描所有窗口，移除开屏广告
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        NSString *cls = NSStringFromClass([window class]);
        if ([cls containsString:@"Splash"] ||
            [cls containsString:@"Launch"] ||
            [cls containsString:@"Advert"]) {
            window.hidden = YES;
            window.windowLevel = UIWindowLevelNormal - 100;
        }
        [self removeAdSubviewsFromView:window depth:0];
    }
}

+ (void)periodicAdCleanup {
    // 定期清理新出现的广告
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        [self removeAdSubviewsFromView:window depth:0];
    }
}

@end

#pragma mark - Constructor

%ctor {
    NSLog(@"[TiebaAdsBlocker] Loaded — blocking Tieba ads");
}

