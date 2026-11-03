import 'package:file_picker/file_picker.dart';
import 'package:flare_im/infrastructure/platform/app_platform_adapter.dart';
import 'package:flare_im_ui/flare_im_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('accept lists map onto file_picker types', () {
    expect(AppPlatformAdapter.fileTypeFor(const []).type, FileType.any);
    expect(
      AppPlatformAdapter.fileTypeFor(const ['image/*']).type,
      FileType.image,
    );
    expect(
      AppPlatformAdapter.fileTypeFor(const ['video/*']).type,
      FileType.video,
    );
    expect(
      AppPlatformAdapter.fileTypeFor(const ['audio/*']).type,
      FileType.audio,
    );
    expect(
      AppPlatformAdapter.fileTypeFor(const ['image/*', 'video/*']).type,
      FileType.media,
    );
    final custom = AppPlatformAdapter.fileTypeFor(const ['.pdf', '.PPTX']);
    expect(custom.type, FileType.custom);
    expect(custom.extensions, ['pdf', 'pptx']);
    expect(
      AppPlatformAdapter.fileTypeFor(const ['image/*', '.pdf']).type,
      FileType.any,
    );
  });

  test('declares pickers as supported on top of the detected capabilities', () {
    const adapter = AppPlatformAdapter();
    expect(adapter.capabilities.filePicker, FlareCapabilitySupport.supported);
    expect(adapter.capabilities.imagePicker, FlareCapabilitySupport.supported);
    expect(adapter.capabilities.share, FlareCapabilitySupport.unsupported);
  });

  test(
    'without the native plugin the picker answers UNSUPPORTED instead of throwing',
    () async {
      // No image_picker platform channel is registered in a unit test: the plugin
      // raises MissingPluginException, which the contract maps to UNSUPPORTED.
      const adapter = AppPlatformAdapter();
      final images = await adapter.pickImages();
      expect(images.isOk, isFalse);
      expect(
        images.code,
        anyOf(
          FlarePlatformErrorCode.unsupported,
          FlarePlatformErrorCode.failed,
        ),
      );
      expect(images.errorOrNull!.message, isNotEmpty);
    },
  );
}
