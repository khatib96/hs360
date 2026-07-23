import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_detail_surface.dart';
import 'invoice_design.dart';

/// Document sheet used by the invoice FORM and DETAIL screens.
///
/// On desktop it renders a neutral page background with a centered, bordered
/// white "paper" panel (accounting document feel). On mobile it goes full-bleed
/// so the form/detail stack naturally. NOT used by the list.
class InvoiceSheet extends StatelessWidget {
  const InvoiceSheet({required this.child, this.banner, super.key});

  /// Optional banner area (errors/validation) shown above the sheet.
  final Widget? banner;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDesktop = InvoiceDesign.isDesktop(context);

    if (!isDesktop) {
      return ListView(
        padding: InvoiceDesign.pagePadding,
        children: [
          if (banner != null) ...[banner!, const SizedBox(height: 12)],
          child,
        ],
      );
    }

    return ColoredBox(
      color: InvoiceDesign.pageFill,
      child: Align(
        alignment: AlignmentDirectional.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: InvoiceDesign.sheetMaxWidth,
          ),
          child: ListView(
            padding: const EdgeInsetsDirectional.all(24),
            children: [
              if (banner != null) ...[banner!, const SizedBox(height: 16)],
              DecoratedBox(
                decoration: InvoiceDesign.panel.copyWith(
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(24),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A titled, thin-bordered block used to group fields/sections inside a sheet.
class InvoiceSectionCard extends StatelessWidget {
  const InvoiceSectionCard({
    required this.child,
    this.title,
    this.trailing,
    this.padding,
    super.key,
  });

  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return AppDetailSection(
      title: title,
      trailing: trailing,
      padding: padding ?? InvoiceDesign.sectionPadding,
      child: child,
    );
  }
}
