import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/documents/domain/document_money_formatter.dart';
import '../../../core/documents/domain/tenant_currency_format.dart';
import '../../../core/localization/locale_controller.dart';
import 'tenant_currency_provider.dart';

/// Canonical finance amount display using tenant currency rules.
class MoneyDisplay extends ConsumerWidget {
  const MoneyDisplay({
    required this.amount,
    this.style,
    this.includeSymbol = true,
    super.key,
  });

  final Decimal amount;
  final TextStyle? style;
  final bool includeSymbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final currencyAsync = ref.watch(tenantCurrencyFormatProvider);

    return currencyAsync.when(
      data: (format) => Text(
        formatDocumentMoney(
          amount,
          format,
          languageCode: locale.languageCode,
          includeSymbol: includeSymbol,
        ),
        style: style,
      ),
      loading: () => Text(
        formatDocumentMoney(
          amount,
          TenantCurrencyFormat.defaults(),
          languageCode: locale.languageCode,
          includeSymbol: includeSymbol,
        ),
        style: style,
      ),
      error: (_, _) => Text(
        formatDocumentMoney(
          amount,
          TenantCurrencyFormat.defaults(),
          languageCode: locale.languageCode,
          includeSymbol: includeSymbol,
        ),
        style: style,
      ),
    );
  }
}
