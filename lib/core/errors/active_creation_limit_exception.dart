class ActiveCreationLimitException implements Exception {
  final String message;

  const ActiveCreationLimitException(this.message);

  @override
  String toString() => message;
}

class CreationCooldownException implements Exception {
  final String message;

  const CreationCooldownException(this.message);

  @override
  String toString() => message;
}
