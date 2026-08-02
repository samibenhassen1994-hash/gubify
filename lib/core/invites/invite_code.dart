import 'dart:math';

import 'package:flutter/foundation.dart';

class InviteCode {
  const InviteCode._();

  static const alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  static const canonicalLength = 8;
  static const formattedLength = 9;

  static final RegExp _canonicalPattern = RegExp(
    r'^[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{8}$',
  );

  static String normalize(String input) {
    final canonical = input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    if (!_canonicalPattern.hasMatch(canonical)) {
      throw const InvalidInviteCodeException();
    }
    return canonical;
  }

  static bool isCanonical(String value) =>
      value.length == canonicalLength && _canonicalPattern.hasMatch(value);

  static String filterSupportedInput(String input) {
    final upper = input.toUpperCase();
    final buffer = StringBuffer();
    for (final character in upper.split('')) {
      if (alphabet.contains(character)) buffer.write(character);
      if (buffer.length == canonicalLength) break;
    }
    return buffer.toString();
  }

  static String formatPartial(String canonical) {
    if (canonical.isEmpty) return '';
    if (canonical.length > canonicalLength ||
        canonical.split('').any((character) => !alphabet.contains(character))) {
      throw const InvalidInviteCodeException();
    }
    if (canonical.length <= 4) return canonical;
    return '${canonical.substring(0, 4)}-${canonical.substring(4)}';
  }

  static String format(String canonical) {
    if (!isCanonical(canonical)) {
      throw const InvalidInviteCodeException();
    }
    return formatPartial(canonical);
  }

  static String? tryFormat(String canonical) =>
      isCanonical(canonical) ? format(canonical) : null;
}

class InvalidInviteCodeException implements Exception {
  const InvalidInviteCodeException();

  @override
  String toString() => 'Invalid or expired invite code.';
}

class InviteCodeReservationException implements Exception {
  const InviteCodeReservationException();

  @override
  String toString() => 'Unable to create an invite code. Please try again.';
}

class InviteCodeGenerator {
  final Random _random;
  final bool usesSecureRandom;

  InviteCodeGenerator.secure()
    : _random = Random.secure(),
      usesSecureRandom = true;

  @visibleForTesting
  InviteCodeGenerator.forTesting(this._random) : usesSecureRandom = false;

  String generate() {
    final buffer = StringBuffer();
    for (var index = 0; index < InviteCode.canonicalLength; index++) {
      buffer.write(
        InviteCode.alphabet[_random.nextInt(InviteCode.alphabet.length)],
      );
    }
    return buffer.toString();
  }
}

Future<T> reserveUniqueInviteCode<T>({
  required Future<T?> Function(String candidate) tryReserve,
  InviteCodeGenerator? generator,
  int maxAttempts = 10,
}) async {
  if (maxAttempts <= 0) throw const InviteCodeReservationException();

  final codeGenerator = generator ?? InviteCodeGenerator.secure();
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    final candidate = codeGenerator.generate();
    final result = await tryReserve(candidate);
    if (result != null) return result;
  }
  throw const InviteCodeReservationException();
}
