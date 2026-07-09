import 'package:flutter/material.dart';

import '../services/device_status_service.dart';
import '../theme/device_layout.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';

/// Real Wi-Fi and battery indicators for RG / native handheld.
class HandheldStatusIcons extends StatelessWidget {
  const HandheldStatusIcons({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!DeviceLayout.isNativeTarget) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DeviceStatusSnapshot>(
      stream: deviceStatusService.watch(),
      builder: (context, snapshot) {
        final status = snapshot.data ?? const DeviceStatusSnapshot();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _WifiIcon(onWifi: status.onWifi, compact: compact),
            SizedBox(width: compact ? 4 : 6),
            _BatteryIndicator(
              level: status.batteryLevel,
              charging: status.isCharging,
              compact: compact,
            ),
          ],
        );
      },
    );
  }
}

class _WifiIcon extends StatelessWidget {
  const _WifiIcon({required this.onWifi, required this.compact});

  final bool onWifi;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Icon(
      onWifi ? Icons.wifi_rounded : Icons.wifi_off_rounded,
      size: DeviceLayout.statusIconSize(context, compact: compact),
      color: onWifi ? TitoColors.deepBlue : TitoColors.deepBlue.withValues(alpha: 0.45),
    );
  }
}

class _BatteryIndicator extends StatelessWidget {
  const _BatteryIndicator({
    required this.level,
    required this.charging,
    required this.compact,
  });

  final int? level;
  final bool charging;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final value = (level ?? 0).clamp(0, 100);
    final fillColor = switch (value) {
      < 20 => const Color(0xFFE85D5D),
      < 40 => TitoColors.coral,
      _ => charging ? TitoColors.mint : TitoColors.softYellow,
    };
    const borderColor = TitoColors.deepBlue;

    final bodyWidth = DeviceLayout.dim(context, compact ? 24.0 : 20.0);
    final bodyHeight = DeviceLayout.dim(context, compact ? 14.0 : 11.0);
    final fillWidth = bodyWidth * (value / 100);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: bodyWidth + 3,
          height: bodyHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: bodyWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor, width: 1.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: fillWidth.clamp(0, bodyWidth - 2),
                      height: bodyHeight - 3,
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: fillColor,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: bodyHeight * 0.28,
                child: Container(
                  width: 2,
                  height: bodyHeight * 0.44,
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              if (charging)
                Positioned.fill(
                  child: Icon(
                    Icons.bolt_rounded,
                    size: compact ? 9 : 10,
                    color: TitoColors.deepBlue,
                  ),
                ),
            ],
          ),
        ),
        if (level != null) ...[
          SizedBox(width: compact ? 2 : 3),
          Text(
            '$value%',
            style: TitoTypography.style(
              fontSize: compact ? 11 : 10,
              fontWeight: FontWeight.w800,
              color: TitoColors.deepBlue,
            ),
          ),
        ],
      ],
    );
  }
}
