class AppLimits {
  const AppLimits._();

  // Hub
  static const int freeMaxHubs = 3;
  static const int gubNameMinLength = 3;
  static const int gubNameMaxLength = 30;

  // Community
  static const int communityDescriptionMaxLength = 280;
  static const int communityMessageMaxLength = 2000;

  // Posts
  static const int postMaxLength = 1000;

  // User
  static const int displayNameMaxLength = 25;
}
