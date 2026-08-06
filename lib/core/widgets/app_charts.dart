import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

/// Une part d'un graphique (catégorie de CA, moyen de paiement…).
class ChartSlice {
  const ChartSlice({required this.label, required this.value, this.color});

  final String label;
  final num value;
  final Color? color;
}

/// Histogramme simple (CA par semaine) : la barre la plus haute est mise en
/// avant en vert accent, les autres en vert pâle.
class AppBarChart extends StatelessWidget {
  const AppBarChart({
    super.key,
    required this.slices,
    this.height = 96,
    this.highlightMax = true,
  });

  final List<ChartSlice> slices;
  final double height;
  final bool highlightMax;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) return const SizedBox.shrink();

    final maxValue = slices
        .map((slice) => slice.value)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < slices.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(
              child: _Bar(
                slice: slices[i],
                ratio: maxValue == 0 ? 0 : slices[i].value / maxValue,
                highlighted: highlightMax && slices[i].value == maxValue,
                maxBarHeight: height - 22,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.slice,
    required this.ratio,
    required this.highlighted,
    required this.maxBarHeight,
  });

  final ChartSlice slice;
  final double ratio;
  final bool highlighted;
  final double maxBarHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          height: math.max(6, maxBarHeight * ratio),
          decoration: BoxDecoration(
            color: highlighted ? AppColors.accent : AppColors.tintGreenBorder,
            borderRadius: BorderRadius.circular(7),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          slice.label,
          style: highlighted
              ? AppTypography.sora(10.5, FontWeight.w700,
                  color: AppColors.primary)
              : AppTypography.manrope(10.5, FontWeight.w600,
                  color: AppColors.textFaint),
        ),
      ],
    );
  }
}

/// Anneau de répartition + légende (rapport par service, moyens de paiement).
class AppDonutChart extends StatelessWidget {
  const AppDonutChart({
    super.key,
    required this.slices,
    this.size = 112,
    this.centerLabel = '100%',
    this.centerCaption = 'du CA',
  });

  final List<ChartSlice> slices;
  final double size;
  final String centerLabel;
  final String centerCaption;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (sum, s) => sum + s.value);

    return Row(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _DonutPainter(slices: slices, total: total),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    centerLabel,
                    style: AppTypography.sora(15, FontWeight.w800),
                  ),
                  Text(
                    centerCaption,
                    style: AppTypography.manrope(
                      9,
                      FontWeight.w600,
                      color: AppColors.textFaint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            children: [
              for (var i = 0; i < slices.length; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: i == slices.length - 1 ? 0 : 9),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _colorAt(i),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          slices[i].label,
                          style: AppTypography.manrope(12.5, FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        total == 0
                            ? '—'
                            : '${(slices[i].value / total * 100).round()} %',
                        style: AppTypography.sora(
                          12,
                          FontWeight.w700,
                          color: AppColors.textBody,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Color _colorAt(int index) =>
      slices[index].color ??
      AppColors.chartSeries[index % AppColors.chartSeries.length];
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.slices, required this.total});

  final List<ChartSlice> slices;
  final double total;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * 0.205;
    final radius = (size.width - stroke) / 2;
    final center = rect.center;

    if (total <= 0) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = AppColors.toggleOff,
      );
      return;
    }

    var start = -math.pi / 2;
    for (var i = 0; i < slices.length; i++) {
      final sweep = slices[i].value / total * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = slices[i].color ??
              AppColors.chartSeries[i % AppColors.chartSeries.length],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.slices != slices || oldDelegate.total != total;
}

/// Bloc à deux colonnes chiffrées (CA généré / commission).
class AppSplitMetrics extends StatelessWidget {
  const AppSplitMetrics({super.key, required this.entries});

  /// Paires (valeur, libellé), affichées côte à côte.
  final List<({String value, String label, Color? color})> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0)
              const SizedBox(
                height: 52,
                child: VerticalDivider(width: 1, color: AppColors.border),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
                child: Column(
                  children: [
                    Text(
                      entries[i].value,
                      textAlign: TextAlign.center,
                      style: AppTypography.sora(
                        15,
                        FontWeight.w800,
                        color: entries[i].color ?? AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entries[i].label,
                      style: AppTypography.manrope(
                        10,
                        FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
