/// Server and database are baked into the APK at build time so staff only
/// type email + password. Set via --dart-define (see build-apk.yml).
class AppConfig {
  static const serverUrl = String.fromEnvironment('SERVER_URL');
  static const dbName = String.fromEnvironment('DB_NAME');
  static bool get isLocked => serverUrl.isNotEmpty;
}
