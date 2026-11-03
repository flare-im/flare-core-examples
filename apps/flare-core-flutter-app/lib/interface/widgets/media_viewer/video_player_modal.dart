import 'dart:async';
import 'dart:io';

import 'package:flare_im/infrastructure/media/network_image_policy.dart';
import 'package:flare_im_ui/flare_im_ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Platform decoding only; player chrome and controls belong to the kit.
class VideoPlayerModal {
  VideoPlayerModal._();

  /// The kit player draws its download key (top right) only with
  /// [onDownload].
  static Future<void> show(
    BuildContext context, {
    required String videoUrl,
    String? posterUrl,
    bool audioOnly = false,
    VoidCallback? onDownload,
    VideoPlayerController Function(String)? controllerFactory,
  }) => ui.FlareVideoPlayer.present(
    context,
    videoSrc: videoUrl,
    poster: posterUrl,
    title: audioOnly ? '语音' : '视频',
    onDownload: onDownload,
    playerBuilder: (_, source) => _PlatformPlayer(
      source: source,
      audioOnly: audioOnly,
      controllerFactory: controllerFactory,
    ),
  );
}

class _PlatformPlayer extends StatefulWidget {
  const _PlatformPlayer({
    required this.source,
    required this.audioOnly,
    this.controllerFactory,
  });

  final String source;
  final bool audioOnly;
  final VideoPlayerController Function(String)? controllerFactory;

  @override
  State<_PlatformPlayer> createState() => _PlatformPlayerState();
}

class _PlatformPlayerState extends State<_PlatformPlayer> {
  VideoPlayerController? _controller;
  String? _error;
  int _generation = 0;
  static const _loadTimeout = Duration(seconds: 20);

  Future<void> _release(VideoPlayerController? controller) async {
    if (controller == null) return;
    controller.removeListener(_changed);
    try {
      await controller.dispose().timeout(const Duration(seconds: 5));
    } catch (_) {
      // A platform teardown failure must not strand retry or escape disposal.
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final old = _controller;
    _controller = null;
    await _release(old);
    if (!mounted || generation != _generation) return;
    setState(() => _error = null);
    final source = widget.source.trim();
    if (!isHttpOrHttpsUrl(source) && !isLocalFileLikePath(source)) {
      setState(() => _error = '无效媒体地址');
      return;
    }
    try {
      final controller =
          widget.controllerFactory?.call(source) ??
          (isLocalFileLikePath(source)
              ? VideoPlayerController.file(
                  File(
                    source.startsWith('file:')
                        ? Uri.parse(source).toFilePath()
                        : source,
                  ),
                )
              : VideoPlayerController.networkUrl(Uri.parse(source)));
      _controller = controller;
      controller.addListener(_changed);
      await controller.initialize().timeout(_loadTimeout);
      if (!mounted || generation != _generation) return;
      await controller.setLooping(false).timeout(_loadTimeout);
      if (!mounted || generation != _generation) return;
      _changed();
    } catch (_) {
      if (mounted && generation == _generation) {
        final failed = _controller;
        _controller = null;
        unawaited(_release(failed));
        setState(() => _error = '无法播放此媒体');
      }
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _command(
    Future<void> Function(VideoPlayerController) action,
  ) async {
    final controller = _controller;
    final generation = _generation;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      await action(controller).timeout(_loadTimeout);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = '播放操作失败');
      }
    }
  }

  void _toggle() => _command((controller) async {
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      if (controller.value.position >= controller.value.duration) {
        await controller.seekTo(Duration.zero);
      }
      await controller.play();
    }
  });

  void _seek(double ratio) => _command(
    (controller) => controller.seekTo(
      Duration(
        milliseconds:
            (controller.value.duration.inMilliseconds * ratio.clamp(0, 1))
                .round(),
      ),
    ),
  );

  @override
  void dispose() {
    _generation++;
    unawaited(_release(_controller));
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final value = controller?.value;
    final failed = _error != null || value?.hasError == true;
    final ready = !failed && value?.isInitialized == true;
    return ui.FlareTheme(
      colors: ui.FlareColors.dark,
      child: SafeArea(
        minimum: const EdgeInsets.all(ui.FlareSizes.spacingLg),
        child: !ready
            ? ui.FlareEmptyState(
                title: failed ? (_error ?? '无法播放此媒体') : '正在加载',
                loading: !failed,
                tone: failed
                    ? ui.FlareEmptyStateTone.error
                    : ui.FlareEmptyStateTone.normal,
                actionText: failed ? '重试' : null,
                onAction: failed ? _load : null,
              )
            : widget.audioOnly
            ? ui.FlareVoicePlayer(
                durationLabel: _time(value!.duration),
                elapsedLabel: _time(value.position),
                progress: _progress(value),
                playing: value.isPlaying,
                speed: value.playbackSpeed,
                onToggle: _toggle,
                onSeek: _seek,
                onCycleSpeed: () => _command(
                  (c) => c.setPlaybackSpeed(
                    c.value.playbackSpeed >= 2
                        ? 1
                        : c.value.playbackSpeed + 0.5,
                  ),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: value!.aspectRatio,
                        child: VideoPlayer(controller!),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      ui.FlareIconButton(
                        icon: value.isPlaying ? 'pause' : 'play',
                        semanticLabel: value.isPlaying ? '暂停' : '播放',
                        onPressed: _toggle,
                      ),
                      Expanded(
                        child: ui.FlareSlider(
                          value: _progress(value),
                          max: 1,
                          step: 0,
                          onChanged: _seek,
                        ),
                      ),
                      ui.FlareIconButton(
                        icon: value.volume == 0 ? 'speaker-off' : 'speaker',
                        semanticLabel: value.volume == 0 ? '取消静音' : '静音',
                        onPressed: () => _command(
                          (c) => c.setVolume(c.value.volume == 0 ? 1 : 0),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  static double _progress(VideoPlayerValue value) =>
      value.duration.inMilliseconds > 0
      ? (value.position.inMilliseconds / value.duration.inMilliseconds).clamp(
          0,
          1,
        )
      : 0;

  static String _time(Duration duration) =>
      '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
}
