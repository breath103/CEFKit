#import "CEFViewObjC.h"

@implementation CEFConfiguration

- (instancetype)init {
  if ((self = [super init])) {
    _sandboxDisabled = YES;
  }
  return self;
}

- (id)copyWithZone:(NSZone*)zone {
  CEFConfiguration* c = [[CEFConfiguration alloc] init];
  c.userAgent = self.userAgent;
  c.locale = self.locale;
  c.cachePath = self.cachePath;
  c.sandboxDisabled = self.sandboxDisabled;
  return c;
}

@end
