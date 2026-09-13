import 'package:flutter/material.dart';

import 'platform_admin_service.dart';
import 'platform_communities_screen.dart';

class PlatformAdminGate extends StatelessWidget {
  const PlatformAdminGate({
    super.key,
    required this.service,
    required this.builder,
  });
  final PlatformAdminService service;
  final WidgetBuilder builder;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: service,
    builder: (context, _) => service.isAdmin
        ? builder(context)
        : Scaffold(
            appBar: AppBar(),
            body: const Center(
              child: Text('Community moderation access is unavailable.'),
            ),
          ),
  );
}

class PlatformAdminEntry extends StatelessWidget {
  const PlatformAdminEntry({super.key, this.service, this.screenBuilder});
  final PlatformAdminService? service;
  final WidgetBuilder? screenBuilder;
  @override
  Widget build(BuildContext context) {
    final role = service ?? PlatformAdminService.instance;
    return ListenableBuilder(
      listenable: role,
      builder: (context, _) => !role.isAdmin
          ? const SizedBox.shrink()
          : ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('Community moderation'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PlatformAdminGate(
                    service: role,
                    builder:
                        screenBuilder ??
                        (_) => PlatformCommunitiesScreen(role: role),
                  ),
                ),
              ),
            ),
    );
  }
}
