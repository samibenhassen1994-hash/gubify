import 'dart:math' as math;

import 'package:flutter/material.dart';

Future<String?> showCommunitySearchPicker({
  required BuildContext context,
  required String title,
  required List<String> options,
  required String selectedValue,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _CommunitySearchPicker(
      title: title,
      options: options,
      selectedValue: selectedValue,
    ),
  );
}

class CommunityPickerField extends StatelessWidget {
  final String label;
  final String value;
  final bool enabled;
  final VoidCallback onTap;

  const CommunityPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: '$label, $value',
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: enabled ? onTap : null,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            enabled: enabled,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
          child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

class _CommunitySearchPicker extends StatefulWidget {
  final String title;
  final List<String> options;
  final String selectedValue;

  const _CommunitySearchPicker({
    required this.title,
    required this.options,
    required this.selectedValue,
  });

  @override
  State<_CommunitySearchPicker> createState() => _CommunitySearchPickerState();
}

class _CommunitySearchPickerState extends State<_CommunitySearchPicker> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final nextQuery = _searchController.text.trim().toLowerCase();
    if (nextQuery != _query) setState(() => _query = nextQuery);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maximumHeight = mediaQuery.size.height * 0.62;
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final availableHeight =
        mediaQuery.size.height - keyboardHeight - mediaQuery.padding.top - 24;
    final sheetHeight = math.max(
      160.0,
      math.min(maximumHeight, availableHeight),
    );
    final filteredOptions = widget.options
        .where((option) => option.toLowerCase().contains(_query))
        .toList(growable: false);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: sheetHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  autofocus: false,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Search',
                    prefixIcon: Icon(Icons.search_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: filteredOptions.isEmpty
                      ? const Center(child: Text('No results found'))
                      : ListView.builder(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          itemCount: filteredOptions.length,
                          itemBuilder: (context, index) {
                            final option = filteredOptions[index];
                            final isSelected = option == widget.selectedValue;
                            return ListTile(
                              selected: isSelected,
                              selectedTileColor: const Color(
                                0xFF2563EB,
                              ).withValues(alpha: 0.10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              title: Text(option),
                              trailing: isSelected
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: Color(0xFF2563EB),
                                    )
                                  : null,
                              onTap: () => Navigator.pop(context, option),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
