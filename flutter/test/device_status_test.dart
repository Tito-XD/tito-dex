import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/services/device_status_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:battery_plus/battery_plus.dart';

void main() {
  test('DeviceStatusSnapshot reports wifi connectivity', () {
    const snapshot = DeviceStatusSnapshot(
      batteryLevel: 72,
      batteryState: BatteryState.discharging,
      connectivity: [ConnectivityResult.wifi],
    );

    expect(snapshot.onWifi, isTrue);
    expect(snapshot.isOnline, isTrue);
    expect(snapshot.isCharging, isFalse);
  });

  test('DeviceStatusSnapshot reports charging state', () {
    const snapshot = DeviceStatusSnapshot(
      batteryLevel: 100,
      batteryState: BatteryState.charging,
      connectivity: [ConnectivityResult.mobile],
    );

    expect(snapshot.onMobile, isTrue);
    expect(snapshot.isCharging, isTrue);
  });
}
