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

  const AppBrandMark({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: title,
      child: ExcludeSemantics(
        child: SizedBox(
          width: 220,
          child: Image.asset(
            logoAssetPath,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
