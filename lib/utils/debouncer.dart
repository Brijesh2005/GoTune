import 'dart:async';
import 'package:flutter/foundation.dart';

/// A lightweight utility to debounce rapid sequential events,
/// such as user typing in a search bar.
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 400)});

  /// Runs [action] after [delay] unless cancelled or re-invoked.
  void run(VoidCallback action) {
    cancel();
    _timer = Timer(delay, action);
  }

  /// Cancels any active pending timer.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Disposes the debouncer instance.
  void dispose() {
    cancel();
  }
}
