import 'package:flare_im/application/providers/conversation_state_provider.dart';
import 'package:flare_im/application/providers/workbench_ui_provider.dart';
import 'package:flare_im/interface/screens/conversation_list/conversation_list_screen.dart';
import 'package:flare_im/interface/widgets/conversation_details_panel.dart';
import 'package:flare_im_ui/flare_im_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// SDK route bridge around the public adaptive application shell.
class WorkbenchShell extends ConsumerWidget {
  const WorkbenchShell({super.key, required this.child});

  final Widget child;

  String? _chatIdFromLocation(String location) {
    const prefix = '/chat/';
    if (!location.startsWith(prefix)) return null;
    final rest = location.substring(prefix.length);
    final slash = rest.indexOf('/');
    final raw = slash < 0 ? rest : rest.substring(0, slash);
    if (raw.isEmpty) return null;
    try {
      return Uri.decodeComponent(raw);
    } on FormatException {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final chatId = _chatIdFromLocation(location);
    final detailsOpen = ref.watch(workbenchDetailsOpenProvider);
    final activeId = _activeNavigationId(location);
    final unread = ref.watch(
      conversationProvider.select(
        (items) => items.fold<int>(0, (sum, item) => sum + item.unreadCount),
      ),
    );
    final content = activeId == 'chats' && chatId == null
        ? const FlareEmptyState(
            title: 'Choose a conversation',
            description:
                'Select a conversation to open its SDK-backed timeline.',
            icon: 'chats',
          )
        : child;

    return FlareIMAppKit(
      configuration: _configuration(unread),
      activeNavigationId: activeId,
      label: 'Flare IM Flutter SDK reference app',
      destinationBuilder: (context, id) {
        if (id != activeId) return const SizedBox.shrink();
        final primary = id == 'chats'
            ? const ConversationListScreen(embedInWorkbench: true)
            : null;
        final detail = chatId == null
            ? null
            : ConversationDetailsPanel(
                conversationId: chatId,
                onClose: () =>
                    ref.read(workbenchDetailsOpenProvider.notifier).state =
                        false,
              );
        return FlareAppLayout(
          primary: primary,
          content: content,
          detail: detail,
          hasDetail: detailsOpen && detail != null,
          activePane: detailsOpen && detail != null
              ? FlareWorkspacePane.detail
              : primary != null && chatId == null
              ? FlareWorkspacePane.primary
              : FlareWorkspacePane.content,
        );
      },
      onNavigate: (id) => context.go(_routeForNavigation(id)),
    );
  }

  String _activeNavigationId(String location) {
    if (location.startsWith('/chat/') || location == '/conversations') {
      return 'chats';
    }
    return switch (location) {
      '/search' => 'search',
      '/media' => 'media',
      '/settings' => 'settings',
      '/sdk-lab' => 'sdk-lab',
      _ => 'chats',
    };
  }

  String _routeForNavigation(String id) => switch (id) {
    'search' => '/search',
    'media' => '/media',
    'settings' => '/settings',
    'sdk-lab' => '/sdk-lab',
    _ => '/conversations',
  };

  FlareIMAppConfiguration _configuration(int unread) => FlareIMAppConfiguration(
    features: const FlareFeatureSet({
      'conversations',
      'search',
      'media',
      'settings',
    }),
    capabilities: const FlareCapabilitySet({
      'reply',
      'media',
      'retry',
      'messageActions',
    }),
    navigation: [
      FlareNavigationGroup(
        id: 'reference',
        items: [
          FlareNavigationItem(
            id: 'chats',
            label: 'Chats',
            icon: 'chats',
            badge: unread > 0
                ? FlareNavigationBadge(
                    kind: FlareNavigationBadgeKind.count,
                    count: unread,
                    label: 'Unread conversations',
                  )
                : null,
          ),
          const FlareNavigationItem(
            id: 'search',
            label: 'Search',
            icon: 'search',
          ),
          const FlareNavigationItem(id: 'media', label: 'Media', icon: 'image'),
          const FlareNavigationItem(
            id: 'settings',
            label: 'Settings',
            icon: 'settings',
          ),
          const FlareNavigationItem(
            id: 'sdk-lab',
            label: 'SDK Lab',
            icon: 'diagnostics',
            accessibilityLabel: 'Flutter SDK Lab',
          ),
        ],
      ),
    ],
  );
}
