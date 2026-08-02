import 'package:flutter/services.dart';

import 'invite_code.dart';

class InviteCodeInputFormatter extends TextInputFormatter {
  const InviteCodeInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var canonical = InviteCode.filterSupportedInput(newValue.text);
    var baseCanonicalOffset = _canonicalOffset(
      newValue.text,
      newValue.selection.baseOffset,
    );
    var extentCanonicalOffset = _canonicalOffset(
      newValue.text,
      newValue.selection.extentOffset,
    );

    final oldCanonical = InviteCode.filterSupportedInput(oldValue.text);
    final deletedOnlySeparator =
        oldValue.selection.isCollapsed &&
        newValue.selection.isCollapsed &&
        newValue.text.length == oldValue.text.length - 1 &&
        canonical == oldCanonical;
    if (deletedOnlySeparator) {
      final cursor = oldValue.selection.extentOffset;
      final deletionIndex = cursor > 4 ? 3 : 4;
      if (deletionIndex < canonical.length) {
        canonical = canonical.replaceRange(
          deletionIndex,
          deletionIndex + 1,
          '',
        );
        baseCanonicalOffset = deletionIndex;
        extentCanonicalOffset = deletionIndex;
      }
    }

    final formatted = InviteCode.formatPartial(canonical);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection(
        baseOffset: _visibleOffset(baseCanonicalOffset, formatted.length),
        extentOffset: _visibleOffset(extentCanonicalOffset, formatted.length),
      ),
    );
  }

  int _canonicalOffset(String text, int visibleOffset) {
    if (visibleOffset <= 0) return 0;
    final safeOffset = visibleOffset.clamp(0, text.length);
    return InviteCode.filterSupportedInput(
      text.substring(0, safeOffset),
    ).length;
  }

  int _visibleOffset(int canonicalOffset, int formattedLength) {
    final offset = canonicalOffset + (canonicalOffset > 4 ? 1 : 0);
    return offset.clamp(0, formattedLength);
  }
}
