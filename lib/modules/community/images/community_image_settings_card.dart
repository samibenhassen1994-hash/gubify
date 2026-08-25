import 'package:flutter/material.dart';

import '../../../widgets/gub_content_card.dart';
import '../models/community_model.dart';
import 'community_image_service.dart';
import 'community_image_view.dart';

typedef CommunityImageUploadAction =
    Future<CommunityModel?> Function(CommunityModel community);

class CommunityImageManagementSection extends StatelessWidget {
  final bool isOwner;
  final CommunityModel community;
  final CommunityImageUploadAction? onUpload;
  final ValueChanged<CommunityModel>? onUpdated;

  const CommunityImageManagementSection({
    super.key,
    required this.isOwner,
    required this.community,
    this.onUpload,
    this.onUpdated,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOwner) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: CommunityImageSettingsCard(
        community: community,
        onUpload: onUpload,
        onUpdated: onUpdated,
      ),
    );
  }
}

class CommunityImageSettingsCard extends StatefulWidget {
  final CommunityModel community;
  final CommunityImageUploadAction? onUpload;
  final ValueChanged<CommunityModel>? onUpdated;

  const CommunityImageSettingsCard({
    super.key,
    required this.community,
    this.onUpload,
    this.onUpdated,
  });

  @override
  State<CommunityImageSettingsCard> createState() =>
      _CommunityImageSettingsCardState();
}

class _CommunityImageSettingsCardState
    extends State<CommunityImageSettingsCard> {
  bool _uploading = false;

  Future<void> _upload() async {
    if (_uploading) return;
    setState(() => _uploading = true);
    try {
      final updated =
          await (widget.onUpload ??
              CommunityImageService.instance.pickAndUpload)(widget.community);
      if (!mounted || updated == null) return;
      widget.onUpdated?.call(updated);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Community image updated.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.community.imageUrl?.trim().isNotEmpty == true;
    return GubContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Community image',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CommunityImageView(imageUrl: widget.community.imageUrl, size: 84),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _uploading ? null : _upload,
                  icon: _uploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.photo_library_outlined),
                  label: Text(hasImage ? 'Change image' : 'Add image'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
