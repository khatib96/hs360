import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../shared/widgets/app_text_field.dart';
import '../../domain/product_group.dart';

class ProductGroupFormDialog extends StatefulWidget {
  const ProductGroupFormDialog({
    required this.groups,
    required this.languageCode,
    this.initial,
    this.excludeGroupId,
    super.key,
  });

  final List<ProductGroup> groups;
  final String languageCode;
  final ProductGroup? initial;
  final String? excludeGroupId;

  @override
  State<ProductGroupFormDialog> createState() => _ProductGroupFormDialogState();
}

class _ProductGroupFormDialogState extends State<ProductGroupFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameArController;
  late final TextEditingController _nameEnController;
  String? _parentId;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _nameArController = TextEditingController(text: widget.initial?.nameAr ?? '');
    _nameEnController = TextEditingController(text: widget.initial?.nameEn ?? '');
    _parentId = widget.initial?.parentId;
    final excludedId = widget.excludeGroupId;
    if (excludedId != null && _parentId != null) {
      final blockedIds = {excludedId, ..._descendantIds(excludedId)};
      if (blockedIds.contains(_parentId)) _parentId = null;
    }
    _isActive = widget.initial?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();
    super.dispose();
  }

  List<ProductGroup> get _parentOptions {
    final blockedIds = <String>{};
    final excludedId = widget.excludeGroupId;
    if (excludedId != null) {
      blockedIds
        ..add(excludedId)
        ..addAll(_descendantIds(excludedId));
    }

    return widget.groups
        .where((g) => !blockedIds.contains(g.id))
        .where((g) => g.isActive || g.id == _parentId)
        .toList();
  }

  Set<String> _descendantIds(String groupId) {
    final childrenByParent = <String, List<ProductGroup>>{};
    for (final group in widget.groups) {
      final parentId = group.parentId;
      if (parentId == null) continue;
      childrenByParent.putIfAbsent(parentId, () => []).add(group);
    }

    final descendants = <String>{};
    void visit(String parentId) {
      for (final child in childrenByParent[parentId] ?? const <ProductGroup>[]) {
        if (!descendants.add(child.id)) continue;
        visit(child.id);
      }
    }

    visit(groupId);
    return descendants;
  }

  String _groupLabel(ProductGroup g) {
    return widget.languageCode.toLowerCase() == 'ar' ? g.nameAr : g.nameEn;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEdit = widget.initial != null;

    return AlertDialog(
      title: Text(isEdit ? l10n.productGroupEdit : l10n.productGroupAdd),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                label: l10n.productGroupNameAr,
                controller: _nameArController,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.productGroupValidationNameRequired
                    : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: l10n.productGroupNameEn,
                controller: _nameEnController,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.productGroupValidationNameRequired
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _parentId,
                decoration: InputDecoration(labelText: l10n.productGroupParent),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(l10n.productGroupNone),
                  ),
                  ..._parentOptions.map(
                    (g) => DropdownMenuItem(
                      value: g.id,
                      child: Text(_groupLabel(g)),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _parentId = v),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.productGroupActive),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(
              ProductGroupFormState(
                nameAr: _nameArController.text,
                nameEn: _nameEnController.text,
                parentId: _parentId,
                sortOrder: widget.initial?.sortOrder ?? 0,
                isActive: _isActive,
              ),
            );
          },
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }
}
