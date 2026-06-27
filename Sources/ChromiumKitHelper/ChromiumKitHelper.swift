// Re-exports the bare minimum needed by helper sub-process executables.
// Crucially does NOT depend on the CCEF binary target, so SPM does not
// embed Chromium Embedded Framework.framework as a load command — the
// helper dlopens it at runtime via CefScopedLibraryLoader::LoadInHelper().
@_exported import ChromiumViewObjC
