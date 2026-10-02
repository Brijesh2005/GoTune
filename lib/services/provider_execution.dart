import 'dart:async';

import 'package:flutter/foundation.dart';

/// Per-catalog reliability policy applied to every adapter call.
///
/// This is the GoTune analogue of the reference project's `raceFetch`
/// `AbortController` timeout: every outbound call has a hard deadline so a
/// hanging mirror can never stall a discovery request.
class ProviderExecutionPolicy {
  /// Hard deadline for a single adapter call.
  final Duration timeout;

  /// Maximum number of attempts (1 = no retry).
  final int maxAttempts;

  /// Delay before the first retry; doubled on each subsequent attempt.
  final Duration retryBackoff;

  const ProviderExecutionPolicy({
    this.timeout = const Duration(seconds: 6),
    this.maxAttempts = 2,
    this.retryBackoff = const Duration(milliseconds: 250),
  });

  /// Policy for broad fan-out discovery (search, trending, related).
  static const ProviderExecutionPolicy discovery = ProviderExecutionPolicy();

  /// Policy for latency-sensitive single-item lookups.
  static const ProviderExecutionPolicy detail = ProviderExecutionPolicy(
    timeout: Duration(seconds: 5),
    maxAttempts: 1,
  );

  /// Policy for source resolution on the playback critical path.
  static const ProviderExecutionPolicy playback = ProviderExecutionPolicy(
    timeout: Duration(seconds: 8),
    maxAttempts: 2,
    retryBackoff: Duration(milliseconds: 150),
  );
}

/// Mutable health snapshot for a single catalog provider.
class ProviderHealth {
  final String providerId;
  final String displayName;

  int successCount = 0;
  int failureCount = 0;
  int timeoutCount = 0;
  int emptyCount = 0;
  int retryCount = 0;
  DateTime? lastSuccessAt;
  DateTime? lastFailureAt;
  String? lastError;

  ProviderHealth({required this.providerId, required this.displayName});

  int get totalCalls => successCount + failureCount + emptyCount;

  /// Share of calls that returned usable data, in `[0, 1]`.
  double get successRate {
    final total = successCount + failureCount + emptyCount;
    if (total == 0) return 0;
    return (successCount / total).clamp(0.0, 1.0);
  }

  /// True when the provider recently failed in a way that will not resolve
  /// itself, letting the aggregator skip it for a cool-down window.
  bool get isDegraded => totalCalls >= 3 && successRate < 0.34;

  void reset() {
    successCount = 0;
    failureCount = 0;
    timeoutCount = 0;
    emptyCount = 0;
    retryCount = 0;
    lastError = null;
  }
}

/// Centralized, observable record of every catalog interaction.
///
/// The reference project logs each source failure with `console.warn`; GoTune
/// aggregates those warnings into per-provider health so a single failing
/// catalog is visible to the user in Settings → Catalog provider health
/// instead of silently degrading the whole app.
///
/// Extends [ChangeNotifier] so diagnostics UI can rebuild without polling.
class MusicDiagnostics extends ChangeNotifier {
  MusicDiagnostics._internal() {
    _instance = this;
  }

  static MusicDiagnostics? _instance;

  /// Process-wide diagnostics registry.
  static MusicDiagnostics get instance => _instance ??= MusicDiagnostics._internal();

  final Map<String, ProviderHealth> _health = <String, ProviderHealth>{};

  /// Number of individual provider calls recovered by a retry.
  int totalRecoveredByRetry = 0;

  /// Number of discovery calls served from a stale cache entry because every
  /// provider failed.
  int totalStaleCacheServes = 0;

  ProviderHealth healthFor(String providerId, String displayName) {
    return _health.putIfAbsent(
      providerId,
      () => ProviderHealth(providerId: providerId, displayName: displayName),
    );
  }

  List<ProviderHealth> get allHealth => _health.values.toList(growable: false);

  void _recordSuccess(String providerId, String displayName) {
    final health = healthFor(providerId, displayName);
    health.successCount++;
    health.lastSuccessAt = DateTime.now();
    notifyListeners();
  }

  void _recordEmpty(String providerId, String displayName) {
    final health = healthFor(providerId, displayName);
    health.emptyCount++;
    health.lastSuccessAt = DateTime.now();
    notifyListeners();
  }

  void _recordFailure(String providerId, String displayName, Object error, {required bool timedOut}) {
    final health = healthFor(providerId, displayName);
    health.failureCount++;
    health.lastFailureAt = DateTime.now();
    health.lastError = _describe(error);
    if (timedOut) health.timeoutCount++;
    debugPrint('[MusicDiagnostics] $providerId failed: ${health.lastError}');
    notifyListeners();
  }

