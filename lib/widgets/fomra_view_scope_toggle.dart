import 'package:flutter/material.dart';

import '../services/app_store.dart';
import '../services/view_scope.dart';
import '../theme/app_theme.dart';
import '../theme/fomra_theme_context.dart';

/// Team / Individual switch in the app header, shown only to Reporting Managers
/// and Heads. Everything downstream re-scopes off [ViewScope] via
/// [LeadVisibility], so this widget only has to set the value.
///
/// Rebuilds on [AppStore] as well as [ViewScope] because whether it should
/// appear at all depends on the employee roster, which loads asynchronously.
class FomraViewScopeToggle extends StatelessWidget {
  const FomraViewScopeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([ViewScope.instance, AppStore.instance]),
      builder: (context, _) {
        if (!ViewScope.instance.canToggle) return const SizedBox.shrink();

        final isDark = context.isDarkMode;
        final compact = MediaQuery.sizeOf(context).width < 720;
        final fg = isDark ? AppColors.darkTextPrimary : Colors.white;
        final trackColor = isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.14);
        final borderColor = isDark
            ? context.fomraBorder.withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.22);

        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: trackColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final scope in TeamViewScope.values)
                  _ScopeSegment(
                    scope: scope,
                    selected: ViewScope.instance.scope == scope,
                    compact: compact,
                    foreground: fg,
                    onTap: () => ViewScope.instance.set(scope),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScopeSegment extends StatelessWidget {
  final TeamViewScope scope;
  final bool selected;
  final bool compact;
  final Color foreground;
  final VoidCallback onTap;

  const _ScopeSegment({
    required this.scope,
    required this.selected,
    required this.compact,
    required this.foreground,
    required this.onTap,
  });

  IconData get _icon => switch (scope) {
        TeamViewScope.team => Icons.groups_2_outlined,
        TeamViewScope.individual => Icons.person_outline_rounded,
      };

  String get _tooltip => switch (scope) {
        TeamViewScope.team => 'Team view — you and everyone reporting to you',
        TeamViewScope.individual => 'Individual view — only your own sites',
      };

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    // The selected pill sits on the header gradient, so it needs its own solid
    // surface to stay legible in both themes.
    final selectedBg =
        isDark ? Colors.white.withValues(alpha: 0.16) : Colors.white;
    final selectedFg = isDark ? AppColors.darkTextPrimary : AppColors.primary;

    return Tooltip(
      message: _tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: Semantics(
        button: true,
        selected: selected,
        label: '${scope.label} view',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.curve,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: selected ? selectedBg : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _icon,
                    size: 14,
                    color: selected
                        ? selectedFg
                        : foreground.withValues(alpha: 0.75),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 5),
                    Text(
                      scope.label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? selectedFg
                            : foreground.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
