import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../auth/domain/app_session.dart';
import '../data/global_tools_repository.dart';
import '../domain/global_search_result.dart';

Future<void> showGlobalSearchPalette({
  required BuildContext context,
  required AppSession session,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => GlobalSearchPalette(session: session),
  );
}

class GlobalSearchPalette extends ConsumerStatefulWidget {
  const GlobalSearchPalette({required this.session, super.key});

  final AppSession session;

  @override
  ConsumerState<GlobalSearchPalette> createState() =>
      _GlobalSearchPaletteState();
}

class _GlobalSearchPaletteState extends ConsumerState<GlobalSearchPalette> {
  final _controller = TextEditingController();
  Timer? _debounce;
  var _results = const <GlobalSearchResult>[];
  var _loading = false;
  var _failed = false;
  var _selected = 0;
  var _requestSerial = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _results = const [];
        _loading = false;
        _failed = false;
        _selected = 0;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(query));
  }

  Future<void> _search(String query) async {
    final serial = ++_requestSerial;
    try {
      final results = await ref
          .read(globalToolsRepositoryProvider)
          .search(widget.session, query);
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _results = results;
        _loading = false;
        _selected = 0;
      });
    } catch (_) {
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _results = const [];
        _loading = false;
        _failed = true;
        _selected = 0;
      });
    }
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    if (_results.isEmpty) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() => _selected = (_selected + 1) % _results.length);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(
        () => _selected = (_selected - 1 + _results.length) % _results.length,
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _open(_results[_selected]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _open(GlobalSearchResult item) {
    if (!item.route.startsWith('/')) return;
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go(item.route);
  }

  String _categoryLabel(AppLocalizations l10n, String category) {
    return switch (category) {
      'customers' => l10n.globalSearchCategoryCustomers,
      'suppliers' => l10n.globalSearchCategorySuppliers,
      'contracts' => l10n.globalSearchCategoryContracts,
      'invoices' => l10n.globalSearchCategoryInvoices,
      'vouchers' => l10n.globalSearchCategoryVouchers,
      'products' => l10n.globalSearchCategoryProducts,
      'product_units' => l10n.globalSearchCategoryProductUnits,
      'inventory_documents' => l10n.globalSearchCategoryInventoryDocuments,
      _ => category,
    };
  }

  IconData _categoryIcon(String category) {
    return switch (category) {
      'customers' => Icons.people_outline,
      'suppliers' => Icons.local_shipping_outlined,
      'contracts' => Icons.description_outlined,
      'invoices' => Icons.receipt_long_outlined,
      'vouchers' => Icons.payments_outlined,
      'products' => Icons.inventory_2_outlined,
      'product_units' => Icons.qr_code_2,
      'inventory_documents' => Icons.assignment_outlined,
      _ => Icons.search,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final hasQuery = _controller.text.trim().length >= 2;

    return Dialog(
      insetPadding: EdgeInsets.all(narrow ? 12 : 40),
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Focus(
          onKeyEvent: _onKeyEvent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 8),
                child: TextField(
                  key: const Key('global-search-field'),
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: _changed,
                  onSubmitted: (_) {
                    if (_results.isNotEmpty) _open(_results[_selected]);
                  },
                  decoration: InputDecoration(
                    hintText: l10n.globalSearchHint,
                    prefixIcon: const Icon(Icons.search),
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              Flexible(
                child: _SearchBody(
                  minimumMessage: l10n.globalSearchMinimum,
                  emptyMessage: l10n.globalSearchEmpty,
                  errorMessage: l10n.globalSearchError,
                  keyboardHint: l10n.globalSearchKeyboardHint,
                  hasQuery: hasQuery,
                  failed: _failed,
                  loading: _loading,
                  results: _results,
                  selected: _selected,
                  languageCode: languageCode,
                  categoryLabel: (category) => _categoryLabel(l10n, category),
                  categoryIcon: _categoryIcon,
                  onOpen: _open,
                  onHover: (index) => setState(() => _selected = index),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBody extends StatelessWidget {
  const _SearchBody({
    required this.minimumMessage,
    required this.emptyMessage,
    required this.errorMessage,
    required this.keyboardHint,
    required this.hasQuery,
    required this.failed,
    required this.loading,
    required this.results,
    required this.selected,
    required this.languageCode,
    required this.categoryLabel,
    required this.categoryIcon,
    required this.onOpen,
    required this.onHover,
  });

  final String minimumMessage;
  final String emptyMessage;
  final String errorMessage;
  final String keyboardHint;
  final bool hasQuery;
  final bool failed;
  final bool loading;
  final List<GlobalSearchResult> results;
  final int selected;
  final String languageCode;
  final String Function(String) categoryLabel;
  final IconData Function(String) categoryIcon;
  final ValueChanged<GlobalSearchResult> onOpen;
  final ValueChanged<int> onHover;

  @override
  Widget build(BuildContext context) {
    if (!hasQuery) {
      return _message(context, minimumMessage, Icons.search);
    }
    if (failed) {
      return _message(context, errorMessage, Icons.cloud_off_outlined);
    }
    if (!loading && results.isEmpty) {
      return _message(context, emptyMessage, Icons.search_off_outlined);
    }

    return ListView.builder(
      key: const Key('global-search-results'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      shrinkWrap: true,
      itemCount: results.length + 1,
      itemBuilder: (context, listIndex) {
        if (listIndex == results.length) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              keyboardHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          );
        }
        final item = results[listIndex];
        final showHeader =
            listIndex == 0 || results[listIndex - 1].category != item.category;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showHeader)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 4),
                child: Text(
                  categoryLabel(item.category),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            MouseRegion(
              onEnter: (_) => onHover(listIndex),
              child: ListTile(
                key: Key('global-search-result-${item.entityId}'),
                selected: selected == listIndex,
                leading: Icon(categoryIcon(item.category)),
                title: Text(
                  item.title(languageCode),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(item.identifier),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onOpen(item),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _message(BuildContext context, String message, IconData icon) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
