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
                padding: const EdgeInsets.all(8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: TitoColors.slateBlue,
                    borderRadius: BorderRadius.circular(TitoRadii.xl),
                    border: Border.all(color: TitoColors.ink, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x4D18283B),
                        blurRadius: 24,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(TitoRadii.xl - 3),
                    child: Column(
                      children: [
                        const _StatusStrip(),
                        Expanded(
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  TitoColors.skyBlue,
                                  TitoColors.slateBlue,
                                ],
                              ),
                            ),
                            child: child,
                          ),
                        ),
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
  const _StatusStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: TitoColors.deepBlue,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'TitoDex',
            style: TextStyle(
              color: TitoColors.skyBlue,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          Row(
            children: [
              _StatusDot(),
              SizedBox(width: 6),
              _BatteryIcon(),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: TitoColors.softYellow,
        shape: BoxShape.circle,
        border: Border.all(color: TitoColors.skyBlue, width: 1),
      ),
    );
  }
}

class _BatteryIcon extends StatelessWidget {
  const _BatteryIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 10,
      decoration: BoxDecoration(
        border: Border.all(color: TitoColors.skyBlue, width: 2),
        borderRadius: BorderRadius.circular(2),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.all(1),
      child: Container(
        width: 11,
        decoration: BoxDecoration(
          color: TitoColors.mint,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}
