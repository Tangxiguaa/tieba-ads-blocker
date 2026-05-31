// == Bailu Tieba Ads Blocker ==
// For Baidu Tieba iOS 12.5.1 ~ 22.2.1

#import <UIKit/UIKit.h>

static void killView(UIView *view) {
    view.hidden = YES;
    [view removeFromSuperview];
}

%hook TBCCommercialAdBaseCell
- (void)setupUI { killView(((UITableViewCell *)self).contentView); }
- (void)layoutSubviews { ((UIView *)self).frame = CGRectZero; %orig; ((UIView *)self).frame = CGRectZero; killView(((UITableViewCell *)self).contentView); }
%end

%hook TBCCommercialAdSmallImageCell
- (void)setupUI { killView(((UITableViewCell *)self).contentView); }
- (void)layoutSubviews { ((UIView *)self).frame = CGRectZero; %orig; ((UIView *)self).frame = CGRectZero; }
%end

%hook TBCCommercialAdSmallImageContentView
- (void)setupUI { killView((UIView *)self); }
- (void)layoutSubviews { ((UIView *)self).frame = CGRectZero; %orig; ((UIView *)self).frame = CGRectZero; }
%end

%hook TBCLegoVideoNewAdCardCell
- (void)bindData:(id)data { killView(((UITableViewCell *)self).contentView); ((UIView *)self).hidden = YES; }
%end

%hook TBCListViewAdCell
- (void)setupUI { ((UIView *)self).hidden = YES; killView(((UITableViewCell *)self).contentView); }
- (void)layoutSubviews { ((UIView *)self).frame = CGRectZero; %orig; ((UIView *)self).frame = CGRectZero; }
%end

%hook TBCPBReplyAdCell
- (void)setupUI { killView(((UITableViewCell *)self).contentView); }
- (void)layoutSubviews { ((UIView *)self).frame = CGRectZero; %orig; ((UIView *)self).frame = CGRectZero; }
%end

%hook TBCPBFirstFloorBannerComponent
- (BOOL)shouldShowBannerView { return NO; }
- (BOOL)shouldShowRecommendAdRecreationView { return NO; }
- (BOOL)shouldShowSimilarBannerView { return NO; }
- (void)setupPbRecommendAdRecreationView {}
- (CGFloat)cardHeight { return 0.0f; }
- (CGFloat)sepSpace { return 0.0f; }
- (CGFloat)topPadding { return 0.0f; }
%end

%hook TBCPBRecommendLiveView
- (BOOL)shouldShowAd { return NO; }
%end

%hook TBCLaunchADViewController
- (BOOL)shouldShowLaunchAd { return NO; }
- (BOOL)shouldInitAd { return NO; }
- (void)initializeAdWindow {}
- (void)viewDidLoad { %orig; for (UIView *sub in self.view.subviews) [sub removeFromSuperview]; }
- (BOOL)isRequestBearAd { return NO; }
- (BOOL)isRequestPLGSplashAd { return NO; }
%end

%hook TBCActivityFloatingView
+ (id)activityFloatingViewWithConfig:(id)config { return nil; }
- (void)showActivityFloatingtWithCurrentVC:(id)vc view:(id)view {}
%end

%hook TBCActivityFloatingViewController
- (id)init { return nil; }
- (void)setHidden:(BOOL)hidden { %orig(YES); }
%end

%hook TBCLiveQuizEntranceItem
- (CGFloat)viewHeight { return 0.0f; }
%end

%hook TBCAdBaseItem
- (BOOL)isEmptyAd { return YES; }
- (BOOL)isVipRemoveAD { return YES; }
- (void)showAdFreeAward:(id)award {}
- (CGFloat)fetchAdFreeAwardHeight { return 0.0f; }
- (void)realShowBearADCellAfter:(id)after {}
%end

%hook TBClientAppDelegate
- (CGFloat)tableView:(id)tableView rowHeightForObject:(id)object {
    Class cls = NSClassFromString(@"TBCAdBaseItem");
    if (cls && [object isKindOfClass:cls]) return 0.0f;
    return %orig;
}
- (void)setObject:(id)object {
    Class cls = NSClassFromString(@"TBCAdBaseItem");
    if (cls && [object isKindOfClass:cls]) return;
    %orig;
}
%end