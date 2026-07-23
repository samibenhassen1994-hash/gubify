import 'package:flutter/services.dart';

class MonetaryAmountInputFormatter extends TextInputFormatter {
  const MonetaryAmountInputFormatter();

  static final RegExp _validAmount = RegExp(r'^\d*(?:[.,]\d{0,2})?$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return _validAmount.hasMatch(newValue.text) ? newValue : oldValue;
  }
}
