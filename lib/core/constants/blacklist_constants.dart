/// Default selection for existing installations; runtime choices live in preferences.
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
