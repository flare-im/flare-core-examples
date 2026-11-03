import 'package:file_picker/file_picker.dart';
import 'package:flare_im_ui/flare_im_ui.dart';
import 'package:image_picker/image_picker.dart';

/// The Flutter host's implementation of the kit's platform contract: pickers
/// through image_picker / file_picker. A dismissed picker is CANCELLED, plugin
/// errors are normalized by the contract (a missing plugin → UNSUPPORTED).
class AppPlatformAdapter extends FlarePlatformAdapter {
  const AppPlatformAdapter({ImagePicker? imagePicker, FilePicker? filePicker})
    : _imagePicker = imagePicker,
      _filePicker = filePicker;

  final ImagePicker? _imagePicker;
  final FilePicker? _filePicker;

  ImagePicker get _images => _imagePicker ?? ImagePicker();
  FilePicker get _files => _filePicker ?? FilePicker.platform;

  @override
  FlarePlatformCapabilities get capabilities =>
      FlarePlatformCapabilities.detect().copyWith(
        filePicker: FlareCapabilitySupport.supported,
        imagePicker: FlareCapabilitySupport.supported,
      );

  /// file_picker's type for the contract's accept list: image/video/audio
  /// wildcards map to the typed pickers, both image and video to `media`,
  /// extensions to `custom`, anything else to `any`.
  static ({FileType type, List<String>? extensions}) fileTypeFor(
    List<String> accept,
  ) {
    final normalized = accept
        .map((entry) => entry.trim().toLowerCase())
        .where((entry) => entry.isNotEmpty)
        .toSet();
    final image = normalized.contains('image/*');
    final video = normalized.contains('video/*');
    final audio = normalized.contains('audio/*');
    final extensions = normalized
        .where((entry) => entry.startsWith('.'))
        .map((entry) => entry.substring(1))
        .toList();
    if (image && video && extensions.isEmpty) {
      return (type: FileType.media, extensions: null);
    }
    if (image && !video && !audio && extensions.isEmpty) {
      return (type: FileType.image, extensions: null);
    }
    if (video && !image && !audio && extensions.isEmpty) {
      return (type: FileType.video, extensions: null);
    }
    if (audio && !image && !video && extensions.isEmpty) {
      return (type: FileType.audio, extensions: null);
    }
    if (extensions.isNotEmpty && !image && !video && !audio) {
      return (type: FileType.custom, extensions: extensions);
    }
    return (type: FileType.any, extensions: null);
  }

  static FlarePickedFile _fromXFile(XFile file) => FlarePickedFile(
    name: file.name,
    mimeType: file.mimeType,
    path: file.path,
  );

  static FlarePickedFile _fromPlatformFile(PlatformFile file) =>
      FlarePickedFile(name: file.name, size: file.size, path: file.path);

  @override
  Future<FlarePlatformResult<List<FlarePickedFile>>> pickImages([
    FlarePickImagesOptions options = const FlarePickImagesOptions(),
  ]) {
    return callFlarePlatform(() async {
      final List<XFile> picked;
      if (options.multiple) {
        picked = options.video
            ? await _images.pickMultipleMedia()
            : await _images.pickMultiImage();
      } else {
        final one = options.video
            ? await _images.pickMedia()
            : await _images.pickImage(source: ImageSource.gallery);
        picked = one == null ? const [] : [one];
      }
      if (picked.isEmpty) {
        return FlarePlatformResult.failure(
          FlarePlatformErrorCode.cancelled,
          message: 'picker dismissed',
        );
      }
      return FlarePlatformResult.ok(
        picked.map(_fromXFile).toList(growable: false),
      );
    });
  }

  @override
  Future<FlarePlatformResult<List<FlarePickedFile>>> pickFiles([
    FlarePickFilesOptions options = const FlarePickFilesOptions(),
  ]) {
    return callFlarePlatform(() async {
      final spec = fileTypeFor(options.accept);
      final result = await _files.pickFiles(
        type: spec.type,
        allowedExtensions: spec.extensions,
        allowMultiple: options.multiple,
        withData: false,
      );
      final files =
          result?.files
              .where((file) => (file.path ?? '').trim().isNotEmpty)
              .toList() ??
          const [];
      if (files.isEmpty) {
        return FlarePlatformResult.failure(
          FlarePlatformErrorCode.cancelled,
          message: 'picker dismissed',
        );
      }
      return FlarePlatformResult.ok(
        files.map(_fromPlatformFile).toList(growable: false),
      );
    });
  }
}
