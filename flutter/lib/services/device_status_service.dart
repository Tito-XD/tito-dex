import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Live device battery and network status for handheld status icons.
class DeviceStatusSnapshot {
  const DeviceStatusSnapshot({
    this.batteryLevel,
    this.batteryState = BatteryState.unknown,
    this.connectivity = const [],
  });

  final int? batteryLevel;
  final BatteryState batteryState;
  final List<ConnectivityResult> connectivity;

  bool get onWifi => connectivity.contains(ConnectivityResult.wifi);

  bool get onMobile => connectivity.contains(ConnectivityResult.mobile);

  bool get isOnline =>
      onWifi ||
      onMobile ||
      connectivity.contains(ConnectivityResult.ethernet) ||
      connectivity.contains(ConnectivityResult.vpn);

  bool get isCharging =>
      batteryState == BatteryState.charging ||
      batteryState == BatteryState.full;
}

class DeviceStatusService {
  DeviceStatusService({
    Battery? battery,
    Connectivity? connectivity,
  })  : _battery = battery ?? Battery(),
        _connectivity = connectivity ?? Connectivity();

  final Battery _battery;
  final Connectivity _connectivity;

  Future<DeviceStatusSnapshot> read() async {
    if (kIsWeb) {
      return const DeviceStatusSnapshot();
    }

    try {
      final results = await _connectivity.checkConnectivity();
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      return DeviceStatusSnapshot(
        batteryLevel: level,
        batteryState: state,
        connectivity: results,
      );
    } catch (_) {
      return const DeviceStatusSnapshot();
    }
  }

  Stream<DeviceStatusSnapshot> watch() async* {
    if (kIsWeb) {
      yield const DeviceStatusSnapshot();
      return;
    }

    yield await read();

    final controller = StreamController<DeviceStatusSnapshot>();
    StreamSubscription<BatteryState>? batterySub;
    StreamSubscription<List<ConnectivityResult>>? connectivitySub;

    Future<void> push() async {
      if (controller.isClosed) {
        return;
      }
      controller.add(await read());
    }

    batterySub = _battery.onBatteryStateChanged.listen((_) => push());
    connectivitySub = _connectivity.onConnectivityChanged.listen((_) => push());

    controller.onCancel = () async {
      await batterySub?.cancel();
      await connectivitySub?.cancel();
    };

    yield* controller.stream;
  }
}

final deviceStatusService = DeviceStatusService();
