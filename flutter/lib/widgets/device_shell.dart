import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tito_colors.dart';

class DeviceShell extends StatelessWidget {
  const DeviceShell({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: ColoredBox(
        color: TitoColors.deepBlue,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B2940),
                    borderRadius: BorderRadius.circular(TitoRadii.xl),
                    border: Border.all(color: TitoColors.ink, width: 4),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x4D18283B),
                        blurRadius: 24,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(TitoRadii.xl - 4),
                    child: Column(
                      children: [
                        _StatusStrip(),
                        Expanded(child: child),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF152033),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'TitoDex',
            style: TextStyle(
              color: TitoColors.card,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          Row(
            children: [
              Icon(Icons.wifi, size: 14, color: TitoColors.skyBlue),
              SizedBox(width: 6),
              Icon(Icons.battery_full, size: 14, color: TitoColors.mint),
            ],
          ),
        ],
      ),
    );
  }
}
