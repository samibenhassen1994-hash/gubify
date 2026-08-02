class AppLimits {
  const AppLimits._();

  // Hub
  static const int freeMaxHubs = 3;
  static const int gubNameMinLength = 3;
  static const int gubNameMaxLength = 30;

  // Posts
  static const int postMaxLength = 1000;

  // Invite Code (canonical: K7M4P9Q2, visible: K7M4-P9Q2)
  static const int inviteCodeInputMaxLength = 24;

  // User
  static const int displayNameMaxLength = 25;
}
