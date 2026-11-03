import 'dart:async';

typedef DraftIdleSave = void Function(String text);

final class DraftIdleScheduler {
  DraftIdleScheduler({required this.delay, required this.onSave});

  final Duration delay;
  final DraftIdleSave onSave;

  Timer? _timer;
  String? _pendingText;

  void schedule(String text) {
    cancel();
    if (text.trim().isEmpty) return;
    _pendingText = text;
    _timer = Timer(delay, () {
      _timer = null;
      final pendingText = _pendingText;
      _pendingText = null;
      if (pendingText != null) {
        onSave(pendingText);
      }
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _pendingText = null;
  }

  void flush() {
    _timer?.cancel();
    _timer = null;
    final pendingText = _pendingText;
    _pendingText = null;
    if (pendingText == null || pendingText.trim().isEmpty) return;
    onSave(pendingText);
  }

  void dispose() {
    cancel();
  }
}
