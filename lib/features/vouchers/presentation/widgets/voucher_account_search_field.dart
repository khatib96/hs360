import 'package:flutter/material.dart';

import '../../../accounting/domain/chart_account.dart';
import '../../../invoices/presentation/widgets/invoice_design.dart';
import '../voucher_display_helpers.dart';

class VoucherAccountSearchField extends StatefulWidget {
  const VoucherAccountSearchField({
    required this.accounts,
    required this.selectedAccountId,
    required this.languageCode,
    required this.label,
    required this.onSelected,
    super.key,
  });

  final List<ChartAccount> accounts;
  final String? selectedAccountId;
  final String languageCode;
  final String label;
  final ValueChanged<String?> onSelected;

  @override
  State<VoucherAccountSearchField> createState() =>
      _VoucherAccountSearchFieldState();
}

class _VoucherAccountSearchFieldState extends State<VoucherAccountSearchField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String? _lastSelectedId;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _syncText();
  }

  @override
  void didUpdateWidget(VoucherAccountSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedAccountId != widget.selectedAccountId ||
        oldWidget.accounts != widget.accounts ||
        oldWidget.languageCode != widget.languageCode) {
      _syncText();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<ChartAccount>(
      textEditingController: _controller,
      focusNode: _focusNode,
      displayStringForOption: _display,
      optionsBuilder: (value) {
        return _rankedAccounts(value.text).take(20);
      },
      onSelected: (account) {
        _lastSelectedId = account.id;
        widget.onSelected(account.id);
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          decoration: InvoiceDesign.denseField(
            context,
            label: widget.label,
            suffixIcon: const Icon(Icons.search, size: 18),
          ),
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (value) {
            final exactMatch = _exactAccount(value);
            if (exactMatch != null) {
              textController.text = _display(exactMatch);
              _lastSelectedId = exactMatch.id;
              widget.onSelected(exactMatch.id);
              return;
            }

            final matches = _rankedAccounts(value).toList();
            if (matches.length == 1) {
              final account = matches.single;
              textController.text = _display(account);
              _lastSelectedId = account.id;
              widget.onSelected(account.id);
            }
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: AlignmentDirectional.topStart,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320, maxWidth: 520),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final account = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(account),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Text(_display(account)),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _syncText() {
    if (_focusNode.hasFocus && _lastSelectedId == widget.selectedAccountId) {
      return;
    }
    final selected = _accountById(widget.selectedAccountId);
    final text = selected == null ? '' : _display(selected);
    if (_controller.text != text) {
      _controller.text = text;
    }
    _lastSelectedId = widget.selectedAccountId;
  }

  ChartAccount? _accountById(String? id) {
    if (id == null || id.trim().isEmpty) return null;
    for (final account in widget.accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  String _display(ChartAccount account) {
    return voucherAccountDisplayName(
      widget.languageCode,
      nameAr: account.nameAr,
      nameEn: account.nameEn,
      code: account.code,
    );
  }

  Iterable<ChartAccount> _rankedAccounts(String rawQuery) {
    final query = _normalize(rawQuery);
    final accounts = List<ChartAccount>.from(widget.accounts);
    if (query.isEmpty) return accounts;

    final matches = accounts
        .where((account) => _haystack(account).contains(query))
        .toList();
    matches.sort((a, b) {
      final aScore = _score(a, query);
      final bScore = _score(b, query);
      if (aScore != bScore) return aScore.compareTo(bScore);
      return a.code.compareTo(b.code);
    });
    return matches;
  }

  ChartAccount? _exactAccount(String rawQuery) {
    final query = _normalize(rawQuery);
    if (query.isEmpty) return null;
    for (final account in widget.accounts) {
      final code = _normalize(account.code);
      final ar = _normalize(account.nameAr);
      final en = _normalize(account.nameEn);
      if (code == query || ar == query || en == query) {
        return account;
      }
    }
    return null;
  }

  String _haystack(ChartAccount account) {
    return _normalize('${account.code} ${account.nameAr} ${account.nameEn}');
  }

  int _score(ChartAccount account, String query) {
    final code = _normalize(account.code);
    final ar = _normalize(account.nameAr);
    final en = _normalize(account.nameEn);
    if (code == query || ar == query || en == query) return 0;
    if (code.startsWith(query)) return 1;
    if (ar.startsWith(query) || en.startsWith(query)) return 2;
    if (code.contains(query)) return 3;
    return 4;
  }

  String _normalize(String value) {
    return value.trim().toLowerCase();
  }
}
