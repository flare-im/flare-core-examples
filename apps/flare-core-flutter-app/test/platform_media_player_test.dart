import 'dart:async';

import 'package:flare_im/interface/widgets/media_viewer/video_player_modal.dart';
import 'package:flare_im_ui/flare_im_ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

class TestMediaController extends VideoPlayerController {
  TestMediaController({
    this.fail = false,
    this.pending,
    this.failDispose = false,
  }) : super.networkUrl(Uri.parse('https://example.test/audio.mp4'));

  final bool fail;
  final Completer<void>? pending;
  final bool failDispose;
  bool released = false;

  @override
  Future<void> initialize() async {
    await pending?.future;
    if (released) return;
    if (fail) throw StateError('decode failed');
    value = value.copyWith(
      isInitialized: true,
      duration: const Duration(seconds: 10),
      size: const Size(320, 180),
    );
  }

  @override
  Future<void> setLooping(bool looping) async {}
  @override
  Future<void> play() async => value = value.copyWith(isPlaying: true);
  @override
  Future<void> pause() async => value = value.copyWith(isPlaying: false);
  @override
  Future<void> seekTo(Duration position) async =>
      value = value.copyWith(position: position);
  @override
  Future<void> setPlaybackSpeed(double speed) async =>
      value = value.copyWith(playbackSpeed: speed);
  @override
  Future<void> dispose() async {
    released = true;
    await super.dispose();
    if (failDispose) throw StateError('platform teardown failed');
  }
}

Future<void> openPlayer(
  WidgetTester tester, {
  String source = 'https://example.test/audio.mp4',
  required VideoPlayerController Function(String) create,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => VideoPlayerModal.show(
              context,
              videoUrl: source,
              audioOnly: true,
              controllerFactory: create,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

void main() {
  testWidgets(
    'initialization times out and stale completion cannot replace retry',
    (tester) async {
      final pending = Completer<void>();
      final stalled = TestMediaController(pending: pending, failDispose: true);
      final recovered = TestMediaController();
      var attempts = 0;
      await openPlayer(
        tester,
        settle: false,
        create: (_) => attempts++ == 0 ? stalled : recovered,
      );
      await tester.pump(const Duration(seconds: 21));
      await tester.pumpAndSettle();
      expect(find.text('无法播放此媒体'), findsOneWidget);
      expect(stalled.released, isTrue);
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      pending.complete();
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.byType(ui.FlareVoicePlayer), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(recovered.released, isTrue);
    },
  );

  testWidgets(
    'dismiss during initialization ignores late completion and disposal errors',
    (tester) async {
      final pending = Completer<void>();
      final controller = TestMediaController(
        pending: pending,
        failDispose: true,
      );
      await openPlayer(tester, settle: false, create: (_) => controller);
      await tester.pumpWidget(const SizedBox());
      pending.complete();
      await tester.pumpAndSettle();
      expect(controller.released, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'audio uses public player controls and releases platform decoding on close',
    (tester) async {
      final controller = TestMediaController();
      await openPlayer(tester, create: (_) => controller);
      expect(find.byType(ui.FlareVideoPlayer), findsOneWidget);
      expect(find.byType(ui.FlareVoicePlayer), findsOneWidget);
      var controls = tester.widget<ui.FlareVoicePlayer>(
        find.byType(ui.FlareVoicePlayer),
      );
      controls.onToggle!();
      await tester.pump();
      expect(controller.value.isPlaying, isTrue);
      controls.onSeek!(0.5);
      await tester.pump();
      expect(controller.value.position, const Duration(seconds: 5));
      controls.onCycleSpeed!();
      await tester.pump();
      expect(controller.value.playbackSpeed, 1.5);
      controls = tester.widget<ui.FlareVoicePlayer>(
        find.byType(ui.FlareVoicePlayer),
      );
      expect(controls.playing, isTrue);
      expect(controls.progress, 0.5);
      await tester.tap(find.bySemanticsLabel('关闭'));
      await tester.pumpAndSettle();
      expect(controller.released, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'invalid media is rejected without creating a platform controller',
    (tester) async {
      var created = false;
      await openPlayer(
        tester,
        source: 'javascript:alert(1)',
        create: (_) {
          created = true;
          return TestMediaController();
        },
      );
      expect(created, isFalse);
      expect(find.text('无效媒体地址'), findsOneWidget);
      expect(find.byType(ui.FlareEmptyState), findsOneWidget);
      expect(find.byType(ui.FlareVoicePlayer), findsNothing);
    },
  );

  testWidgets(
    'decoder failure shows kit retry and disposes the failed controller',
    (tester) async {
      final failed = TestMediaController(fail: true);
      final recovered = TestMediaController();
      var attempts = 0;
      await openPlayer(
        tester,
        create: (_) => attempts++ == 0 ? failed : recovered,
      );
      expect(find.text('无法播放此媒体'), findsOneWidget);
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(failed.released, isTrue);
      expect(find.byType(ui.FlareVoicePlayer), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(recovered.released, isTrue);
    },
  );
}
