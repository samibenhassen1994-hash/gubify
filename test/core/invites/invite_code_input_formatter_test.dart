import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/core/invites/invite_code.dart';
import 'package:gubify/core/invites/invite_code_input_formatter.dart';

void main() {
  const formatter = InviteCodeInputFormatter();

  TextEditingValue apply(
    TextEditingValue oldValue,
    String text, {
    int? cursor,
  }) {
    return formatter.formatEditUpdate(
      oldValue,
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: cursor ?? text.length),
      ),
    );
  }

  test('progressive lowercase typing uppercases and inserts one separator', () {
    var value = TextEditingValue.empty;
    final expected = [
      'K',
      'K7',
      'K7M',
      'K7M4',
      'K7M4-P',
      'K7M4-P9',
      'K7M4-P9Q',
      'K7M4-P9Q2',
    ];
    for (final character in 'k7m4p9q2'.split('')) {
      value = apply(value, '${value.text}$character');
      expect(value.text, expected.removeAt(0));
      expect(value.selection.extentOffset, value.text.length);
    }
  });

  test('limits input to eight canonical and nine visible characters', () {
    final value = apply(TextEditingValue.empty, 'K7M4P9Q2ABCDEFG');
    expect(value.text, 'K7M4-P9Q2');
    expect(InviteCode.filterSupportedInput(value.text), hasLength(8));
    expect(value.text, hasLength(9));
  });

  test('ignores spaces, separators, special and ambiguous characters', () {
    final value = apply(TextEditingValue.empty, ' k-7_m.4/p 9q2 01io!@#');
    expect(value.text, 'K7M4-P9Q2');
  });

  test('paste with or without separator produces the same display', () {
    final canonical = apply(TextEditingValue.empty, 'K7M4P9Q2');
    final formatted = apply(TextEditingValue.empty, 'K7M4-P9Q2');
    expect(canonical.text, 'K7M4-P9Q2');
    expect(formatted.text, 'K7M4-P9Q2');
    expect(formatted.text, isNot(contains('--')));
  });

  test('backspace immediately after the separator deletes naturally', () {
    const oldValue = TextEditingValue(
      text: 'K7M4-P9Q2',
      selection: TextSelection.collapsed(offset: 5),
    );
    final value = apply(oldValue, 'K7M4P9Q2', cursor: 4);
    expect(value.text, 'K7MP-9Q2');
    expect(value.selection, const TextSelection.collapsed(offset: 3));
  });

  test(
    'delete immediately before the separator removes the next character',
    () {
      const oldValue = TextEditingValue(
        text: 'K7M4-P9Q2',
        selection: TextSelection.collapsed(offset: 4),
      );
      final value = apply(oldValue, 'K7M4P9Q2', cursor: 4);
      expect(value.text, 'K7M4-9Q2');
      expect(value.selection, const TextSelection.collapsed(offset: 4));
    },
  );
}
