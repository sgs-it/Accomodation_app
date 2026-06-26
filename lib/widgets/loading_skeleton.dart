// lib/widgets/loading_skeleton.dart

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/theme.dart';

class LoadingSkeleton extends StatelessWidget {
  final double height;
  final double? width;
  final double radius;

  const LoadingSkeleton({
    super.key,
    this.height = 16,
    this.width,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.bgCard,
      highlightColor: AppTheme.bgCardLight,
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LoadingSkeleton(height: 16, width: 150),
          const SizedBox(height: 8),
          const LoadingSkeleton(height: 12, width: 200),
          const SizedBox(height: 12),
          Row(
            children: [
              const LoadingSkeleton(height: 32, width: 80, radius: 8),
              const SizedBox(width: 8),
              const LoadingSkeleton(height: 32, width: 80, radius: 8),
            ],
          ),
        ],
      ),
    );
  }
}
