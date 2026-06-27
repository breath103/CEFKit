// Helper sub-process — does not link our ChromiumViewObjC layer. Pulling in the
// host's ObjC classes via -Wl,-ObjC drags in CEF cpptoc/ctocpp template
// instantiations that conflict with the framework's own and trip a Chromium
// CHECK inside cef_execute_process.

#include "include/cef_app.h"
#include "include/wrapper/cef_library_loader.h"

int main(int argc, char* argv[]) {
  CefScopedLibraryLoader loader;
  if (!loader.LoadInHelper()) return 1;
  CefMainArgs main_args(argc, argv);
  return CefExecuteProcess(main_args, nullptr, nullptr);
}
