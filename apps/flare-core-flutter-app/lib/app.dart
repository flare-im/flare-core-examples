import 'package:flare_im/application/providers/app_theme_mode_provider.dart';
import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/infrastructure/platform/app_platform_adapter.dart';
import 'package:flare_im/interface/router/app_router.dart';
import 'package:flare_im/interface/sdk_event_scope.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im_ui/flare_im_ui.dart' show FlarePlatformScope;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Flare IM 应用主组件
class FlareImApp extends ConsumerWidget {
  const FlareImApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final flareLocale = ref.watch(flareLocaleProvider);
    final themeMode = ref.watch(appThemeModeProvider);

    // The host's platform contract (pickers through image_picker / file_picker)
    // for every kit component below.
    return SdkEventScope(
      child: FlarePlatformScope(
        adapter: const AppPlatformAdapter(),
        child: MaterialApp.router(
          title: 'Flare IM',
          themeMode: themeMode,
          locale: materialLocaleFor(flareLocale),
          supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: FlareImDesign.lightTheme(),
          darkTheme: FlareImDesign.darkTheme(),
          routerConfig: router,
        ),
      ),
    );
  }
}
