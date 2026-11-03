import 'dart:async';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_im/application/services/media_storage_service.dart';
import 'package:flare_im/domain/repositories/i_media_repository.dart';
import 'package:flare_im/domain/value_objects/media_storage.dart';
import 'package:flare_im/domain/value_objects/message_content.dart';
import 'package:flare_im/infrastructure/platform/download_location_host.dart';
import 'package:flare_im/infrastructure/repositories/media_repository_impl.dart';
import 'package:flare_im/infrastructure/sdk/flare_core_sdk_wrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('picture resolution', () {
    late _FakeMediaRepository repo;
    late DateTime now;
    late Set<String> files;
    late MediaStorageService service;

    setUp(() {
      repo = _FakeMediaRepository();
      now = DateTime(2026, 9, 27, 12);
      files = {};
      service = MediaStorageService(
        repo,
        now: () => now,
        fileExists: files.contains,
      );
    });

    test('a picture in the SDK cache is drawn from disk, and asked only '
        'once', () async {
      repo.pictures['img-1'] = const PictureAccess(
        localPath: '/cache/img-1.jpg',
      );
      files.add('/cache/img-1.jpg');

      expect(
        await service.resolvePicture('img-1'),
        const PictureAccess(localPath: '/cache/img-1.jpg'),
      );
      expect(
        await service.resolvePicture('img-1'),
        const PictureAccess(localPath: '/cache/img-1.jpg'),
      );
      // A rebuild reads the answer without waiting.
      expect(
        service.peekPicture('img-1'),
        const PictureAccess(localPath: '/cache/img-1.jpg'),
      );
      expect(repo.resolved, ['img-1']);
    });

    test('a signed address is reused briefly, then the SDK is asked again '
        '(its background cache takes over)', () async {
      repo.pictures['img-2'] = const PictureAccess(
        url: 'https://cdn.example/img-2?sig=1',
      );
      expect(
        (await service.resolvePicture('img-2'))?.url,
        'https://cdn.example/img-2?sig=1',
      );
      now = now.add(const Duration(seconds: 10));
      expect(service.peekPicture('img-2')?.url, isNotNull);
      await service.resolvePicture('img-2');
      expect(repo.resolved, ['img-2']);

      now = now.add(const Duration(seconds: 15));
      expect(service.peekPicture('img-2'), isNull);
      repo.pictures['img-2'] = const PictureAccess(
        localPath: '/cache/img-2.jpg',
      );
      files.add('/cache/img-2.jpg');
      expect(
        await service.resolvePicture('img-2'),
        const PictureAccess(localPath: '/cache/img-2.jpg'),
      );
      expect(repo.resolved, ['img-2', 'img-2']);
    });

    test('rows asking at the same time share one SDK call', () async {
      final gate = Completer<void>();
      repo.gate = gate.future;
      repo.pictures['img-3'] = const PictureAccess(localPath: '/cache/3.jpg');
      files.add('/cache/3.jpg');
      final a = service.resolvePicture('img-3');
      final b = service.resolvePicture('img-3');
      gate.complete();
      expect(await a, await b);
      expect(repo.resolved, ['img-3']);
    });

    test(
      'a cached copy that is gone (cache cleared) is asked for again',
      () async {
        repo.pictures['img-4'] = const PictureAccess(localPath: '/cache/4.jpg');
        files.add('/cache/4.jpg');
        await service.resolvePicture('img-4');
        files.clear();
        expect(service.peekPicture('img-4'), isNull);
        await service.resolvePicture('img-4');
        expect(repo.resolved, ['img-4', 'img-4']);
      },
    );

    test(
      'an SDK that cannot answer leaves the message address in place',
      () async {
        repo.failResolve = true;
        expect(await service.resolvePicture('img-5'), isNull);
        expect(await service.resolvePicture(''), isNull);
      },
    );
  });

  group('saving and settings', () {
    test('saving hands the core the stored id and the name', () async {
      final repo = _FakeMediaRepository();
      final service = MediaStorageService(
        repo,
        now: () => DateTime(2026, 1, 2, 3, 4, 5),
      );
      final saved = await service.saveMessageMedia(
        const ImageContent(url: 'https://cdn.example/p', fileId: 'img-1'),
      );
      expect(
        repo.saved.single,
        const MediaSaveTarget(fileName: 'IMG_20260102_030405', fileId: 'img-1'),
      );
      expect(saved.directory, '/Users/me/Downloads/flare');
      await expectLater(
        service.saveMessageMedia(const TextContent('hi')),
        throwsStateError,
      );
      // Someone else's path is never handed to the core as a source.
      await expectLater(
        service.saveMessageMedia(
          const FileContent(url: '/Users/me/flare.db', filename: 'flare.db'),
        ),
        throwsStateError,
      );
      expect(repo.saved, hasLength(1));
      await service.saveMessageMedia(
        const FileContent(url: '/Users/me/Desktop/a.txt', filename: 'a.txt'),
        ownMessage: true,
      );
      expect(repo.saved.last.sourcePath, '/Users/me/Desktop/a.txt');
    });

    test('cache size that cannot be measured is null, not 0', () async {
      final repo = _FakeMediaRepository()..cacheBytes = 42;
      final service = MediaStorageService(repo);
      expect(await service.mediaCacheBytes(), 42);
      repo.failCache = true;
      expect(await service.mediaCacheBytes(), isNull);
    });
  });

  group('core wire shapes', () {
    test('SdkWrapper sends the core media requests it documents', () async {
      final media = _RecordingMediaApi();
      final sdk = SdkWrapper(client: _FakeFlareImClient(media));

      await sdk.resolveMediaAccess('img-1', autoCache: true);
      expect(media.calls.last.$1, 'resolveMediaAccess');
      expect(media.calls.last.$2, {
        'fileId': 'img-1',
        'expiresIn': 3600,
        'autoCache': true,
      });

      await sdk.setUserDownloadDirectory(null);
      expect(media.calls.last.$1, 'setUserDownloadDirectory');
      expect(media.calls.last.$2, {'directory': null});

      await sdk.downloadToUserDirectory(fileName: 'a.pdf', fileId: 'f-1');
      // Absent sources are left out, not sent as null.
      expect(media.calls.last.$1, 'downloadToUserDirectory');
      expect(media.calls.last.$2, {
        'fileName': 'a.pdf',
        'fileId': 'f-1',
        'expiresIn': 3600,
      });
    });

    test('the repository never reaches the SDK before init', () async {
      final media = _RecordingMediaApi();
      final repo = MediaRepositoryImpl(
        SdkWrapper(client: _FakeFlareImClient(media)),
      );
      await expectLater(repo.getDownloadLocation(), throwsStateError);
      await expectLater(repo.resolvePicture('img-1'), throwsStateError);
      expect(media.calls, isEmpty);
    });

    test('core results map to the app\'s media values', () {
      expect(
        downloadLocationFromCore({
          'directory': '/Volumes/Work/收件',
          'defaultDirectory': '/Users/me/Downloads/flare',
          'customDirectory': '/Volumes/Work/收件',
          'isCustom': true,
          'subfolder': 'flare',
        }),
        const DownloadLocation(
          directory: '/Volumes/Work/收件',
          defaultDirectory: '/Users/me/Downloads/flare',
          isCustom: true,
        ),
      );
      expect(
        savedMediaFileFromCore({
          'path': '/Users/me/Downloads/flare/IMG_1.jpg',
          'directory': '/Users/me/Downloads/flare',
          'fileName': 'IMG_1.jpg',
          'sizeBytes': 2048,
          'fromCache': true,
          'downloadKey': 'img-1',
        }),
        const SavedMediaFile(
          path: '/Users/me/Downloads/flare/IMG_1.jpg',
          directory: '/Users/me/Downloads/flare',
          fileName: 'IMG_1.jpg',
          sizeBytes: 2048,
          fromCache: true,
        ),
      );
      expect(
        pictureAccessFromCore({'source': 'local', 'localPath': '/c/1.jpg'}),
        const PictureAccess(localPath: '/c/1.jpg'),
      );
      expect(
        pictureAccessFromCore({
          'source': 'remote',
          'remote': {'url': 'https://cdn.example/1?sig'},
        }),
        const PictureAccess(url: 'https://cdn.example/1?sig'),
      );
      expect(
        mediaCacheBytesFromCore({'total_bytes': 2726297, 'entry_count': 5}),
        2726297,
      );
      expect(mediaCacheBytesFromCore({}), isNull);
    });

    test('folders read short: home as ~, long paths keep the last two', () {
      expect(
        shortDownloadLocation('/Users/me/Downloads/flare', home: '/Users/me'),
        '~/Downloads/flare',
      );
      // The macOS sandbox container's Downloads is the user's Downloads.
      expect(
        shortDownloadLocation(
          '/Users/me/Library/Containers/com.flare.im/Data/Downloads/flare',
          home: '/Users/me/Library/Containers/com.flare.im/Data',
        ),
        '~/Downloads/flare',
      );
      expect(
        shortDownloadLocation('/Volumes/Work/Projects/2026/收件', home: ''),
        '…/2026/收件',
      );
      expect(
        shortDownloadLocation('/storage/emulated/0/Download/flare', home: ''),
        '…/Download/flare',
      );
    });
  });
}

