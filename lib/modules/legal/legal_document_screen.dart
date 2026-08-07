import 'package:flutter/material.dart';

class LegalSection {
  final String title;
  final List<LegalBlock> blocks;

  const LegalSection({required this.title, required this.blocks});
}

enum LegalBlockType { paragraph, subheading, bullets, address }

class LegalBlock {
  final LegalBlockType type;
  final String? text;
  final List<String>? items;

  const LegalBlock._({required this.type, this.text, this.items});

  const LegalBlock.paragraph(String text)
      : this._(type: LegalBlockType.paragraph, text: text);

  const LegalBlock.subheading(String text)
      : this._(type: LegalBlockType.subheading, text: text);

  const LegalBlock.bullets(List<String> items)
      : this._(type: LegalBlockType.bullets, items: items);

  const LegalBlock.address(String text)
      : this._(type: LegalBlockType.address, text: text);
}

class LegalDocumentScreen extends StatelessWidget {
  final String title;
  final String intro;
  final String versionLabel;
  final String version;
  final String lastUpdated;
  final IconData icon;
  final List<LegalSection> sections;

  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.intro,
    required this.versionLabel,
    required this.version,
    required this.lastUpdated,
    required this.icon,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const primary = Color(0xFF3B82F6);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE8EDF5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    intro,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.55,
                      color: const Color(0xFF4B5563),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetaChip(label: 'Last updated', value: lastUpdated),
                      _MetaChip(label: versionLabel, value: version),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            for (var i = 0; i < sections.length; i++) ...[
              _LegalSectionView(section: sections[i]),
              if (i != sections.length - 1) const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetaChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF4B5563),
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _LegalSectionView extends StatelessWidget {
  final LegalSection section;

  const _LegalSectionView({required this.section});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: const TextStyle(
              fontSize: 18,
              height: 1.25,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < section.blocks.length; i++) ...[
            _LegalBlockView(block: section.blocks[i]),
            if (i != section.blocks.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _LegalBlockView extends StatelessWidget {
  final LegalBlock block;

  const _LegalBlockView({required this.block});

  @override
  Widget build(BuildContext context) {
    const bodyStyle = TextStyle(
      fontSize: 14,
      height: 1.55,
      color: Color(0xFF374151),
    );

    switch (block.type) {
      case LegalBlockType.subheading:
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            block.text ?? '',
            style: const TextStyle(
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
        );
      case LegalBlockType.bullets:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in block.items ?? const <String>[])
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: Icon(
                        Icons.circle,
                        size: 5,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item, style: bodyStyle)),
                  ],
                ),
              ),
          ],
        );
      case LegalBlockType.address:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            block.text ?? '',
            style: bodyStyle.copyWith(fontWeight: FontWeight.w600),
          ),
        );
      case LegalBlockType.paragraph:
        return Text(block.text ?? '', style: bodyStyle);
    }
  }
}
