// Obj-C surface. The Swift names (via NS_SWIFT_NAME) are what consumers see.

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class CEFView;
@class CEFConfiguration;
@protocol CEFNavigationDelegate;

/// Backing object for a single favicon download. Identity = URL: when the
/// page swaps to a new favicon URL, `CEFView.favicon` is replaced with a
/// fresh instance, so stale download callbacks land on the old (now
/// unreferenced) one rather than overwriting current state.
/// The Swift `Favicon` wrapper in CEFKit exposes this with @Observable.
NS_SWIFT_NAME(CEFFaviconRef)
@interface CEFFaviconRef : NSObject
@property (nonatomic, readonly) NSURL* url;
@property (nonatomic, readonly, nullable) NSImage* image;
- (instancetype)initWithURL:(NSURL*)url NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

typedef void (^CEFSetupBlock)(void);

NS_SWIFT_NAME(CEFConfiguration)
@interface CEFConfiguration : NSObject <NSCopying>
/// Overrides the User-Agent string sent on every request.
@property (nonatomic, copy, nullable) NSString* userAgent;
/// Locale to advertise (defaults to system).
@property (nonatomic, copy, nullable) NSString* locale;
/// Cache directory. Defaults to `~/Library/Caches/<bundle-id>`.
@property (nonatomic, copy, nullable) NSURL* cachePath;
/// Disable the Chromium sandbox (default YES — standard CEF distribution
/// doesn't ship `cef_sandbox.a`). Flip off only if linking the Sandbox
/// Distribution.
@property (nonatomic, assign) BOOL sandboxDisabled;
@end

NS_SWIFT_NAME(CEFApplication)
@interface CEFApplication : NSObject
+ (int)runWithSetup:(CEFSetupBlock)setup NS_SWIFT_NAME(run(setup:));
+ (int)runWithConfiguration:(nullable CEFConfiguration*)config
                      setup:(CEFSetupBlock)setup
    NS_SWIFT_NAME(run(configuration:setup:));
+ (int)runHelper NS_SWIFT_NAME(runHelper());

+ (int)runWithSetup:(CEFSetupBlock)setup argc:(int)argc argv:(char* _Nonnull[_Nonnull])argv
    NS_SWIFT_UNAVAILABLE("use run(setup:)");
+ (int)runHelperWithArgc:(int)argc argv:(char* _Nonnull[_Nonnull])argv
    NS_SWIFT_UNAVAILABLE("use runHelper()");
@end

NS_SWIFT_NAME(CEFNavigationDelegate)
@protocol CEFNavigationDelegate <NSObject>
@optional
// Navigation EVENTS. State mirrors (title / isLoading / canGoBack /
// canGoForward / URL) are KVO-observable on CEFView directly — observe
// those rather than listening here.
- (void)webView:(CEFView*)webView didStartProvisionalNavigation:(nullable NSURL*)url
    NS_SWIFT_NAME(webView(_:didStartProvisionalNavigationTo:));
- (void)webView:(CEFView*)webView didFinishNavigationTo:(nullable NSURL*)url statusCode:(int)code
    NS_SWIFT_NAME(webView(_:didFinishNavigationTo:statusCode:));
- (void)webView:(CEFView*)webView didFailNavigationWithError:(NSError*)error
    NS_SWIFT_NAME(webView(_:didFailNavigationWith:));
@end

NS_SWIFT_NAME(CEFWebView)
@interface CEFView : NSView

@property (nonatomic, copy, nullable) NSURL* URL;
@property (nonatomic, readonly) BOOL canGoBack;
@property (nonatomic, readonly) BOOL canGoForward;
@property (nonatomic, readonly) BOOL isLoading;
@property (nonatomic, readonly, nullable) NSString* title;
/// Current page favicon. A new instance is created every time the page's
/// favicon URL changes — `url` is fixed at construction, `image` lands
/// asynchronously when CEF's image loader finishes the download. Old
/// instances orphan naturally when the URL changes again, so a late
/// callback writing to one is harmless. KVO-observable.
@property (nonatomic, readonly, nullable) CEFFaviconRef* favicon;
@property (nonatomic, weak, nullable) id<CEFNavigationDelegate> navigationDelegate;

- (instancetype)initWithFrame:(NSRect)frame URL:(nullable NSURL*)url NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(NSRect)frame NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder*)c NS_UNAVAILABLE;

- (void)load:(NSURL*)url NS_SWIFT_NAME(load(_:));
- (void)loadHTMLString:(NSString*)html baseURL:(nullable NSURL*)baseURL
    NS_SWIFT_NAME(loadHTMLString(_:baseURL:));

- (void)reload;
- (void)reloadFromOrigin;
- (void)stopLoading;
- (void)goBack;
- (void)goForward;

/// JS eval. `completion` is called on the main thread. `result` is a Foundation
/// JSON value (NSString / NSNumber / NSDictionary / NSArray / NSNull) unwrapped
/// from the DevTools Protocol's `RemoteObject`.
- (void)evaluateJavaScript:(NSString*)script
                completion:(void (^_Nullable)(id _Nullable result, NSError* _Nullable error))completion
    NS_SWIFT_NAME(evaluateJavaScript(_:completion:));

#pragma mark - DevTools

/// Open / close Chromium DevTools for this browser.
/// Setting `YES` while already open is a no-op focus; setting `NO` while
/// closed is a no-op. DevTools open in a new floating native window.
@property (nonatomic, assign) BOOL isDevToolsOpen;

@end

NS_ASSUME_NONNULL_END
