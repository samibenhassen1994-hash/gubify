class AppLimits {
  const AppLimits._();

  // Hub
  static const int freeMaxHubs = 3;
  static const int gubNameMinLength = 3;
  static const int gubNameMaxLength = 30;

  // Posts
  static const int postMaxLength = 1000;

  // Invite Code (es. HUB-1234)
  static const int inviteCodeLength = 8;

  // User
  static const int displayNameMaxLength = 25;
}