class _FakeMediaRepository implements IMediaRepository {
  final Map<String, PictureAccess> pictures = {};
  final List<String> resolved = [];
  final List<MediaSaveTarget> saved = [];
  Future<void>? gate;
  bool failResolve = false;
  bool failCache = false;
  int? cacheBytes;

  @override
  Future<PictureAccess> resolvePicture(String fileId) async {
    resolved.add(fileId);
    if (gate != null) await gate;
    if (failResolve) throw StateError('sdk not ready');
    return pictures[fileId] ?? const PictureAccess();
  }

  @override
  Future<SavedMediaFile> saveToDownloadLocation(MediaSaveTarget target) async {
    saved.add(target);
    return SavedMediaFile(
      path: '/Users/me/Downloads/flare/${target.fileName}.jpg',
      directory: '/Users/me/Downloads/flare',
      fileName: '${target.fileName}.jpg',
    );
  }

  @override
  Future<int?> mediaCacheBytes() async {
    if (failCache) throw StateError('sdk not ready');
    return cacheBytes;
  }

  @override
  Future<void> clearMediaCache() async {}

  @override
  Future<DownloadLocation> getDownloadLocation() async =>
      const DownloadLocation(
        directory: '/Users/me/Downloads/flare',
        defaultDirectory: '/Users/me/Downloads/flare',
        isCustom: false,
      );

  @override
  Future<DownloadLocation> setDownloadLocation(String? directory) async =>
      getDownloadLocation();
}

final class _FakeFlareImClient implements core.FlareImClient {
  _FakeFlareImClient(this._media);

  final _RecordingMediaApi _media;

  @override
  core.MediaApi get media => _media;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _RecordingMediaApi implements core.MediaApi {
  final List<(String, Map<String, Object?>)> calls = [];

  @override
  Future<Map<String, Object?>> resolveMediaAccess(
    Map<String, Object?> request,
  ) async {
    calls.add(('resolveMediaAccess', request));
    return {'source': 'remote'};
  }

  @override
  Future<Map<String, Object?>> setUserDownloadDirectory(
    Map<String, Object?> request,
  ) async {
    calls.add(('setUserDownloadDirectory', request));
    return {'directory': '/d', 'defaultDirectory': '/d', 'isCustom': false};
  }

  @override
  Future<Map<String, Object?>> downloadToUserDirectory(
    Map<String, Object?> request,
  ) async {
    calls.add(('downloadToUserDirectory', request));
    return {'path': '/d/a.pdf', 'directory': '/d', 'fileName': 'a.pdf'};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
