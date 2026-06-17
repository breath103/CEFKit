#import "CEFViewObjC.h"
#include "include/cef_app.h"
#include "include/cef_browser.h"
#include "include/cef_client.h"
#include "include/cef_devtools_message_observer.h"
#include "include/cef_parser.h"
#include "include/wrapper/cef_helpers.h"

@interface CEFView ()
- (void)_onTitleChange:(nullable NSString*)title;
- (void)_onLoadingStateChange:(BOOL)isLoading
                    canGoBack:(BOOL)canGoBack
                 canGoForward:(BOOL)canGoForward;
- (void)_onLoadStartURL:(nullable NSURL*)url;
- (void)_onLoadEndURL:(nullable NSURL*)url statusCode:(int)code;
- (void)_onLoadErrorURL:(nullable NSURL*)url
                  error:(NSError*)error;
- (void)_onDevToolsResult:(int)messageId
                  success:(BOOL)success
                   result:(NSData*)data;
@end

namespace {

class _CEFClient;

class _CEFDevToolsObserver : public CefDevToolsMessageObserver {
 public:
  _CEFDevToolsObserver() = default;
  void SetOwner(__weak CEFView* o) { owner_ = o; }
  void OnDevToolsMethodResult(CefRefPtr<CefBrowser> browser, int message_id,
                              bool success, const void* result,
                              size_t result_size) override {
    NSData* data = [NSData dataWithBytes:result length:result_size];
    __weak CEFView* owner = owner_;
    dispatch_async(dispatch_get_main_queue(), ^{
      [owner _onDevToolsResult:message_id success:success result:data];
    });
  }
 private:
  __weak CEFView* owner_;
  IMPLEMENT_REFCOUNTING(_CEFDevToolsObserver);
};

class _CEFClient : public CefClient,
                   public CefLifeSpanHandler,
                   public CefLoadHandler,
                   public CefDisplayHandler {
 public:
  _CEFClient() = default;
  explicit _CEFClient(CEFView* owner) : owner_(owner) {}
  CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() override { return this; }
  CefRefPtr<CefLoadHandler> GetLoadHandler() override { return this; }
  CefRefPtr<CefDisplayHandler> GetDisplayHandler() override { return this; }

  void OnAfterCreated(CefRefPtr<CefBrowser> b) override {
    CEF_REQUIRE_UI_THREAD();
    browser_ = b;
    devtools_ = new _CEFDevToolsObserver();
    devtools_->SetOwner(owner_);
    devtools_registration_ = b->GetHost()->AddDevToolsMessageObserver(devtools_.get());
  }
  void OnBeforeClose(CefRefPtr<CefBrowser>) override {
    CEF_REQUIRE_UI_THREAD();
    browser_ = nullptr;
    devtools_registration_ = nullptr;
    owner_ = nil;
    CefQuitMessageLoop();
  }

  void OnLoadingStateChange(CefRefPtr<CefBrowser>, bool isLoading,
                            bool canGoBack, bool canGoForward) override {
    is_loading_ = isLoading;
    can_back_ = canGoBack;
    can_forward_ = canGoForward;
    __weak CEFView* o = owner_;
    BOOL il = isLoading, cb = canGoBack, cf = canGoForward;
    dispatch_async(dispatch_get_main_queue(), ^{
      [o _onLoadingStateChange:il canGoBack:cb canGoForward:cf];
    });
  }

  void OnLoadStart(CefRefPtr<CefBrowser>, CefRefPtr<CefFrame> frame,
                   TransitionType) override {
    if (!frame || !frame->IsMain()) return;
    NSURL* url = [NSURL URLWithString:
        [NSString stringWithUTF8String:frame->GetURL().ToString().c_str()]];
    __weak CEFView* o = owner_;
    dispatch_async(dispatch_get_main_queue(), ^{ [o _onLoadStartURL:url]; });
  }

  void OnLoadEnd(CefRefPtr<CefBrowser>, CefRefPtr<CefFrame> frame,
                 int httpStatusCode) override {
    if (!frame || !frame->IsMain()) return;
    NSURL* url = [NSURL URLWithString:
        [NSString stringWithUTF8String:frame->GetURL().ToString().c_str()]];
    int code = httpStatusCode;
    __weak CEFView* o = owner_;
    dispatch_async(dispatch_get_main_queue(), ^{
      [o _onLoadEndURL:url statusCode:code];
    });
  }

  void OnLoadError(CefRefPtr<CefBrowser>, CefRefPtr<CefFrame> frame,
                   ErrorCode errorCode, const CefString& errorText,
                   const CefString& failedUrl) override {
    if (!frame || !frame->IsMain()) return;
    NSURL* url = [NSURL URLWithString:
        [NSString stringWithUTF8String:failedUrl.ToString().c_str()]];
    NSString* msg = [NSString stringWithUTF8String:errorText.ToString().c_str()];
    NSError* err = [NSError errorWithDomain:@"CEFView"
                                       code:(NSInteger)errorCode
                                   userInfo:@{NSLocalizedDescriptionKey: msg ?: @""}];
    __weak CEFView* o = owner_;
    dispatch_async(dispatch_get_main_queue(), ^{
      [o _onLoadErrorURL:url error:err];
    });
  }

  void OnTitleChange(CefRefPtr<CefBrowser>, const CefString& title) override {
    NSString* t = [NSString stringWithUTF8String:title.ToString().c_str()];
    title_ = t;
    __weak CEFView* o = owner_;
    dispatch_async(dispatch_get_main_queue(), ^{ [o _onTitleChange:t]; });
  }

  CefRefPtr<CefBrowser> browser() const { return browser_; }
  bool isLoading() const { return is_loading_; }
  bool canGoBack() const { return can_back_; }
  bool canGoForward() const { return can_forward_; }
  NSString* title() const { return title_; }

 private:
  __weak CEFView* owner_;
  CefRefPtr<CefBrowser> browser_;
  CefRefPtr<_CEFDevToolsObserver> devtools_;
  CefRefPtr<CefRegistration> devtools_registration_;
  bool is_loading_ = false;
  bool can_back_ = false;
  bool can_forward_ = false;
  NSString* title_ = nil;
  IMPLEMENT_REFCOUNTING(_CEFClient);
  DISALLOW_COPY_AND_ASSIGN(_CEFClient);
};

}  // namespace

