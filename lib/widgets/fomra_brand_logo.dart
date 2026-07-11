import 'package:flutter/material.dart';

/// FOMRA Housing & Infrastructure corporate logo for nav and auth surfaces.
class FomraBrandLogo extends StatelessWidget {
  final bool compact;
  final double? height;
  final bool showBackground;

  const FomraBrandLogo({
    super.key,
    this.compact = false,
    this.height,
    this.showBackground = true,
  });

  static const _assetPath = 'assets/images/fomra_logo.png';

  @override
  Widget build(BuildContext context) {
    final h = height ?? (compact ? 48.0 : 52.0);

    final logo = Image.asset(
      _assetPath,
      fit: BoxFit.contain,
      alignment: compact ? Alignment.center : Alignment.centerLeft,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => _VectorFallback(
        compact: compact,
        lightOnDark: !showBackground,
      ),
    );

    if (!showBackground) {
      return SizedBox(
        height: h,
        width: double.infinity,
        child: Align(
          alignment: compact ? Alignment.center : Alignment.centerLeft,
          child: logo,
        ),
      );
    }

    return Container(
      height: h,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: compact ? Alignment.center : Alignment.centerLeft,
      child: logo,
    );
  }
}

class _VectorFallback extends StatelessWidget {
  final bool compact;
  final bool lightOnDark;

  const _VectorFallback({
    required this.compact,
    this.lightOnDark = false,
  });

  Color get _ink => lightOnDark ? Colors.white : const Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return CustomPaint(
        size: const Size(28, 24),
        painter: _SwooshPainter(),
      );
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'FOMRA',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                  letterSpacing: -0.5,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              CustomPaint(
                size: const Size(36, 32),
                painter: _SwooshPainter(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'HOUSING & INFRASTRUCTURE PVT. LTD.',
            style: TextStyle(
              fontSize: 7.5,
              fontWeight: FontWeight.w700,
              color: _ink.withValues(alpha: 0.85),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwooshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [Color(0xFF0E1E52), Color(0xFF2E6BD6)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final blade = Path()
      ..moveTo(w * 0.04, h * 0.70)
      ..quadraticBezierTo(w * 0.56, h * 0.50, w * 1.00, h * 0.02)
      ..quadraticBezierTo(w * 1.00, h * 0.18, w * 0.98, h * 0.30)
      ..quadraticBezierTo(w * 0.54, h * 0.66, w * 0.04, h * 0.70)
      ..close();
    canvas.drawPath(blade, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
