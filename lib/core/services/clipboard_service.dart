// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/services.dart';

/// Copies sensitive values to the clipboard and clears them automatically.
///
/// A new copy cancels the previous timer. Before clearing, the service reads
/// the clipboard and only wipes it when the content is still the value this
/// service copied — avoiding accidental deletion of unrelated user content.
class ClipboardService {
  final int Function() _clearSeconds;
  Timer? _clearTimer;
  String? _lastCopied;

  ClipboardService({required int Function() clearSeconds})
    : _clearSeconds = clearSeconds;

  /// Currently configured auto-clear duration in seconds (0 = never).
  int get clearSeconds => _clearSeconds();

  /// Copies [text] and schedules a clear after [clearAfter] (defaults to the
  /// configured preference). A value of zero disables automatic clearing.
  Future<void> copy(String text, {Duration? clearAfter}) async {
    await Clipboard.setData(ClipboardData(text: text));
    _lastCopied = text;
    _clearTimer?.cancel();
    _clearTimer = null;

    final seconds = clearAfter?.inSeconds ?? _clearSeconds();
    if (seconds <= 0) return;

    _clearTimer = Timer(Duration(seconds: seconds), () async {
      try {
        final current = await Clipboard.getData(Clipboard.kTextPlain);
        if (current?.text == _lastCopied) {
          await Clipboard.setData(const ClipboardData(text: ''));
          _lastCopied = null;
        }
      } catch (_) {
        // Clipboard access can fail when the app is backgrounded. Nothing to
        // do here; the next copy resets the state.
      }
    });
  }

  void dispose() {
    _clearTimer?.cancel();
    _clearTimer = null;
    _lastCopied = null;
  }
}
