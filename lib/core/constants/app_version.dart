class AppVersion {
  static const String version = '1.0.0';
  static const int buildNumber = 1;
  static const String full = '$version+$buildNumber';

  // Increment buildNumber by 1 for every AAB uploaded to Play Store.
  // Increment version for user-visible releases (patch.minor.major).
}
