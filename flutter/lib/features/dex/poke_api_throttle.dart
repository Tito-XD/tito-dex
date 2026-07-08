import 'dart:async';
import 'dart:math';

/// Limits concurrent outbound PokeAPI requests to avoid 429 rate limits.
class PokeApiThrottle {
  PokeApiThrottle({this.maxConcurrent = 3}) : _semaphore = _Semaphore(maxConcurrent);

  final int maxConcurrent;
  final _Semaphore _semaphore;

  Future<T> run<T>(Future<T> Function() action) => _semaphore.run(action);
}

class _Semaphore {
  _Semaphore(this._max);

  final int _max;
  int _active = 0;
  final _waiters = <Completer<void>>[];

  Future<T> run<T>(Future<T> Function() action) async {
    await _acquire();
    try {
      return await action();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() async {
    if (_active < _max) {
      _active++;
      return;
    }
    final waiter = Completer<void>();
    _waiters.add(waiter);
    await waiter.future;
    _active++;
  }

  void _release() {
    _active--;
    if (_waiters.isEmpty) {
      return;
    }
    _waiters.removeAt(0).complete();
  }
}

bool pokeApiStatusShouldRetry(int statusCode) {
  return statusCode == 429 || statusCode == 408 || statusCode >= 500;
}

Duration pokeApiRetryDelay(int attempt) {
  final baseMs = 400 * pow(2, attempt).toInt();
  return Duration(milliseconds: min(baseMs, 8000));
}
