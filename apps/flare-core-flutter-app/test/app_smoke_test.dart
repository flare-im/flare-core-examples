import 'dart:ui';

import 'package:flare_im/app.dart';
import 'package:flare_im/interface/screens/login/login_screen.dart';
import 'package:flare_im_ui/flare_im_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('renders the IM application shell', (tester) async {
    // 热启动会话恢复会读取偏好存储；空档案 → 走登录页。
    SharedPreferences.setMockInitialValues(const {});
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ProviderScope(child: FlareImApp()));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(FlareAuthShell), findsOneWidget);
    expect(find.byType(FlareInput), findsOneWidget);
    expect(
      tester.widget<FlareButton>(find.byType(FlareButton)).disabled,
      isTrue,
    );
  });
}
