import 'package:flare_im/domain/entities/message.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/domain/value_objects/media_storage.dart';
import 'package:flare_im/domain/value_objects/message_content.dart';
import 'package:flare_im/infrastructure/mappers/sdk_message_content_mapper.dart';
import 'package:flare_im/interface/widgets/message/message_media_save.dart';
import 'package:flare_im/shared/i18n/flare_locale.dart';
import 'package:flare_im/shared/i18n/flare_messages.dart';
import 'package:flutter_test/flutter_test.dart';

// 保存到本机：一条消息交给核心的是什么。优先核心里存的 id（看过的图直接从本地缓存拷出），
// 名字用发送方给的文件名或 IMG_ / VID_ 时间戳（核心按类型补扩展名）。

final _now = DateTime(2026, 9, 27, 9, 5, 7);

void main() {
  group('mediaSaveTargetFor', () {
    test('a file saves by its stored id under the sender\'s name', () {
      final target = mediaSaveTargetFor(
        const FileContent(
          url: 'https://cdn.example/f-1?sig=1',
          fileId: 'f-1',
          filename: '需求稿.pdf',
        ),
        now: _now,
      );
      expect(target, const MediaSaveTarget(fileName: '需求稿.pdf', fileId: 'f-1'));
    });

    test('pictures and videos get a timestamped name, no extension', () {
      expect(
        mediaSaveTargetFor(
          const ImageContent(url: 'https://cdn.example/p.jpg', fileId: 'img-1'),
          now: _now,
        ),
        const MediaSaveTarget(fileName: 'IMG_20260927_090507', fileId: 'img-1'),
      );
      expect(
        mediaSaveTargetFor(
          const VideoContent(url: 'https://cdn.example/v.mp4', fileId: 'vid-1'),
          now: _now,
        ),
        const MediaSaveTarget(fileName: 'VID_20260927_090507', fileId: 'vid-1'),
      );
    });

    test('without a stored id: the web address, else — for the signed-in '
        'user\'s own message — the file on this device', () {
      expect(
        mediaSaveTargetFor(
          const FileContent(
            url: 'https://cdn.example/a.zip',
            filename: 'a.zip',
          ),
          now: _now,
        ),
        const MediaSaveTarget(
          fileName: 'a.zip',
          sourceUrl: 'https://cdn.example/a.zip',
        ),
      );
      // Still uploading: the core keeps the local path where the id goes.
      expect(
        mediaSaveTargetFor(
          const ImageContent(url: '', localPath: '/Users/me/Pictures/a.png'),
          now: _now,
          ownMessage: true,
        ),
        const MediaSaveTarget(
          fileName: 'IMG_20260927_090507',
          sourcePath: '/Users/me/Pictures/a.png',
        ),
      );
      expect(
        mediaSaveTargetFor(
          const FileContent(
            url: 'file:///Users/me/My%20Doc.txt',
            filename: 'My Doc.txt',
          ),
          now: _now,
          ownMessage: true,
        ),
        const MediaSaveTarget(
          fileName: 'My Doc.txt',
          sourcePath: '/Users/me/My Doc.txt',
        ),
      );
    });

    test('nothing to save: no id and no usable address, or not media', () {
      expect(
        mediaSaveTargetFor(const ImageContent(url: 'data:image/png;base64,AA')),
        isNull,
      );
      expect(mediaSaveTargetFor(const TextContent('hi')), isNull);
      expect(
        mediaSaveTargetFor(const StickerContent(stickerId: 's1', url: 'x')),
        isNull,
      );
      expect(
        mediaSaveTargetFor(const AudioContent(url: 'https://a/b')),
        isNull,
      );
    });

    test('someone else\'s message never names a file on this device as the '
        'source', () {
      // A path in someone else's message is text they chose: saving it would
      // copy one of this device's files (the SDK database) into Downloads.
      const paths = [
        'file:///Users/me/Library/Application%20Support/flare/flare.db',
        '/Users/me/Library/Application Support/flare/flare.db',
        r'C:\Users\me\AppData\flare\flare.db',
      ];
      for (final path in paths) {
        final contents = <MessageContent>[
          FileContent(url: path, filename: 'flare.db'),
          FileContent(url: '', localPath: path, filename: 'flare.db'),
          ImageContent(url: path),
          ImageContent(url: '', localPath: path),
          VideoContent(url: path),
        ];
        for (final content in contents) {
          expect(
            mediaSaveTargetFor(content, now: _now),
            isNull,
            reason: '$content',
          );
          expect(
            messageMediaSavable(
              _message(content, sender: 'mallory'),
              currentUserId: 'me',
            ),
            isFalse,
            reason: '$content',
          );
        }
        // With a stored id it saves by the id only, never by the path.
        final byId = mediaSaveTargetFor(
          FileContent(url: path, fileId: 'f-9', filename: 'flare.db'),
          now: _now,
        );
        expect(
          byId,
          const MediaSaveTarget(fileName: 'flare.db', fileId: 'f-9'),
        );
        expect(byId!.sourcePath, isNull);
      }
      // A web address in someone else's message is still savable.
      expect(
        messageMediaSavable(
          _message(
            const FileContent(url: 'https://cdn.example/a.pdf', filename: 'a'),
            sender: 'mallory',
          ),
          currentUserId: 'me',
        ),
        isTrue,
      );
      // No signed-in user: nothing counts as one's own.
      expect(
        messageMediaSavable(
          _message(
            const FileContent(url: '/Users/me/a.txt', filename: 'a.txt'),
            sender: '',
          ),
          currentUserId: '',
        ),
        isFalse,
      );
    });

    test('the signed-in user\'s own uploading message saves from its file', () {
      expect(
        messageMediaSavable(
          _message(
            const FileContent(
              url: '/Users/me/Desktop/a.txt',
              filename: 'a.txt',
            ),
            sender: 'me',
          ),
          currentUserId: 'me',
        ),
        isTrue,
      );
    });

    test('a recalled message is not savable', () {
      const content = FileContent(url: '', fileId: 'f-1', filename: 'a.txt');
      expect(
        messageMediaSavable(_message(content), currentUserId: 'me'),
        isTrue,
      );
      expect(
        messageMediaSavable(
          _message(content, recalled: true),
          currentUserId: 'me',
        ),
        isFalse,
      );
    });
  });

  group('SdkMessageContentMapper keeps the stored media id', () {
    test('image, video and file carry their core ids', () {
      final image = SdkMessageContentMapper.fromMap({
        'contentType': 'image',
        'source': {'imageId': 'img-1', 'url': 'https://cdn.example/p.jpg'},
      }, const {});
      expect((image as ImageContent).fileId, 'img-1');

      final video = SdkMessageContentMapper.fromMap({
        'contentType': 'video',
        'videoId': 'vid-1',
        'source': {'url': 'https://cdn.example/v.mp4'},
      }, const {});
      expect((video as VideoContent).fileId, 'vid-1');

      final file = SdkMessageContentMapper.fromMap({
        'contentType': 'file',
        'fileId': 'f-1',
        'fileName': 'a.pdf',
      }, const {});
      expect((file as FileContent).fileId, 'f-1');
    });

    test('a local path, data: or address in the id slot is not an id', () {
      for (final raw in [
        '/Users/me/a.png',
        'file:///Users/me/a.png',
        'data:image/png;base64,AA',
        'https://cdn.example/a.png',
        r'C:\Users\me\a.png',
      ]) {
        final image = SdkMessageContentMapper.fromMap({
          'contentType': 'image',
          'source': {'imageId': raw},
        }, const {});
        expect((image as ImageContent).fileId, isNull, reason: raw);
      }
      final file = SdkMessageContentMapper.fromMap({
        'contentType': 'file',
        'url': 'https://cdn.example/a.pdf',
        'fileName': 'a.pdf',
      }, const {});
      expect((file as FileContent).fileId, isNull);
    });
  });

  test('an unwritable folder says so; other failures say it was not saved', () {
    final zh = FlareMessages.of(FlareLocale.zhCn);
    expect(
      mediaSaveFailureText(
        StateError('download directory is not writable: denied'),
        zh,
      ),
      '这个文件夹不能写入，请换一个',
    );
    expect(mediaSaveFailureText(StateError('timeout'), zh), '没有保存成功，请重试');
    final en = FlareMessages.of(FlareLocale.enUs);
    expect(en.chat.savedTo('~/Downloads/flare'), 'Saved to ~/Downloads/flare');
    expect(zh.chat.savedTo('~/Downloads/flare'), '已保存到 ~/Downloads/flare');
  });
}

Message _message(
  MessageContent content, {
  bool recalled = false,
  String sender = 'u2',
}) => Message(
  serverId: 's1',
  clientMsgId: 'c1',
  conversationId: 'conv',
  senderId: sender,
  seq: 1,
  timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
  clientTimestamp: DateTime.fromMillisecondsSinceEpoch(1000),
  content: content,
  status: MessageStatus.sent,
  source: MessageSource.remote,
  senderName: '',
  senderAvatar: '',
  senderDisplayName: '',
  isRecalled: recalled,
);
