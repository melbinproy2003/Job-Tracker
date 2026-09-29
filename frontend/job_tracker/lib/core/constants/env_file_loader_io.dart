import 'dart:io';

/// Reads [path] relative to the package root, or null when it is absent.
String? readLocalEnvFile(String path) {
  final file = File(path);
  if (!file.existsSync()) return null;
  return file.readAsStringSync();
}
