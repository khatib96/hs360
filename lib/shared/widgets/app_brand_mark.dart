import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';

class AppBrandMark extends StatelessWidget {
  static const logoAssetPath = 'assets/brand/hs-logo-gold.png';

  const AppBrandMark({required this.title, this.width = 220, super.key});

  final String title;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: title,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth.clamp(0.0, width).toDouble()
                : width;
            return SizedBox(
              width: maxWidth > 0 ? maxWidth : width,
              child: AspectRatio(
                aspectRatio: 220 / 88,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: width,
                    height: width * 88 / 220,
                    child: Image.asset(
                      logoAssetPath,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (context, error, stackTrace) {
                        return Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.brandGold,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class AppCompactBrand extends StatelessWidget {
  const AppCompactBrand({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.charcoal,
        borderRadius: AppRadii.controlRadius,
      ),
      child: const Text(
        'HS',
        style: TextStyle(
          color: AppColors.brandGold,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AppSidebarBrand extends StatelessWidget {
  const AppSidebarBrand({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const AppCompactBrand(),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              'HS360',
              maxLines: 1,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.charcoal,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
