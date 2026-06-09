import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/documents/data/document_providers.dart';
import '../../../core/documents/data/document_template_repository.dart';
import '../../../core/documents/data/logo_loader.dart';
import '../../../core/documents/domain/document_kind.dart';
import '../../../core/documents/domain/document_permissions.dart';
import '../../../core/errors/document_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import 'template_settings_state.dart';

part 'template_settings_controller.g.dart';

@riverpod
class TemplateSettingsController extends _$TemplateSettingsController {
  @override
  TemplateSettingsState build() {
    Future.microtask(load);
    return const TemplateSettingsState(isLoading: true);
  }

  Future<void> load({bool force = false}) async {
    if (!force && state.settings != null) return;

    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null || !canViewTemplateSettings(session)) {
      state = const TemplateSettingsState(
        isLoading: false,
        permissionDenied: true,
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final settings = await ref
          .read(documentTemplateRepositoryProvider)
          .fetchTenantDocumentSettings();
      state = TemplateSettingsState(
        isLoading: false,
        canEdit: canEditTemplateSettings(session),
        settings: settings,
        logoUrl: settings.logoUrl ?? '',
        primaryColor: settings.primaryColor ?? '',
        secondaryColor: settings.secondaryColor ?? '',
        defaultLanguage: settings.defaultLanguage,
        invoicePaperKind: settings.invoicePaperKind,
        voucherPaperKind: settings.voucherPaperKind,
        assetLabelPaperKind: settings.assetLabelPaperKind,
        headerTextAr: settings.headerJson['text_ar'] as String? ?? '',
        headerTextEn: settings.headerJson['text_en'] as String? ?? '',
        footerTextAr: settings.footerJson['text_ar'] as String? ?? '',
        footerTextEn: settings.footerJson['text_en'] as String? ?? '',
        optionalColumns: TemplateSettingsState.optionalColumnsFromSettings(
          settings.optionalColumnsJson,
        ),
      );
    } on DocumentException catch (e) {
      state = state.copyWith(isLoading: false, errorCode: e.code);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorCode: DocumentException.unknown,
      );
    }
  }

  void updateLogoUrl(String value) {
    state = state.copyWith(logoUrl: value, saveSuccess: false);
  }

  void updatePrimaryColor(String value) {
    state = state.copyWith(primaryColor: value, saveSuccess: false);
  }

  void updateSecondaryColor(String value) {
    state = state.copyWith(secondaryColor: value, saveSuccess: false);
  }

  void updateDefaultLanguage(DocumentLanguageMode value) {
    state = state.copyWith(defaultLanguage: value, saveSuccess: false);
  }

  void updateVoucherPaperKind(PaperKind value) {
    state = state.copyWith(voucherPaperKind: value, saveSuccess: false);
  }

  void updateHeaderTextAr(String value) {
    state = state.copyWith(headerTextAr: value, saveSuccess: false);
  }

  void updateHeaderTextEn(String value) {
    state = state.copyWith(headerTextEn: value, saveSuccess: false);
  }

  void updateFooterTextAr(String value) {
    state = state.copyWith(footerTextAr: value, saveSuccess: false);
  }

  void updateFooterTextEn(String value) {
    state = state.copyWith(footerTextEn: value, saveSuccess: false);
  }

  void updateOptionalColumn(String docType, String field, bool enabled) {
    final next = Map<String, Map<String, bool>>.from(
      state.optionalColumns.map(
        (key, value) => MapEntry(key, Map<String, bool>.from(value)),
      ),
    );
    final fields = Map<String, bool>.from(next[docType] ?? {});
    fields[field] = enabled;
    next[docType] = fields;
    state = state.copyWith(optionalColumns: next, saveSuccess: false);
  }

  Future<void> save() async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null || !canEditTemplateSettings(session)) return;

    state = state.copyWith(
      isSaving: true,
      clearSaveError: true,
      saveSuccess: false,
    );

    final trimmedLogo = state.logoUrl.trim();
    if (trimmedLogo.isNotEmpty) {
      try {
        await ref.read(logoLoaderProvider).loadValidated(trimmedLogo);
      } on LogoLoadException catch (e) {
        state = state.copyWith(isSaving: false, saveErrorCode: e.code);
        return;
      } catch (_) {
        state = state.copyWith(
          isSaving: false,
          saveErrorCode: NetworkLogoLoader.fetchFailed,
        );
        return;
      }
    }

    try {
      final patch = <String, dynamic>{
        'logo_url': trimmedLogo,
        'primary_color': state.primaryColor.trim().isEmpty
            ? null
            : state.primaryColor.trim(),
        'secondary_color': state.secondaryColor.trim().isEmpty
            ? null
            : state.secondaryColor.trim(),
        'default_language': state.defaultLanguage.value,
        'voucher_paper_kind': state.voucherPaperKind.value,
        'header_json': {
          if (state.headerTextAr.trim().isNotEmpty)
            'text_ar': state.headerTextAr.trim(),
          if (state.headerTextEn.trim().isNotEmpty)
            'text_en': state.headerTextEn.trim(),
        },
        'footer_json': {
          if (state.footerTextAr.trim().isNotEmpty)
            'text_ar': state.footerTextAr.trim(),
          if (state.footerTextEn.trim().isNotEmpty)
            'text_en': state.footerTextEn.trim(),
        },
        'optional_columns_json': state.optionalColumns,
      };

      final settings = await ref
          .read(documentTemplateRepositoryProvider)
          .upsertTenantDocumentSettings(patch);

      state = state.copyWith(
        isSaving: false,
        settings: settings,
        saveSuccess: true,
      );
    } on DocumentException catch (e) {
      state = state.copyWith(isSaving: false, saveErrorCode: e.code);
    } catch (_) {
      state = state.copyWith(
        isSaving: false,
        saveErrorCode: DocumentException.unknown,
      );
    }
  }
}