  void _recordRetry(String providerId, String displayName) {
    healthFor(providerId, displayName).retryCount++;
    totalRecoveredByRetry++;
    notifyListeners();
  }

  static String _describe(Object error) {
    if (error is TimeoutException) return 'timeout';
    final text = error.toString();
    if (text.startsWith('Exception:')) return text.substring(11).trim();
    return text;
  }

  void clear() {
    for (final health in _health.values) {
      health.reset();
    }
    totalRecoveredByRetry = 0;
    totalStaleCacheServes = 0;
    notifyListeners();
  }
}

/// Executes catalog adapter calls under a [ProviderExecutionPolicy].
///
/// Guarantees, for every call routed through this invoker:
/// * a hard **timeout**,
/// * a bounded number of **retries** with backoff,
/// * **error isolation** — a failure is recorded and `null`/empty is returned,
///   never rethrown into the discovery pipeline,
/// * **logging** into [MusicDiagnostics].
class ProviderInvoker {
  final MusicDiagnostics diagnostics;

  ProviderInvoker({MusicDiagnostics? diagnostics})
      : diagnostics = diagnostics ?? MusicDiagnostics.instance;

  /// Runs [action] for [provider] under [policy].
  ///
  /// Returns `null` when every attempt failed or timed out.
  Future<T?> invoke<T>(
    String providerId,
    String displayName,
    Future<T> Function() action, {
    ProviderExecutionPolicy policy = ProviderExecutionPolicy.discovery,
  }) async {
    for (var attempt = 0; attempt < policy.maxAttempts; attempt++) {
      if (attempt > 0) {
        diagnostics._recordRetry(providerId, displayName);
        await Future<void>.delayed(policy.retryBackoff * attempt);
      }
      try {
        final result = await action().timeout(policy.timeout);
        diagnostics._recordSuccess(providerId, displayName);
        return result;
      } on TimeoutException catch (error) {
        diagnostics._recordFailure(providerId, displayName, error, timedOut: true);
      } catch (error) {
        diagnostics._recordFailure(providerId, displayName, error, timedOut: false);
      }
    }
    return null;
  }

  /// Runs [action] and normalizes the outcome to a list.
  ///
  /// An adapter that returns `null`, throws or times out contributes nothing to
  /// the merge instead of aborting it. An adapter returning an empty list is
  /// recorded as an empty result rather than a failure.
  Future<List<T>> invokeList<T>(
    String providerId,
    String displayName,
    Future<List<T>> Function() action, {
    ProviderExecutionPolicy policy = ProviderExecutionPolicy.discovery,
  }) async {
    for (var attempt = 0; attempt < policy.maxAttempts; attempt++) {
      if (attempt > 0) {
        diagnostics._recordRetry(providerId, displayName);
        await Future<void>.delayed(policy.retryBackoff * attempt);
      }
      try {
        final result = await action().timeout(policy.timeout);
        if (result.isEmpty) {
          diagnostics._recordEmpty(providerId, displayName);
        } else {
          diagnostics._recordSuccess(providerId, displayName);
        }
        return result;
      } on TimeoutException catch (error) {
        diagnostics._recordFailure(providerId, displayName, error, timedOut: true);
      } catch (error) {
        diagnostics._recordFailure(providerId, displayName, error, timedOut: false);
      }
    }
    return const [];
  }

  /// Sequentially tries each [action] until one returns a non-null, non-empty
  /// value — the ordered-fallback behaviour used for single-item lookups where
  /// a partial merge would be wrong.
  Future<T?> invokeFirstSuccessful<T>(
    String providerId,
    String displayName,
    Future<T?> Function() action, {
    ProviderExecutionPolicy policy = ProviderExecutionPolicy.detail,
    bool Function(T value)? isUsable,
  }) async {
    for (var attempt = 0; attempt < policy.maxAttempts; attempt++) {
      if (attempt > 0) {
        diagnostics._recordRetry(providerId, displayName);
        await Future<void>.delayed(policy.retryBackoff * attempt);
      }
      try {
        final result = await action().timeout(policy.timeout);
        if (result == null || (isUsable != null && !isUsable(result))) {
          diagnostics._recordEmpty(providerId, displayName);
          return null;
        }
        diagnostics._recordSuccess(providerId, displayName);
        return result;
      } on TimeoutException catch (error) {
        diagnostics._recordFailure(providerId, displayName, error, timedOut: true);
      } catch (error) {
        diagnostics._recordFailure(providerId, displayName, error, timedOut: false);
      }
    }
    return null;
  }
}
