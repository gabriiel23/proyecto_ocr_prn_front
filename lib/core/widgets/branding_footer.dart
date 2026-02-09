import 'package:flutter/material.dart';

class BrandingFooter extends StatelessWidget {
  final bool isDark;

  const BrandingFooter({super.key, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                (isDark ? Colors.white : Colors.grey[300]!).withValues(
                  alpha: 0.5,
                ),
                Colors.transparent,
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 14,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.grey[500],
            ),
            const SizedBox(width: 6),
            Text(
              'Desarrollado por',
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.grey[500],
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Universidad Internacional del Ecuador',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: isDark
                ? Colors.white.withValues(alpha: 0.7)
                : Colors.grey[700],
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
