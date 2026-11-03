import 'dart:ui';

import 'package:flare_im/app.dart';
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

    expect(find.textContaining('flare'), findsWidgets);
  });
}
