import 'package:flare_im/application/providers/auth_state_provider.dart';
import 'package:flare_im/interface/screens/chat/chat_screen.dart';
import 'package:flare_im/interface/screens/conversation_list/conversation_list_screen.dart';
import 'package:flare_im/interface/screens/login/login_screen.dart';
import 'package:flare_im/interface/screens/message_search/message_search_screen.dart';
import 'package:flare_im/interface/screens/sdk_lab/sdk_lab_screen.dart';
import 'package:flare_im/interface/screens/settings/settings_screen.dart';
import 'package:flare_im/interface/shell/workbench_shell.dart';
import 'package:flare_im/shared/layout/workbench_layout.dart';
import 'package:flare_im_ui/flare_im_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 全局路由可见性观察器：供页面级 RouteAware（如 ChatScreen）订阅。
final RouteObserver<ModalRoute<dynamic>> appRouteObserver =
    RouteObserver<ModalRoute<dynamic>>();

/// 与会话列表 [Uri.encodeComponent] 成对；非法 `%` 序列时回退原串，避免深链崩溃。
String decodeRouteConversationId(String raw) {
  if (raw.isEmpty) return raw;
  try {
    return Uri.decodeComponent(raw);
  } on FormatException {
    return raw;
  }
}

bool _isWide(BuildContext context) {
  return MediaQuery.sizeOf(context).width >= kWorkbenchWideBreakpoint;
}

/// 应用路由配置
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),

      ShellRoute(
        builder: (context, state, child) => WorkbenchShell(child: child),
        routes: [
          GoRoute(
            path: '/conversations',
            builder: (context, state) {
              if (_isWide(context)) {
                return const SizedBox.shrink();
              }
              return const ConversationListScreen();
            },
          ),
          GoRoute(
            path: '/chat/:conversationId',
            builder: (context, state) {
              final raw = (state.pathParameters['conversationId'] ?? '').trim();
              final conversationId = decodeRouteConversationId(raw);
              return ChatScreen(
                conversationId: conversationId,
                embedInWorkbench: _isWide(context),
              );
            },
          ),
          GoRoute(
            path: '/media',
            builder: (context, state) => const _UnavailableCapabilityScreen(
              title: 'Media',
              description:
                  'Open a conversation to inspect SDK-backed media messages.',
              icon: 'image',
            ),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const MessageSearchScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/sdk-lab',
            builder: (context, state) => const SdkLabScreen(),
          ),
        ],
      ),

      GoRoute(
        path: '/chat/:conversationId/search',
        builder: (context, state) {
          final raw = (state.pathParameters['conversationId'] ?? '').trim();
          return MessageSearchScreen(
            conversationId: decodeRouteConversationId(raw),
          );
        },
      ),

      GoRoute(
        path: '/',
        redirect: (context, state) async {
          if (ref.read(isLoggedInProvider)) return '/conversations';
          // 热启动：本地会话档案存在时 prepare 本地出图（毫秒级），跳过登录页；
          // 连接与增量同步在后台补齐。
          final resumed = await ref
              .read(currentUserProvider.notifier)
              .resumeSavedSession();
          return resumed ? '/conversations' : '/login';
        },
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('页面不存在: ${state.error}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('返回首页'),
            ),
          ],
        ),
      ),
    ),

    observers: [appRouteObserver, _RouterObserver(ref)],
  );
});

class _UnavailableCapabilityScreen extends StatelessWidget {
  const _UnavailableCapabilityScreen({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final String icon;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: FlareEmptyState(
        title: title,
        description: description,
        icon: icon,
      ),
    ),
  );
}

/// 路由监听器
class _RouterObserver extends NavigatorObserver {
  final Ref ref;

  _RouterObserver(this.ref);
}
