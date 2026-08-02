import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/core/invites/invite_code.dart';

void main() {
  group('InviteCode', () {
    test('uses the exact 32-character alphabet and eight-character code', () {
      expect(InviteCode.alphabet, '23456789ABCDEFGHJKLMNPQRSTUVWXYZ');
      expect(InviteCode.alphabet.length, 32);
      expect(InviteCode.canonicalLength, 8);
    });

    test('normalizes formatted, unformatted, lowercase, and spaced input', () {
      expect(InviteCode.normalize('K7M4-P9Q2'), 'K7M4P9Q2');
      expect(InviteCode.normalize('K7M4P9Q2'), 'K7M4P9Q2');
      expect(InviteCode.normalize('k7m4-p9q2'), 'K7M4P9Q2');
      expect(InviteCode.normalize(' k7 m4 - p9 q2 '), 'K7M4P9Q2');
    });

    test('formats canonical values as XXXX-XXXX', () {
      expect(InviteCode.format('K7M4P9Q2'), 'K7M4-P9Q2');
    });

    test('rejects ambiguous, invalid, short, and long values', () {
      for (final value in [
        'K7M4P9Q',
        'K7M4P9Q22',
        'K7M4P9O2',
        'K7M4P1Q2',
        'K7M4/PQ2',
      ]) {
        expect(
          () => InviteCode.normalize(value),
          throwsA(isA<InvalidInviteCodeException>()),
        );
      }
    });

    test('secure constructor declares and produces secure-format output', () {
      final generator = InviteCodeGenerator.secure();
      final generated = generator.generate();
      expect(generator.usesSecureRandom, isTrue);
      expect(InviteCode.isCanonical(generated), isTrue);
      expect(generated, isNot(contains('/')));
    });

    test('repeated deterministic generations can produce different tokens', () {
      final generator = InviteCodeGenerator.forTesting(
        _SequenceRandom([...List.filled(8, 0), ...List.filled(8, 1)]),
      );
      expect(generator.generate(), '22222222');
      expect(generator.generate(), '33333333');
    });
  });

  group('reserveUniqueInviteCode', () {
    test('retries a collision and returns the next reserved code', () async {
      final attempted = <String>[];
      final result = await reserveUniqueInviteCode<String>(
        generator: InviteCodeGenerator.forTesting(
          _SequenceRandom([...List.filled(8, 0), ...List.filled(8, 1)]),
        ),
        maxAttempts: 2,
        tryReserve: (candidate) async {
          attempted.add(candidate);
          return attempted.length == 1 ? null : candidate;
        },
      );
      expect(attempted, ['22222222', '33333333']);
      expect(result, '33333333');
    });

    test('stops exactly at the configured retry limit', () async {
      var attempts = 0;
      await expectLater(
        reserveUniqueInviteCode<String>(
          generator: InviteCodeGenerator.forTesting(
            _SequenceRandom(List.filled(24, 0)),
          ),
          maxAttempts: 3,
          tryReserve: (_) async {
            attempts++;
            return null;
          },
        ),
        throwsA(isA<InviteCodeReservationException>()),
      );
      expect(attempts, 3);
    });
  });
}

class _SequenceRandom implements Random {
  final List<int> _values;
  var _index = 0;

  _SequenceRandom(this._values);

  @override
  int nextInt(int max) => _values[_index++] % max;

  @override
  bool nextBool() => nextInt(2) == 0;

  @override
  double nextDouble() => nextInt(1 << 20) / (1 << 20);
}
