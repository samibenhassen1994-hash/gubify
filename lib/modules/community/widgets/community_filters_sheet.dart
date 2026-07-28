import 'package:flutter/material.dart';

import '../models/community_model.dart';

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
            DropdownButtonFormField<String?>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: "Type",
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text("All types"),
                ),
                ...CommunityModel.availableTypes.map(
                  (type) =>
                      DropdownMenuItem<String?>(value: type, child: Text(type)),
                ),
              ],
              onChanged: (type) => setState(() => _type = type),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _language,
              decoration: const InputDecoration(
                labelText: "Language",
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text("All languages"),
                ),
                ...CommunityModel.availableLanguages.map(
                  (language) => DropdownMenuItem<String?>(
                    value: language,
                    child: Text(language),
                  ),
                ),
              ],
              onChanged: (language) => setState(() => _language = language),
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
