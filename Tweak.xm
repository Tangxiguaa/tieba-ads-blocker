#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Safe Tieba ad blocker - startup friendly

@interface TiebaAdCleaner : NSObject
+ (void)start;
+ (BOOL)isAdView:(UIView *)v;
@end

@implementation TiebaAdCleaner
+ (void)start {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
            [NSTimer scheduledTimerWithTimeInterval:4.0 repeats:YES block:^(NSTimer *t) {
                for (UIWindow *w in UIApplication.sharedApplication.windows) {
                    [TiebaAdCleaner sweepView:w];
                }
            }];
    });
}
+ (BOOL)isAdView:(UIView *)v {
    NSString *cn = NSStringFromClass(v.class);
    if ([cn containsString:@"Ad"] || [cn containsString:@"ad"] ||
        [cn containsString:@"Splash"] || [cn containsString:@"Banner"])
        return YES;
    for (UIView *sub in v.subviews) {
        if ([sub isKindOfClass:[UILabel class]]) {
            NSString *t = [(UILabel *)sub text];
            if (t && ([t containsString:@"\u5e7f\u544a"] || [t containsString:@"AD"])) return YES;
        }
    }
    return NO;
}
+ (void)sweepView:(UIView *)v {
    if ([self isAdView:v]) { v.hidden = YES; return; }
    for (UIView *sub in [v.subviews copy]) { [self sweepView:sub]; }
}
@end

// Network: block ad URLs
%hook NSMutableURLRequest
- (void)setURL:(NSURL *)url {
    NSString *host = url.host.lowercaseString;
    NSArray *blocked = @[@"eclick.baidu.com", @"nsclick.baidu.com",
        @"pos.baidu.com", @"c.baidu.com", @"cb.baidu.com",
        @"dup.baidustatic.com", @"baidustatic.com", @"mobads.baidu.com",
        @"union.baidu.com", @"adm.baidu.com", @"appc.baidu.com"];
    for (NSString *d in blocked) {
        if ([host containsString:d]) { url = [NSURL URLWithString:@"about:blank"]; break; }
    }
    %orig(url);
}
%end

// Cells: hide ad cells
%hook UITableViewCell
- (void)layoutSubviews {
    %orig;
    if ([TiebaAdCleaner isAdView:self]) {
        self.hidden = YES; self.frame = CGRectZero;
    }
}
%end

%hook UICollectionViewCell
- (void)layoutSubviews {
    %orig;
    if ([TiebaAdCleaner isAdView:self]) {
        self.hidden = YES; self.frame = CGRectZero;
    }
}
%end

// Start cleanup after app is ready
%ctor {
    dispatch_async(dispatch_get_main_queue(), ^{
        [TiebaAdCleaner start];
    });
    NSLog(@"[TiebaAdBlocker] Loaded");
}