@implementation CEFView {
  CefRefPtr<_CEFClient> _client;
  BOOL _browserCreated;
  int _nextEvalId;
  NSMutableDictionary<NSNumber*, void(^)(id _Nullable, NSError* _Nullable)>* _evalCallbacks;
}

@synthesize URL = _URL;
@synthesize navigationDelegate = _navigationDelegate;

- (instancetype)initWithFrame:(NSRect)frame URL:(NSURL*)url {
  if ((self = [super initWithFrame:frame])) {
    _URL = [url copy];
    _nextEvalId = 1;
    _evalCallbacks = [NSMutableDictionary new];
    self.wantsLayer = YES;
  }
  return self;
}

- (void)viewDidMoveToWindow {
  [super viewDidMoveToWindow];
  if (self.window && !_browserCreated) {
    _browserCreated = YES;
    _client = new _CEFClient(self);
    NSRect b = self.bounds;
    CefWindowInfo wi;
    wi.SetAsChild((__bridge void*)self,
                  CefRect(0, 0, (int)b.size.width, (int)b.size.height));
    CefBrowserSettings bs;
    NSString* urlString = _URL.absoluteString ?: @"about:blank";
    CefBrowserHost::CreateBrowser(wi, _client.get(),
                                  [urlString UTF8String], bs, nullptr, nullptr);
  }
}

#pragma mark - State

- (BOOL)canGoBack    { return _client ? _client->canGoBack()    : NO; }
- (BOOL)canGoForward { return _client ? _client->canGoForward() : NO; }
- (BOOL)isLoading    { return _client ? _client->isLoading()    : NO; }
- (NSString*)title   { return _client ? _client->title()        : nil; }

#pragma mark - Navigation

- (CefRefPtr<CefBrowser>)_browser { return _client ? _client->browser() : nullptr; }

- (void)load:(NSURL*)url {
  _URL = [url copy];
  if (auto b = [self _browser]) {
    b->GetMainFrame()->LoadURL([url.absoluteString UTF8String]);
  }
}

- (void)loadHTMLString:(NSString*)html baseURL:(NSURL*)baseURL {
  if (auto b = [self _browser]) {
    std::string s([html UTF8String]);
    CefString encoded = CefBase64Encode(s.data(), s.size());
    std::string dataUrl = std::string("data:text/html;base64,") + encoded.ToString();
    b->GetMainFrame()->LoadURL(dataUrl);
  }
}

- (void)reload            { if (auto b = [self _browser]) b->Reload(); }
- (void)reloadFromOrigin  { if (auto b = [self _browser]) b->ReloadIgnoreCache(); }
- (void)stopLoading       { if (auto b = [self _browser]) b->StopLoad(); }
- (void)goBack            { if (auto b = [self _browser]) b->GoBack(); }
- (void)goForward         { if (auto b = [self _browser]) b->GoForward(); }

