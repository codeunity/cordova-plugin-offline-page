#import "CDVOfflinePage.h"
#import <Cordova/CDV.h>
#import "CDVConnection.h"

@interface CDVOfflinePage ()

@property UIWebView *offlineView;
@property NSString *offlinePage;
@property BOOL enableOfflineSupport;
@property NSURL *failedURL;

@end

@implementation CVDWebViewNotificationDelegate

- (void)webViewDidStartLoad:(UIWebView*)theWebView {
    [self.wrappedDelegate webViewDidStartLoad: theWebView];

    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kCDVOfflinePageWebViewDidStartLoad object:theWebView]];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kCDVOfflinePageWebViewShouldStartLoadWithRequest object:request]];

    return [self.wrappedDelegate webView:webView shouldStartLoadWithRequest:request navigationType:navigationType];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    [self.wrappedDelegate webViewDidFinishLoad:webView];

    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kCDVOfflinePageWebViewDidFinishLoad object:webView]];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    [self.wrappedDelegate webView:webView didFailLoadWithError:error];

    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kCDVOfflinePageWebViewDidFailLoadWithError object:error]];
}

@end

@implementation CDVOfflinePage

- (void)pluginInitialize
{
    [super pluginInitialize];

    // creates the UI to show offline mode
    [self createOfflineView];

    // observe notifications from network-information plugin to detect when device is offline
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateConnectivityStatus:)
                                                 name:kReachabilityChangedNotification
                                               object:nil];

    // observe notifications from webview when page starts loading
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(webViewDidStartLoad:)
                                                 name:kCDVOfflinePageWebViewDidStartLoad
                                               object:nil];

    // observe notifications from webview when page starts loading
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(webViewDidFinishLoad:)
                                                 name:kCDVOfflinePageWebViewDidFinishLoad
                                               object:nil];

    // observe notifications from webview when page fails loading
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didWebViewFailLoadWithError:)
                                                 name:kCDVOfflinePageWebViewDidFailLoadWithError
                                               object:nil];

    // enable offline support by default
    self.enableOfflineSupport = YES;

    // no connection errors on startup
    self.failedURL = nil;

    // set the webview delegate to notify navigation events
    notificationDelegate = [[CVDWebViewNotificationDelegate alloc] init];
    notificationDelegate.wrappedDelegate = self.webView.delegate;
    [self.webView setDelegate:notificationDelegate];
}

// enables offline page support
-(void) enableOfflinePage:(CDVInvokedUrlCommand *)command {

    self.enableOfflineSupport = YES;
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:true];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

// disables offline page support
-(void) disableOfflinePage:(CDVInvokedUrlCommand *)command {

    self.enableOfflineSupport = NO;
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:true];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

// Creates an additional webview to load the offline page, places it above the content webview, and hides it. It will
// be made visible whenever network connectivity is lost.
- (void)createOfflineView
{
    CGRect webViewBounds = self.webView.bounds;

    webViewBounds.origin = self.webView.bounds.origin;

    self.offlineView = [[UIWebView alloc] initWithFrame:webViewBounds];
    self.offlineView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
    [self.offlineView setHidden:YES];

    [self.viewController.view addSubview:self.offlineView];

    NSURL* offlinePageURL = [NSURL URLWithString:self.offlinePage];
    if (offlinePageURL == nil) {
        offlinePageURL = [NSURL URLWithString:@"offline.html"];
    }

    NSString* offlineFilePath = [self.commandDelegate pathForResource:[offlinePageURL path]];
    if (offlineFilePath != nil) {
        offlinePageURL = [NSURL fileURLWithPath:offlineFilePath];
        [self.offlineView loadRequest:[NSURLRequest requestWithURL:offlinePageURL]];
    }
    else {
        NSString *offlinePageTemplate = @"<html><body><div style=\"height:100%;position:absolute;top:0;bottom:0;left:0;right:0;margin:auto 20;font-size:x-large;text-align:center;\">%@</div></body></html>";
        [self.offlineView
            loadHTMLString:[NSString stringWithFormat:offlinePageTemplate, @"It looks like you are offline. Please reconnect to use this application."]
            baseURL:nil];
    }

    [self.viewController.view sendSubviewToBack:self.webView];
}

// Handles notifications from the network-information plugin and shows the offline page whenever
// network connectivity is lost. It restores the original view once the network is up again.
- (void)updateConnectivityStatus:(NSNotification*)notification
{
    if ([[notification name] isEqualToString:kReachabilityChangedNotification]) {
        CDVReachability* reachability = [notification object];
        if ((reachability != nil) && [reachability isKindOfClass:[CDVReachability class]]) {
            BOOL isOffline = (reachability.currentReachabilityStatus == NotReachable);
            NSLog (@"Received a network connectivity change notification. The device is currently %@.", isOffline ? @"offLine" : @"online");
            if (self.enableOfflineSupport) {
                if (isOffline) {
                    [self.offlineView setHidden:NO];
                }
                else {
                    if (self.failedURL) {
                        [self.webView loadRequest: [NSURLRequest requestWithURL: self.failedURL]];
                    }
                    else {
                        [self.offlineView setHidden:YES];
                    }
                }
            }
        }
    }
}

// Handles notifications from the webview delegate whenever a page starts loading.
- (void)webViewDidStartLoad:(NSNotification*)notification
{
    if ([[notification name] isEqualToString:kCDVOfflinePageWebViewDidStartLoad]) {
        NSLog (@"Received a navigation start notification.");
        self.failedURL = nil;
    }
}

// Handles notifications from the webview delegate whenever a page finishes loading.
- (void)webViewDidFinishLoad:(NSNotification*)notification
{
    if ([[notification name] isEqualToString:kCDVOfflinePageWebViewDidFinishLoad]) {
        NSLog (@"Received a navigation completed notification.");
        if (!self.failedURL) {
            [self.offlineView setHidden:YES];
        }
    }
}

// Handles notifications from the webview delegate whenever a page load fails.
- (void)didWebViewFailLoadWithError:(NSNotification*)notification
{
    NSError* error = [notification object];

    if ([[notification name] isEqualToString:kCDVOfflinePageWebViewDidFailLoadWithError]) {
        NSLog (@"Received a navigation failure notification. error: %@", [error description]);
        if ([error code] == NSURLErrorTimedOut ||
            [error code] == NSURLErrorUnsupportedURL ||
            [error code] == NSURLErrorCannotFindHost ||
            [error code] == NSURLErrorCannotConnectToHost ||
            [error code] == NSURLErrorDNSLookupFailed ||
            [error code] == NSURLErrorNotConnectedToInternet ||
            [error code] == NSURLErrorNetworkConnectionLost) {

            self.failedURL = [NSURL URLWithString:[error.userInfo objectForKey:@"NSErrorFailingURLStringKey"]];

            if (self.enableOfflineSupport) {
                [self.offlineView setHidden:NO];
            }
        }
    }
}

@end
