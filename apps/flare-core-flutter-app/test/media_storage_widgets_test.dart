import 'dart:io' show Platform;

import 'package:flare_im/application/providers/service_providers.dart';
import 'package:flare_im/application/services/media_storage_service.dart';
import 'package:flare_im/domain/entities/message.dart';
import 'package:flare_im/domain/repositories/i_media_repository.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/domain/value_objects/media_storage.dart';
import 'package:flare_im/domain/value_objects/message_content.dart';
import 'package:flare_im/infrastructure/platform/download_location_host.dart';
import 'package:flare_im/interface/screens/settings/settings_screen.dart';
import 'package:flare_im/interface/widgets/message/sdk_message_bubble_adapter.dart';
import 'package:flare_im_ui/flare_im_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 设置页「下载位置」「图片与文件缓存」，以及时间线上图片的显示与保存 —— 核心 SDK 换成假的。

void main() {
  late List<String> hostCalls;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    hostCalls = [];
    // The host half of the download location (macOS channel).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DownloadLocationHost.channel, (call) async {
          hostCalls.add(call.method);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DownloadLocationHost.channel, null);
  });

  group('settings: storage', () {
    testWidgets('the download location shows the folder and goes back to the '
        'default', (tester) async {
      final repo = _StorageRepository(
        location: const DownloadLocation(
          directory: '/Volumes/Work/收件',
          defaultDirectory: '/Users/me/Downloads/flare',
          isCustom: true,
        ),
      );
      await _pumpSettings(tester, repo);

      expect(find.text('下载位置'), findsOneWidget);
      expect(find.text('/Volumes/Work/收件'), findsOneWidget);
      await tester.tap(find.text('下载位置'));
      await tester.pumpAndSettle();
      // The sheet is drawn (its list shrink-wraps inside the column): the
      // folder in the row and in the sheet, and both actions.
      expect(find.text('/Volumes/Work/收件'), findsNWidgets(2));
      expect(find.text('更改位置'), findsOneWidget);
      await tester.tap(find.text('恢复默认位置'));
      await tester.pumpAndSettle();

      expect(repo.set, [null]);
      expect(repo.location.isCustom, isFalse);
      // Back on the default, the host drops the old folder's bookmark (macOS).
      if (Platform.isMacOS) expect(hostCalls, ['forgetDirectory']);
      expect(find.text('/Volumes/Work/收件'), findsNothing);
      // The row and the confirmation toast name the default folder.
      expect(find.textContaining('Downloads/flare'), findsNWidgets(2));
    });

    testWidgets('a default location offers no reset', (tester) async {
      final repo = _StorageRepository(location: _defaultLocation);
      await _pumpSettings(tester, repo);
      await tester.tap(find.text('下载位置'));
      await tester.pumpAndSettle();
      expect(find.text('恢复默认位置'), findsNothing);
    });

    testWidgets('the media cache shows its size and clears after a '
        'confirmation', (tester) async {
      final repo = _StorageRepository(location: _defaultLocation);
      await _pumpSettings(tester, repo);
      expect(find.text('图片与文件缓存'), findsOneWidget);
      expect(find.text('3.0 MB'), findsOneWidget);

      await tester.tap(find.text('图片与文件缓存'));
      await tester.pumpAndSettle();
      expect(find.byType(FlareDangerConfirm), findsOneWidget);
      expect(repo.clears, 0);
      // The title and the confirm key share the words; the key is the last.
      await tester.tap(_inConfirm('清除缓存').last);
      await tester.pumpAndSettle();

      expect(repo.clears, 1);
      expect(find.byType(FlareDangerConfirm), findsNothing);
      expect(find.text('0 B'), findsOneWidget);
      expect(find.text('缓存已清除'), findsOneWidget);
    });

    testWidgets('on a wide window the storage overlays are kit Modals, and '
        'the location sheet is named', (tester) async {
      final semantics = tester.ensureSemantics();
      final repo = _StorageRepository(location: _defaultLocation);
      await _pumpSettings(tester, repo, size: const Size(1280, 900));
      await tester.tap(find.text('下载位置'));
      await tester.pumpAndSettle();
      expect(find.byType(FlareModal), findsOneWidget);
      expect(
        tester.getSemantics(
          find
              .descendant(
                of: find.byType(FlareModal),
                matching: find.bySemanticsLabel('下载位置'),
              )
              .first,
        ),
        isSemantics(label: '下载位置', namesRoute: true),
      );
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(FlareModal), findsNothing);

      await tester.tap(find.text('图片与文件缓存'));
      await tester.pumpAndSettle();
      expect(
        find.ancestor(
          of: find.byType(FlareDangerConfirm),
          matching: find.byType(FlareModal),
        ),
        findsOneWidget,
      );
      await tester.tap(_inConfirm('清除缓存').last);
      await tester.pumpAndSettle();
      expect(repo.clears, 1);
      expect(find.byType(FlareModal), findsNothing);
      semantics.dispose();
    });

    testWidgets('a cache that could not be cleared says so and can be '
        'retried', (tester) async {
      final repo = _StorageRepository(location: _defaultLocation)
        ..failClear = true;
      await _pumpSettings(tester, repo);
      await tester.tap(find.text('图片与文件缓存'));
      await tester.pumpAndSettle();
      await tester.tap(_inConfirm('清除缓存').last);
      await tester.pumpAndSettle();

      expect(find.byType(FlareDangerConfirm), findsOneWidget);
      expect(_inConfirm('缓存没有清除，请重试'), findsOneWidget);
      expect(find.text('3.0 MB'), findsOneWidget);
    });

    testWidgets('an SDK that is not ready leaves the rows unmeasured', (
      tester,
    ) async {
      final repo = _StorageRepository(location: _defaultLocation)
        ..notReady = true;
      await _pumpSettings(tester, repo);
      expect(find.text('下载位置'), findsOneWidget);
      expect(find.textContaining('Downloads'), findsNothing);
      expect(find.text('未统计'), findsOneWidget);
    });
  });

  group('timeline media', () {
    testWidgets('a picture in the SDK cache is drawn from disk, and its '
        'preview saves it to the download location', (tester) async {
      final repo = _StorageRepository(location: _defaultLocation)
        ..pictures['img-1'] = const PictureAccess(
          localPath: '/cache/media/img-1.jpg',
        );
      await _pumpBubble(
        tester,
        repo,
        const ImageContent(
          url: 'https://cdn.example/img-1?sig=old',
          fileId: 'img-1',
          width: 120,
          height: 90,
        ),
      );

      final picture = find.byWidgetPredicate(
        (w) =>
            w is FlareImageMessage &&
            w.src == '/cache/media/img-1.jpg' &&
            w.allowLocalFile,
      );
      expect(picture, findsOneWidget);
      expect(repo.resolved, ['img-1']);

      await tester.tap(picture);
      await tester.pumpAndSettle();
      await tester.tap(_downloadKey);
      await tester.pumpAndSettle();

      expect(repo.saved.single.fileId, 'img-1');
      expect(repo.saved.single.fileName, startsWith('IMG_'));
      expect(find.textContaining('已保存到'), findsOneWidget);
      expect(find.textContaining('Downloads/flare'), findsOneWidget);
    });

    testWidgets('an address-only picture keeps its address', (tester) async {
      final repo = _StorageRepository(location: _defaultLocation);
      await _pumpBubble(
        tester,
        repo,
        const ImageContent(url: 'https://cdn.example/plain.jpg'),
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is FlareImageMessage &&
              w.src == 'https://cdn.example/plain.jpg' &&
              !w.allowLocalFile,
        ),
        findsOneWidget,
      );
      // No stored id: the SDK is not asked.
      expect(repo.resolved, isEmpty);
    });

    testWidgets('tapping a file saves it by its stored id', (tester) async {
      final repo = _StorageRepository(location: _defaultLocation);
      await _pumpBubble(
        tester,
        repo,
        const FileContent(
          url: 'https://cdn.example/f-1?sig=1',
          fileId: 'f-1',
          filename: '需求稿.pdf',
          size: 2048,
        ),
      );
      await tester.tap(find.text('需求稿.pdf'));
      await tester.pumpAndSettle();

      expect(
        repo.saved.single,
        const MediaSaveTarget(fileName: '需求稿.pdf', fileId: 'f-1'),
      );
      expect(find.textContaining('已保存到'), findsOneWidget);
    });

    testWidgets('a save that fails says it was not saved; an unwritable '
        'folder says so', (tester) async {
      final repo = _StorageRepository(location: _defaultLocation)
        ..saveError = StateError('download directory is not writable: denied');
      await _pumpBubble(
        tester,
        repo,
        const FileContent(url: '', fileId: 'f-2', filename: 'a.txt'),
      );
      await tester.tap(find.text('a.txt'));
      await tester.pumpAndSettle();
      expect(find.text('这个文件夹不能写入，请换一个'), findsOneWidget);

      repo.saveError = StateError('network');
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();
      await tester.tap(find.text('a.txt'));
      await tester.pumpAndSettle();
      expect(find.text('没有保存成功，请重试'), findsOneWidget);
    });

    testWidgets('someone else\'s message pointing at a file on this device '
        'offers no save', (tester) async {
      final repo = _StorageRepository(location: _defaultLocation);
      await _pumpBubble(
        tester,
        repo,
        const FileContent(
          url: '/Users/me/Library/Application Support/flare/flare.db',
          filename: 'flare.db',
        ),
      );
      await tester.tap(find.text('flare.db'));
      await tester.pumpAndSettle();
      expect(repo.saved, isEmpty);
      expect(find.textContaining('保存'), findsNothing);

      await tester.longPress(find.text('flare.db'));
      await tester.pumpAndSettle();
      expect(find.text('复制'), findsOneWidget);
      expect(find.text('保存'), findsNothing);
    });

    testWidgets('the long-press menu saves a video', (tester) async {
      final repo = _StorageRepository(location: _defaultLocation);
      await _pumpBubble(
        tester,
        repo,
        const VideoContent(
          url: 'https://cdn.example/v.mp4',
          fileId: 'vid-1',
          duration: 12,
        ),
      );
      await tester.longPress(find.byType(FlareVideoMessage));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(repo.saved.single.fileId, 'vid-1');
      expect(repo.saved.single.fileName, startsWith('VID_'));
    });
  });
}

