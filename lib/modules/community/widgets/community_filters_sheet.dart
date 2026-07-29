import 'package:flutter/material.dart';

import '../models/community_model.dart';
import 'community_search_picker.dart';

class CommunityExplorerFilters {
  final String? type;
  final String? language;

  const CommunityExplorerFilters({this.type, this.language});

  bool get hasActiveFilters => type != null || language != null;
}

class CommunityFiltersSheet extends StatefulWidget {
  final CommunityExplorerFilters initialFilters;

  const CommunityFiltersSheet({super.key, required this.initialFilters});

  @override
  State<CommunityFiltersSheet> createState() => _CommunityFiltersSheetState();
}

class _CommunityFiltersSheetState extends State<CommunityFiltersSheet> {
  String? _type;
  String? _language;

  @override
  void initState() {
    super.initState();
    _type = widget.initialFilters.type;
    _language = widget.initialFilters.language;
  }

  Future<void> _selectType() async {
    const allTypes = 'All types';
    final selection = await showCommunitySearchPicker(
      context: context,
      title: 'Filter by type',
      options: const [allTypes, ...CommunityModel.availableTypes],
      selectedValue: _type ?? allTypes,
    );
    if (!mounted || selection == null) return;
    setState(() => _type = selection == allTypes ? null : selection);
  }

  Future<void> _selectLanguage() async {
    const allLanguages = 'All languages';
    final selection = await showCommunitySearchPicker(
      context: context,
      title: 'Filter by language',
      options: const [allLanguages, ...CommunityModel.availableLanguages],
      selectedValue: _language ?? allLanguages,
    );
    if (!mounted || selection == null) return;
    setState(() => _language = selection == allLanguages ? null : selection);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Filters",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            CommunityPickerField(
              label: 'Type',
              value: _type ?? 'All types',
              enabled: true,
              onTap: _selectType,
            ),
            const SizedBox(height: 16),
            CommunityPickerField(
              label: 'Language',
              value: _language ?? 'All languages',
              enabled: true,
              onTap: _selectLanguage,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _type = null;
                      _language = null;
                    });
                  },
                  child: const Text("Clear filters"),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    CommunityExplorerFilters(type: _type, language: _language),
                  ),
                  child: const Text("Apply"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
