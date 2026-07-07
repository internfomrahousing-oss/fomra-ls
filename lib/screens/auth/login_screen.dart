import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_input.dart';
import '../../theme/fomra_layout.dart';
import '../../theme/fomra_theme_context.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthService.instance.login(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException
            ? e.message
            : 'Invalid email or password. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = FomraLayout.isDesktop(context);

    return Scaffold(
      body: wide ? _buildSplitLayout(context) : _buildMobileLayout(context),
    );
  }

  Widget _buildSplitLayout(BuildContext context) {
    return Row(
      children: [
        // Left: white background — Fomra logo only, no text
        Expanded(
          flex: 5,
          child: ColoredBox(
            color: Colors.white,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Center(
                  child: Image.asset(
                    'assets/images/fomra_logo.png',
                    width: 380,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const FomraLogo(width: 380),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Right: blue panel with the sign-in form
        Expanded(
          flex: 4,
          child: Container(
            decoration: const BoxDecoration(gradient: AppColors.heroGradient),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _buildFormCard(context, showBranding: false),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final isDark = context.isDarkMode;
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [
                  AppColors.darkBackground,
                  Color(0xFF0F2447),
                  Color(0xFF152A52),
                ]
              : const [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(Icons.house_outlined,
                        color: Colors.white, size: 38),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'FomraLS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fomra Housing',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 36),
                  _buildFormCard(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard(BuildContext context, {bool showBranding = true}) {
    final isDark = context.isDarkMode;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? context.fomraSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.fomraBorder),
        boxShadow: isDark
            ? context.fomraCardShadow
            : AppColors.elevatedShadow,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!showBranding) ...[
              Text(
                'Sign in',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: context.fomraTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Use your Fomra Housing account',
                style: TextStyle(
                  fontSize: 14,
                  color: context.fomraTextSecondary,
                ),
              ),
              const SizedBox(height: 24),
            ],
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Email is required' : null,
              decoration: FomraInput.decoration(
                context: context,
                label: 'Email',
                icon: Icons.email_outlined,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _login(),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Password is required' : null,
              decoration: FomraInput.decoration(
                context: context,
                label: 'Password',
                icon: Icons.lock_outline,
              ).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: context.fomraTextSecondary,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.error),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppColors.coloredShadow(AppColors.primary),
                ),
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vector recreation of the FOMRA Housing & Infrastructure logo.
/// Used as a fallback until `assets/images/fomra_logo.png` is added.
class FomraLogo extends StatelessWidget {
  final double width;
  const FomraLogo({super.key, this.width = 380});

  static const Color _ink = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'FOMRA',
                style: TextStyle(
                  fontSize: width * 0.215,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                  letterSpacing: -width * 0.006,
                  height: 1,
                ),
              ),
              SizedBox(width: width * 0.02),
              CustomPaint(
                size: Size(width * 0.20, width * 0.185),
                painter: _SwooshPainter(),
              ),
            ],
          ),
          SizedBox(height: width * 0.028),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'HOUSING & INFRASTRUCTURE PVT. LTD.',
              style: TextStyle(
                fontSize: width * 0.053,
                fontWeight: FontWeight.w700,
                color: _ink,
                letterSpacing: width * 0.004,
              ),
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
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [Color(0xFF10245C), Color(0xFF3D74D6)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    // Upper (larger) sweep
    final upper = Path()
      ..moveTo(w * 0.02, h * 0.52)
      ..quadraticBezierTo(w * 0.52, h * 0.10, w * 1.0, h * 0.02)
      ..quadraticBezierTo(w * 0.55, h * 0.40, w * 0.10, h * 0.66)
      ..close();
    canvas.drawPath(upper, paint);

    // Lower (smaller) sweep
    final lower = Path()
      ..moveTo(w * 0.14, h * 0.86)
      ..quadraticBezierTo(w * 0.52, h * 0.58, w * 0.90, h * 0.34)
      ..quadraticBezierTo(w * 0.52, h * 0.74, w * 0.22, h * 0.98)
      ..close();
    canvas.drawPath(lower, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
