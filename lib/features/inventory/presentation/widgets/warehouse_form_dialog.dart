import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../shared/widgets/app_text_field.dart';
import '../../domain/warehouse.dart';
import '../../domain/warehouse_assignable_employee.dart';
import '../../domain/warehouse_form_state.dart';
import '../../domain/warehouse_type.dart';
import '../warehouse_display_helpers.dart';

class WarehouseFormDialog extends StatefulWidget {
  const WarehouseFormDialog({
    required this.languageCode,
    required this.employees,
    required this.warehouses,
    this.initial,
    super.key,
  });

  final String languageCode;
  final List<WarehouseAssignableEmployee> employees;
  final List<Warehouse> warehouses;
  final Warehouse? initial;

  @override
  State<WarehouseFormDialog> createState() => _WarehouseFormDialogState();
}

class _WarehouseFormDialogState extends State<WarehouseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameArController;
  late final TextEditingController _nameEnController;
  late final TextEditingController _addressController;
  late WarehouseType _type;
  String? _agentId;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameArController = TextEditingController(text: initial?.nameAr ?? '');
    _nameEnController = TextEditingController(text: initial?.nameEn ?? '');
    _addressController = TextEditingController(
      text: initial?.locationAddress ?? '',
    );
    _type = initial?.type ?? WarehouseType.main;
    _agentId = initial?.agentId;
    _isActive = initial?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  List<WarehouseAssignableEmployee> get _employeeOptions {
    return dropdownAssignableEmployees(
      employees: widget.employees,
      warehouses: widget.warehouses,
      excludeWarehouseId: widget.initial?.id,
      includeAgentId: _agentId,
    );
  }

  String _typeLabel(WarehouseType type, AppLocalizations l10n) {
    return localizedWarehouseTypeLabel(
      type,
      (key) => switch (key) {
        'main' => l10n.warehouseTypeMain,
        'branch' => l10n.warehouseTypeBranch,
        'van' => l10n.warehouseTypeVan,
        _ => key,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEdit = widget.initial != null;
    final showEmployee = _type == WarehouseType.van;

    return AlertDialog(
      title: Text(isEdit ? l10n.warehouseEdit : l10n.warehouseAdd),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  label: l10n.warehouseNameAr,
                  controller: _nameArController,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l10n.productValidationNameArRequired
                      : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: l10n.warehouseNameEn,
                  controller: _nameEnController,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l10n.productValidationNameEnRequired
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<WarehouseType>(
                  initialValue: _type,
                  decoration: InputDecoration(labelText: l10n.warehouseType),
                  items: WarehouseType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(_typeLabel(type, l10n)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _type = value;
                      if (value != WarehouseType.van) {
                        _agentId = null;
                      }
                    });
                  },
                ),
                if (showEmployee) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: _agentId,
                    decoration: InputDecoration(labelText: l10n.warehouseEmployee),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(l10n.warehouseEmployeeNone),
                      ),
                      ..._employeeOptions.map(
                        (e) => DropdownMenuItem(
                          value: e.id,
                          child: Text(
                            localizedEmployeeLabel(e, widget.languageCode),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _agentId = value),
                    validator: (value) {
                      if (_type == WarehouseType.van &&
                          (value == null || value.isEmpty)) {
                        return l10n.warehouseValidationAgentRequired;
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 12),
                AppTextField(
                  label: l10n.warehouseLocationAddress,
                  controller: _addressController,
                ),
                if (isEdit) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.warehouseActive),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ],
              ],
            ),
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
              WarehouseFormState(
                nameAr: _nameArController.text,
                nameEn: _nameEnController.text,
                type: _type,
                agentId: _type == WarehouseType.van ? _agentId : null,
                locationAddress: _addressController.text,
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
