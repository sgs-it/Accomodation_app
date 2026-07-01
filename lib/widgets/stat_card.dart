// lib/widgets/stat_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/theme.dart';

class StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  final String trendText;
  final bool trendUp;
  final List<double> sparklineData;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.trendText = '',
    this.trendUp = true,
    this.sparklineData = const [],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final trendColor = trendUp ? AppTheme.statUpGreen : AppTheme.statDownRed;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // Watermark Icon
            Positioned(
              right: -10,
              top: 20,
              child: Icon(
                icon,
                size: 80,
                color: color.withValues(alpha: 0.05),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(height: 12),
                  // Value
                  Text(
                    value.toString(),
                    style: GoogleFonts.inter(
                      color: const Color(0xFF1E293B),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Label
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Trend
                  if (trendText.isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          trendUp ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 14,
                          color: trendColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          trendText,
                          style: GoogleFonts.inter(
                            color: trendColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          ' from last month',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  const Spacer(),
                ],
              ),
            ),
            // Sparkline Chart at bottom
            if (sparklineData.isNotEmpty)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 40,
                child: IgnorePointer(
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: (sparklineData.length - 1).toDouble(),
                      minY: sparklineData.reduce((a, b) => a < b ? a : b) * 0.9,
                      maxY: sparklineData.reduce((a, b) => a > b ? a : b) * 1.1,
                      lineBarsData: [
                        LineChartBarData(
                          spots: sparklineData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                          isCurved: true,
                          color: color,
                          barWidth: 1.5,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                color.withValues(alpha: 0.2),
                                color.withValues(alpha: 0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
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
