import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/fomra_theme_context.dart';
import 'app_components.dart';

/// A column definition for [AppDataTable].
class AppTableColumn {
  const AppTableColumn(
    this.label, {
    this.numeric = false,
    this.tooltip,
  });

  final String label;

  /// Right-aligns the header and cells (for numeric/amount columns).
  final bool numeric;
  final String? tooltip;
}

/// A row definition for [AppDataTable]. [cells] must match the column count.
class AppTableRow {
  const AppTableRow({required this.cells, this.onTap, this.selected = false});

  final List<Widget> cells;
  final VoidCallback? onTap;
  final bool selected;
}

/// ============================================================================
/// A styled, responsive data table.
///
/// One consistent look for tabular data across Reports, Land Bank, Audit, etc.:
/// a rounded bordered container, a tinted uppercase header, zebra striping,
/// row hover/press, and horizontal scrolling on narrow screens. Renders an
/// [EmptyState] when there are no rows.
///
/// Pure presentation — pass in already-built cell widgets and tap callbacks.
/// ============================================================================
class AppDataTable extends StatelessWidget {
  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage,
    this.emptyIcon = Icons.table_chart_outlined,
    this.emptyAction,
    this.minWidth = 640,
    this.rowHeight = 56,
    this.headingHeight = 48,
  });

  final List<AppTableColumn> columns;
  final List<AppTableRow> rows;

  final String emptyTitle;
  final String? emptyMessage;
  final IconData emptyIcon;
  final Widget? emptyAction;

  /// Below this width the table scrolls horizontally instead of squeezing.
  final double minWidth;
  final double rowHeight;
  final double headingHeight;

  @override
  Widget build(BuildContext context) {
    final surface = context.fomraSurface;
    final surfaceVar = context.fomraSurfaceVar;
    final border = context.fomraBorder;
    final container = Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: EmptyState(
                title: emptyTitle,
                message: emptyMessage,
                icon: emptyIcon,
                action: emptyAction,
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final table = DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(surfaceVar),
                  headingRowHeight: headingHeight,
                  dataRowMinHeight: rowHeight,
                  dataRowMaxHeight: rowHeight,
                  dividerThickness: 1,
                  horizontalMargin: AppSpacing.md,
                  columnSpacing: AppSpacing.lg,
                  headingTextStyle: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(
                        color: context.fomraTextSecondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                  dataTextStyle: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: context.fomraTextPrimary),
                  columns: [
                    for (final c in columns)
                      DataColumn(
                        numeric: c.numeric,
                        tooltip: c.tooltip,
                        label: Text(c.label.toUpperCase()),
                      ),
                  ],
                  rows: [
                    for (var i = 0; i < rows.length; i++)
                      DataRow(
                        selected: rows[i].selected,
                        onSelectChanged: rows[i].onTap == null
                            ? null
                            : (_) => rows[i].onTap!(),
                        color: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.hovered)) {
                            return AppColors.primary.withValues(alpha: 0.06);
                          }
                          // Zebra striping on odd rows.
                          if (i.isOdd) {
                            return surfaceVar.withValues(alpha: 0.4);
                          }
                          return null;
                        }),
                        cells: [
                          for (final cell in rows[i].cells) DataCell(cell),
                        ],
                      ),
                  ],
                );

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth < minWidth
                          ? minWidth
                          : constraints.maxWidth,
                    ),
                    child: table,
                  ),
                );
              },
            ),
    );

    return container;
  }
}
