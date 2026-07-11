import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/fomra_theme_context.dart';
import '../utils/tngis_parcel_lookup.dart';

/// TNGIS admin hierarchy + parcel identifiers (district, village LGD, ULPIN, etc.).
class TngisParcelSummary extends StatelessWidget {
  final TngisParcelDetails parcel;
  final bool loading;

  const TngisParcelSummary({
    super.key,
    required this.parcel,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return _shell(
        context,
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Fetching village & parcel details from TNGIS…',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    if (!parcel.hasAdminData && !parcel.hasParcelIdentifiers) {
      return const SizedBox.shrink();
    }

    return _shell(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TNGIS Land Records',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: context.fomraTextPrimary,
            ),
          ),
          const SizedBox(height: 10),
          if (parcel.hasAdminData) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if ((parcel.district ?? '').isNotEmpty)
                  _adminChip(context, 'District', parcel.district!),
                if ((parcel.taluk ?? '').isNotEmpty)
                  _adminChip(context, 'Taluk', parcel.taluk!),
                if ((parcel.village ?? '').isNotEmpty)
                  _adminChip(context, 'Village', parcel.village!),
              ],
            ),
            if (parcel.villageLgdDisplay != null) ...[
              const SizedBox(height: 10),
              Text(
                'Village LGD Code: ${parcel.villageLgdDisplay}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: context.fomraTextSecondary,
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if ((parcel.ulpin ?? '').isNotEmpty)
                _infoTile(context, 'ULPIN', parcel.ulpin!),
              if ((parcel.centroid ?? '').isNotEmpty)
                _infoTile(context, 'Centroid', parcel.centroid!),
              if (parcel.hasSurvey)
                _infoTile(context, parcel.surveyLabel, parcel.surveyNumber!),
              if ((parcel.subDivision ?? '').isNotEmpty)
                _infoTile(context, parcel.subLabel, parcel.subDivision!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shell(BuildContext context, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.07),
            AppColors.accent.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.fomraBorder),
      ),
      child: child,
    );
  }

  Widget _adminChip(BuildContext context, String label, String value) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.fomraSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.fomraBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: context.fomraTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.25,
              color: context.fomraTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(BuildContext context, String label, String value) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.fomraSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.fomraBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: context.fomraTextSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.fomraTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
