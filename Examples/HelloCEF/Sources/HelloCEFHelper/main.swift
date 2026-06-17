// CEFKitHelper is the helper-only facade: it re-exports CEFApplication but
// does NOT pull in the Chromium Embedded Framework binary target. The helper
// dlopens the framework at runtime via CefScopedLibraryLoader::LoadInHelper(),
// which finds it relative to the host bundle, not the helper bundle.
import CEFKitHelper
exit(Int32(CEFApplication.runHelper()))
