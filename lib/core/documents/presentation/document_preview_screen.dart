import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:typed_data';
import 'package:hs360/l10n/app_localizations.dart';
import 'package:printing/printing.dart';

import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/message_banner.dart';
import '../../routing/app_routes.dart';
import 'document_error_messages.dart';
import 'document_preview_controller.dart';
import 'document_preview_state.dart';

class DocumentPreviewScreen extends ConsumerWidget {
  const DocumentPreviewScreen({required this.args, super.key});

  final DocumentPreviewArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(documentPreviewControllerProvider(args));
    final notifier = ref.read(documentPreviewControllerProvider(args).notifier);

    return AppShell(
      title: l10n.documentPreviewTitle,
      currentRoute: AppRoutes.documentPreview,
      body: _buildBody(context, l10n, state, notifier),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    DocumentPreviewState state,
    DocumentPreviewController notifier,
  ) {
    if (state.permissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: MessageBanner(
            key: const Key('document-preview-denied'),
            variant: MessageBannerVariant.info,
            message: l10n.documentPreviewPermissionDenied,
          ),
        ),
      );
    }

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorCode != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MessageBanner(
                variant: MessageBannerVariant.error,
                message: documentErrorMessage(l10n, state.errorCode!),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('document-preview-retry'),
                onPressed: () => notifier.load(force: true),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    final result = state.renderResult;
    if (result == null) {
      return Center(child: Text(l10n.documentPreviewEmpty));
    }

    return PdfPreview(
      key: const Key('document-preview-pdf'),
      canChangePageFormat: false,
      canChangeOrientation: false,
      allowPrinting: state.canExport,
      allowSharing: state.canExport,
      maxPageWidth: 700,
      pdfFileName: '${result.title.replaceAll(' ', '_')}.pdf',
      build: (format) async => Uint8List.fromList(result.bytes),
    );
  }
}
