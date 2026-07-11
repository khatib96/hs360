import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../auth/presentation/auth_controller.dart';
import '../../../products/data/product_repository.dart';
import '../../../products/domain/product.dart';
import '../../../products/domain/product_filters.dart';
import '../../../products/domain/product_type.dart';
import '../../../products/presentation/product_display_helpers.dart';

Future<Product?> showConsumableRentalProductPicker(BuildContext context) {
  return showDialog<Product>(
    context: context,
    builder: (_) => const ConsumableRentalProductPickerDialog(),
  );
}

class ConsumableRentalProductPickerDialog extends ConsumerStatefulWidget {
  const ConsumableRentalProductPickerDialog({super.key});

  @override
  ConsumerState<ConsumableRentalProductPickerDialog> createState() =>
      _ConsumableRentalProductPickerDialogState();
}

class _ConsumableRentalProductPickerDialogState
    extends ConsumerState<ConsumableRentalProductPickerDialog> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  var _results = <Product>[];
  var _isSearching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return;

    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final products = await ref
          .read(productRepositoryProvider)
          .fetchProducts(
            ProductFilters(
              search: trimmed,
              productType: ProductType.consumableRental,
              isActive: true,
            ),
            session,
          );
      if (!mounted) return;
      setState(() {
        _results = products.take(20).toList();
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _isSearching = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_search(query));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;

    return AlertDialog(
      title: Text(l10n.contractFieldProduct),
      content: SizedBox(
        width: 420,
        height: 360,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('consumable-product-search'),
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.contractFilterSearchHint,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 12),
            if (_isSearching) const LinearProgressIndicator(),
            Expanded(
              child: _results.isEmpty
                  ? Center(child: Text(l10n.contractSelectProductFirst))
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final product = _results[index];
                        return ListTile(
                          key: Key('consumable-product-${product.id}'),
                          title: Text(localizedProductName(product, locale)),
                          subtitle: Text(product.sku),
                          onTap: () => Navigator.pop(context, product),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ],
    );
  }
}
