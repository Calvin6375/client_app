import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:shimmer/shimmer.dart';

/// Theme-aware shimmer wrapper used across the app.
class AppShimmer extends StatelessWidget {
  const AppShimmer({super.key, required this.child});

  final Widget child;

  static (Color base, Color highlight) colorsFor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppColors.getThemeColors(context);
    if (isDark) {
      return (
        colors.surfaceVariant.withValues(alpha: 0.85),
        colors.surface.withValues(alpha: 0.95),
      );
    }
    return (
      colors.border.withValues(alpha: 0.9),
      colors.borderLight.withValues(alpha: 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (base, highlight) = colorsFor(context);
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: child,
    );
  }
}

/// Rounded rectangle bone used inside [AppShimmer].
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Circular bone used inside [AppShimmer].
class ShimmerCircle extends StatelessWidget {
  const ShimmerCircle({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Compact inline shimmer that replaces small [CircularProgressIndicator]s.
///
/// Use [onPrimary] for loaders on teal/primary buttons.
class ShimmerBusyIndicator extends StatelessWidget {
  const ShimmerBusyIndicator({
    super.key,
    this.width = 22,
    this.height = 12,
    this.onPrimary = false,
  });

  final double width;
  final double height;
  final bool onPrimary;

  @override
  Widget build(BuildContext context) {
    final bone = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );

    if (onPrimary) {
      return Shimmer.fromColors(
        baseColor: Colors.white.withValues(alpha: 0.35),
        highlightColor: Colors.white.withValues(alpha: 0.9),
        child: bone,
      );
    }

    return AppShimmer(child: bone);
  }
}

/// Thin top shimmer bar (webview / page load progress).
class ShimmerProgressBar extends StatelessWidget {
  const ShimmerProgressBar({super.key, this.height = 2});

  final double height;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ShimmerBox(
        width: double.infinity,
        height: height,
        borderRadius: 0,
      ),
    );
  }
}

/// Transaction row skeletons for home / wallet / transactions lists.
class TransactionListShimmer extends StatelessWidget {
  const TransactionListShimmer({
    super.key,
    this.itemCount = 5,
    this.compact = true,
  });

  final int itemCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Column(
        children: List.generate(itemCount, (index) {
          return Padding(
            padding: EdgeInsets.only(bottom: compact ? 8 : 12),
            child: Row(
              children: [
                const ShimmerCircle(size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: compact ? 120 : 160, height: 12),
                      const SizedBox(height: 8),
                      ShimmerBox(width: compact ? 80 : 100, height: 10),
                    ],
                  ),
                ),
                const ShimmerBox(width: 56, height: 12),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// Full home dashboard skeleton (access check / first paint).
class DashboardShimmer extends StatelessWidget {
  const DashboardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return SafeArea(
      top: false,
      child: AppShimmer(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, top + 12, 20, 20),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ShimmerCircle(size: 40),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: 90, height: 10),
                        SizedBox(height: 8),
                        ShimmerBox(width: 160, height: 14),
                      ],
                    ),
                  ),
                  ShimmerCircle(size: 36),
                ],
              ),
              SizedBox(height: 20),
              ShimmerBox(width: 200, height: 36, borderRadius: 16),
              SizedBox(height: 16),
              ShimmerBox(height: 180, borderRadius: 20),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: ShimmerBox(height: 48, borderRadius: 12)),
                  SizedBox(width: 12),
                  Expanded(child: ShimmerBox(height: 48, borderRadius: 12)),
                ],
              ),
              SizedBox(height: 28),
              ShimmerBox(width: 140, height: 14),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerCircle(size: 48),
                  ShimmerCircle(size: 48),
                  ShimmerCircle(size: 48),
                  ShimmerCircle(size: 48),
                ],
              ),
              SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerBox(width: 140, height: 14),
                  ShimmerBox(width: 48, height: 12),
                ],
              ),
              SizedBox(height: 16),
              TransactionListShimmerBones(itemCount: 3),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bones only (must sit inside [AppShimmer]).
class TransactionListShimmerBones extends StatelessWidget {
  const TransactionListShimmerBones({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              ShimmerCircle(size: 40),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 120, height: 12),
                    SizedBox(height: 8),
                    ShimmerBox(width: 80, height: 10),
                  ],
                ),
              ),
              ShimmerBox(width: 56, height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wallet settings / profile page skeleton.
class SettingsPageShimmer extends StatelessWidget {
  const SettingsPageShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            const ShimmerCircle(size: 88),
            const SizedBox(height: 12),
            const ShimmerBox(width: 140, height: 16),
            const SizedBox(height: 8),
            const ShimmerBox(width: 180, height: 12),
            const SizedBox(height: 24),
            const ShimmerBox(height: 120, borderRadius: 16),
            const SizedBox(height: 20),
            ...List.generate(
              5,
              (_) => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: ShimmerBox(height: 56, borderRadius: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Generic form / detail page skeleton.
class PageContentShimmer extends StatelessWidget {
  const PageContentShimmer({super.key, this.blocks = 4});

  final int blocks;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerBox(width: 160, height: 18),
            const SizedBox(height: 8),
            const ShimmerBox(width: 220, height: 12),
            const SizedBox(height: 24),
            ...List.generate(
              blocks,
              (_) => const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: ShimmerBox(height: 52, borderRadius: 12),
              ),
            ),
            const SizedBox(height: 24),
            const ShimmerBox(height: 52, borderRadius: 12),
          ],
        ),
      ),
    );
  }
}

/// Notification list skeleton.
class NotificationListShimmer extends StatelessWidget {
  const NotificationListShimmer({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerCircle(size: 44),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: double.infinity, height: 14),
                  SizedBox(height: 8),
                  ShimmerBox(width: 180, height: 12),
                  SizedBox(height: 8),
                  ShimmerBox(width: 80, height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Receive / QR style card skeleton.
class CardBlockShimmer extends StatelessWidget {
  const CardBlockShimmer({
    super.key,
    this.height = 220,
    this.borderRadius = 16,
  });

  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ShimmerBox(height: height, borderRadius: borderRadius),
    );
  }
}
