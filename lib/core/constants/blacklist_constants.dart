/// Predefined blacklisted entertainment & social media packages for screen-time telemetry
class BlacklistConstants {
  static const Map<String, String> appNames = {
    'com.facebook.katana': 'Facebook',
    'com.zhiliaoapp.musically': 'TikTok',
    'com.instagram.android': 'Instagram',
    'com.google.android.youtube': 'YouTube',
  };

  static const List<String> defaultBlacklist = [
    'com.facebook.katana',
    'com.zhiliaoapp.musically',
    'com.instagram.android',
    'com.google.android.youtube',
  ];
}
