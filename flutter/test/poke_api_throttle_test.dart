import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/poke_api_throttle.dart';

void main() {
  test('pokeApiStatusShouldRetry covers rate limits and server errors', () {
    expect(pokeApiStatusShouldRetry(429), isTrue);
    expect(pokeApiStatusShouldRetry(500), isTrue);
    expect(pokeApiStatusShouldRetry(404), isFalse);
    expect(pokeApiStatusShouldRetry(200), isFalse);
  });

  test('pokeApiRetryDelay grows with attempt count', () {
    expect(
      pokeApiRetryDelay(0).inMilliseconds,
      lessThan(pokeApiRetryDelay(2).inMilliseconds),
    );
  });

  test('PokeApiThrottle limits concurrent work', () async {
    final throttle = PokeApiThrottle(maxConcurrent: 2);
    var active = 0;
    var maxActive = 0;

    Future<void> task() async {
      active++;
      maxActive = maxActive < active ? active : maxActive;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      active--;
    }

    await Future.wait([
      for (var i = 0; i < 6; i++) throttle.run(task),
    ]);

    expect(maxActive, lessThanOrEqualTo(2));
  });
}
