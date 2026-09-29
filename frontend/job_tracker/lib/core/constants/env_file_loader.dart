// Reads the local, untracked `.env` from the filesystem.
//
// `.env` is deliberately **not** declared as a pubspec asset. It is
// gitignored, so it never exists on a fresh checkout (CI, a new clone) and a
// missing declared asset fails `flutter analyze`. Bundling it would also bake
// machine-local config into release binaries. `.env.example` stays the
// committed asset fallback, and `--dart-define` still outranks everything.
export 'env_file_loader_stub.dart'
    if (dart.library.io) 'env_file_loader_io.dart';