const _defaultLocation = DownloadLocation(
  directory: '/Users/me/Downloads/flare',
  defaultDirectory: '/Users/me/Downloads/flare',
  isCustom: false,
);

final _downloadKey = find.byWidgetPredicate(
  (w) => w is FlareIconButton && w.icon == 'download',
);

Finder _inConfirm(String text) => find.descendant(
  of: find.byType(FlareDangerConfirm),
  matching: find.text(text),
);

Future<void> _pumpSettings(
  WidgetTester tester,
  _StorageRepository repo, {
  Size size = const Size(480, 1400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [mediaRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: SettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpBubble(
  WidgetTester tester,
  _StorageRepository repo,
  MessageContent content,
) async {
  tester.view.physicalSize = const Size(800, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mediaRepositoryProvider.overrideWithValue(repo),
        mediaStorageServiceProvider.overrideWithValue(
          MediaStorageService(repo, fileExists: (_) => true),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SdkMessageBubbleAdapter(
              message: Message(
                serverId: 's1',
                clientMsgId: 'c1',
                conversationId: 'conv',
                senderId: 'u2',
                seq: 1,
                timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
                clientTimestamp: DateTime.fromMillisecondsSinceEpoch(1000),
                content: content,
                status: MessageStatus.sent,
                source: MessageSource.remote,
                senderName: 'Ann',
                senderAvatar: '',
                senderDisplayName: '',
              ),
              currentUserId: 'u1',
              pinToggleLabel: 'Pin message',
              onCopy: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The core SDK's download location, save and media cache, without the SDK.
class _StorageRepository implements IMediaRepository {
  _StorageRepository({required this.location});

  DownloadLocation location;
  final List<String?> set = [];
  final Map<String, PictureAccess> pictures = {};
  final List<String> resolved = [];
  final List<MediaSaveTarget> saved = [];
  Object? saveError;
  int cacheBytes = 3 * 1024 * 1024;
  int clears = 0;
  bool failClear = false;
  bool notReady = false;

  void _ready() {
    if (notReady) throw StateError('flare sdk is not initialized');
  }

  @override
  Future<DownloadLocation> getDownloadLocation() async {
    _ready();
    return location;
  }

  @override
  Future<DownloadLocation> setDownloadLocation(String? directory) async {
    set.add(directory);
    return location = DownloadLocation(
      directory: directory ?? location.defaultDirectory,
      defaultDirectory: location.defaultDirectory,
      isCustom: directory != null,
    );
  }

  @override
  Future<SavedMediaFile> saveToDownloadLocation(MediaSaveTarget target) async {
    final error = saveError;
    if (error != null) throw error;
    saved.add(target);
    return SavedMediaFile(
      path: '${location.directory}/${target.fileName}',
      directory: location.directory,
      fileName: target.fileName,
    );
  }

  @override
  Future<PictureAccess> resolvePicture(String fileId) async {
    resolved.add(fileId);
    return pictures[fileId] ?? const PictureAccess();
  }

  @override
  Future<int?> mediaCacheBytes() async {
    _ready();
    return cacheBytes;
  }

  @override
  Future<void> clearMediaCache() async {
    if (failClear) throw StateError('io error');
    clears++;
    cacheBytes = 0;
  }
}