#pragma mark - JS eval (DevTools Runtime.evaluate)

- (void)evaluateJavaScript:(NSString*)script
                completion:(void (^)(id, NSError*))completion {
  auto b = [self _browser];
  if (!b) {
    if (completion) {
      completion(nil, [NSError errorWithDomain:@"CEFView" code:2
                                      userInfo:@{NSLocalizedDescriptionKey:
                                                  @"browser not yet created"}]);
    }
    return;
  }
  int msgId = ++_nextEvalId;
  if (completion) {
    _evalCallbacks[@(msgId)] = [completion copy];
  }
  NSDictionary* req = @{
    @"id": @(msgId),
    @"method": @"Runtime.evaluate",
    @"params": @{
      @"expression": script,
      @"returnByValue": @YES,
      @"awaitPromise": @YES,
    },
  };
  NSData* json = [NSJSONSerialization dataWithJSONObject:req options:0 error:nil];
  b->GetHost()->SendDevToolsMessage(json.bytes, json.length);
}

- (void)_onDevToolsResult:(int)messageId success:(BOOL)success result:(NSData*)data {
  void (^cb)(id, NSError*) = _evalCallbacks[@(messageId)];
  if (!cb) return;
  [_evalCallbacks removeObjectForKey:@(messageId)];

  NSError* jsonErr = nil;
  id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
  if (!success || ![obj isKindOfClass:[NSDictionary class]]) {
    cb(nil, [NSError errorWithDomain:@"CEFView" code:3
                            userInfo:@{NSLocalizedDescriptionKey:
                                        jsonErr.localizedDescription ?: @"eval failed"}]);
    return;
  }
  // DevTools shape: { "result": { "type": "string"|..., "value": ..., "description": "..." },
  //                   "exceptionDetails": { "text": ... } }
  NSDictionary* d = obj;
  NSDictionary* ex = d[@"exceptionDetails"];
  if ([ex isKindOfClass:[NSDictionary class]]) {
    NSString* text = ex[@"text"] ?: @"JS exception";
    cb(nil, [NSError errorWithDomain:@"CEFView" code:4
                            userInfo:@{NSLocalizedDescriptionKey: text}]);
    return;
  }
  NSDictionary* r = d[@"result"];
  if (![r isKindOfClass:[NSDictionary class]]) { cb(nil, nil); return; }
  id value = r[@"value"];
  if (value == nil || value == NSNull.null) {
    // `undefined` shows up as no `value` key, type=undefined
    NSString* type = r[@"type"];
    if ([type isEqual:@"undefined"]) { cb(nil, nil); return; }
    cb(NSNull.null, nil);
    return;
  }
  cb(value, nil);
}

#pragma mark - Delegate forwarding

- (void)_onTitleChange:(NSString*)title {
  id<CEFNavigationDelegate> d = self.navigationDelegate;
  if ([d respondsToSelector:@selector(webView:didChangeTitle:)]) {
    [d webView:self didChangeTitle:title];
  }
}
- (void)_onLoadingStateChange:(BOOL)isLoading canGoBack:(BOOL)b canGoForward:(BOOL)f {
  id<CEFNavigationDelegate> d = self.navigationDelegate;
  if ([d respondsToSelector:@selector(webView:didChangeLoadingState:)]) {
    [d webView:self didChangeLoadingState:isLoading];
  }
}
- (void)_onLoadStartURL:(NSURL*)url {
  id<CEFNavigationDelegate> d = self.navigationDelegate;
  if ([d respondsToSelector:@selector(webView:didStartProvisionalNavigationTo:)]) {
    [d webView:self didStartProvisionalNavigation:url];
  }
}
- (void)_onLoadEndURL:(NSURL*)url statusCode:(int)code {
  id<CEFNavigationDelegate> d = self.navigationDelegate;
  if ([d respondsToSelector:@selector(webView:didFinishNavigationTo:statusCode:)]) {
    [d webView:self didFinishNavigationTo:url statusCode:code];
  }
}
- (void)_onLoadErrorURL:(NSURL*)url error:(NSError*)error {
  id<CEFNavigationDelegate> d = self.navigationDelegate;
  if ([d respondsToSelector:@selector(webView:didFailNavigationWith:)]) {
    [d webView:self didFailNavigationWithError:error];
  }
}

@end
