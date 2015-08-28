#import <Cordova/CDVPlugin.h>

#define kCDVOfflinePageWebViewDidStartLoad @"CDVOfflinePageWebViewDidStartLoad"
#define kCDVOfflinePageWebViewShouldStartLoadWithRequest @"CDVOfflinePageWebViewShouldStartLoadWithRequest"
#define kCDVOfflinePageWebViewDidFinishLoad @"CDVOfflinePageWebViewDidFinishLoad"
#define kCDVOfflinePageWebViewDidFailLoadWithError @"CDVOfflinePageWebViewDidFailLoadWithError"

@interface CVDWebViewNotificationDelegate : NSObject <UIWebViewDelegate>
    @property (nonatomic,retain) id<UIWebViewDelegate> wrappedDelegate;
@end

@interface CDVOfflinePage : CDVPlugin
{
    CVDWebViewNotificationDelegate *notificationDelegate;
    NSDictionary *manifest;
}

-(void) enableOfflinePage:(CDVInvokedUrlCommand*)command;

-(void) disableOfflinePage:(CDVInvokedUrlCommand*)command;

@end
