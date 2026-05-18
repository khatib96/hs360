import 'package:flutter/material.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    required this.title,
    required this.body,
    this.actions,
    super.key,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(child: body),
    );
  }
}

class AppBrandMark extends StatelessWidget {
  static const logoAssetPath = 'assets/brand/hs-logo-gold.png';

  const AppBrandMark({
    required this.title,
    required this.brandName,
    required this.tagline,
    super.key,
  });

  final String title;
  final String brandName;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Semantics(
      image: true,
      label: title,
      child: ExcludeSemantics(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                logoAssetPath,
                height: 76,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
              const SizedBox(height: 8),
              Text(
                brandName,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: textTheme.displaySmall?.copyWith(
                  color: onSurface,
                  fontSize: 34,
                  fontWeight: FontWeight.w400,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tagline,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: onSurface,
                  fontSize: 17,
                  fontStyle: FontStyle.italic,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
