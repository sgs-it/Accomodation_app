// lib/widgets/bed_tile.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/bed.dart';
import '../core/theme.dart';
import '../core/constants.dart';

class BedTile extends StatelessWidget {
  final BedModel bed;
  final VoidCallback? onTap;

  const BedTile({super.key, required this.bed, this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = AppTheme.bedStatusColor(bed.status);
    final posLabel = kBedPositionLabels[bed.position] ?? bed.position;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 1.5),

        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  bed.bedCode.split('-').last,
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),

                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    bed.status,
                    style: GoogleFonts.inter(
                      color: statusColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              posLabel,
              style: GoogleFonts.inter(
                  color: AppTheme.textMuted, fontSize: 10),
            ),
            const SizedBox(height: 8),
            if (bed.occupant != null) ...[
              Icon(Icons.person, color: statusColor, size: 14),
              const SizedBox(height: 2),
              Text(
                bed.occupant!.name,
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                bed.occupant!.staffId,
                style: GoogleFonts.inter(
                  color: AppTheme.textMuted,
                  fontSize: 9,
                ),
              ),
            ] else ...[
              Icon(Icons.bed, color: AppTheme.textMuted, size: 14),
              const SizedBox(height: 2),
              Text(
                'Vacant',
                style: GoogleFonts.inter(
                    color: AppTheme.textMuted, fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
