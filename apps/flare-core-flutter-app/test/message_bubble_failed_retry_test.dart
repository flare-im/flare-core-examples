import 'package:flare_im/domain/entities/message.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/domain/value_objects/message_content.dart';
import 'package:flare_im/interface/widgets/message/sdk_message_bubble_adapter.dart';
import 'package:flare_im_ui/flare_im_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('failed self message keeps retry affordance near the bubble', (
    tester,
  ) async {
    var retryCount = 0;
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SdkMessageBubbleAdapter(
              message: Message(
                serverId: '',
                clientMsgId: 'cm1',
                conversationId: 'c1',
                senderId: 'u1',
                seq: 0,
                timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
                clientTimestamp: DateTime.fromMillisecondsSinceEpoch(1000),
                content: const TextContent('hello'),
                status: MessageStatus.failed,
                source: MessageSource.local,
                senderName: '',
                senderAvatar: '',
                senderDisplayName: '',
              ),
              currentUserId: 'u1',
              pinToggleLabel: 'Pin message',
              onResend: () => retryCount++,
            ),
          ),
        ),
      ),
    );

    final retry = find.byType(FlareMessageStatus);
    expect(retry, findsOneWidget);
    expect(tester.getTopLeft(retry).dx, greaterThan(500));

    await tester.tap(retry);
    expect(retryCount, 1);
  });
}
