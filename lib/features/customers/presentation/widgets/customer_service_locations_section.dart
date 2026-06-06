import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/message_banner.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../domain/customer_permissions.dart';
import '../../domain/customer_service_location.dart';
import '../customer_error_messages.dart';
import '../customer_locations_controller.dart';
import '../service_location_coordinate_labels.dart';
import '../service_location_type_labels.dart';
import 'customer_service_location_form_dialog.dart';

class CustomerServiceLocationsSection extends ConsumerWidget {
  const CustomerServiceLocationsSection({required this.customerId, super.key});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(authControllerProvider).valueOrNull;
    final canEdit = session != null && canEditCustomer(session);
    final state = ref.watch(customerLocationsControllerProvider(customerId));
    final notifier = ref.read(
      customerLocationsControllerProvider(customerId).notifier,
    );

    if (state.isLoading && state.locations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final active = state.activeLocations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.errorCode != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
            child: MessageBanner(
              variant: MessageBannerVariant.error,
              message: customerErrorMessage(l10n, state.errorCode!),
            ),
          ),
        if (canEdit)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.icon(
                onPressed: state.isMutating
                    ? null
                    : () => _onAdd(context, ref, notifier),
                icon: const Icon(Icons.add),
                label: Text(l10n.serviceLocationAdd),
              ),
            ),
          ),
        Expanded(
          child: active.isEmpty
              ? Center(
                  child: Text(
                    l10n.serviceLocationEmpty,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsetsDirectional.all(16),
                  itemCount: active.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final location = active[index];
                    return _LocationCard(
                      location: location,
                      canEdit: canEdit,
                      isMutating: state.isMutating,
                      onEdit: () => _onEdit(context, ref, notifier, location),
                      onDeactivate: () =>
                          _onDeactivate(context, ref, notifier, location),
                      onSetPrimary: location.isPrimary
                          ? null
                          : () =>
                                _onSetPrimary(context, ref, notifier, location),
                      onOpenMaps:
                          location.googleMapsUrl?.trim().isNotEmpty == true
                          ? () =>
                                _copyMapsLink(context, location.googleMapsUrl!)
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _onAdd(
    BuildContext context,
    WidgetRef ref,
    CustomerLocationsController notifier,
  ) async {
    final form = await showCustomerServiceLocationFormDialog(context);
    if (form == null || !context.mounted) return;
    final code = await notifier.createLocation(form);
    if (code != null && context.mounted) {
      showServiceLocationErrorSnackBar(context, code);
    }
  }

  Future<void> _onEdit(
    BuildContext context,
    WidgetRef ref,
    CustomerLocationsController notifier,
    CustomerServiceLocation location,
  ) async {
    final form = await showCustomerServiceLocationFormDialog(
      context,
      initial: location,
    );
    if (form == null || !context.mounted) return;
    final code = await notifier.updateLocation(location.id, form);
    if (code != null && context.mounted) {
      showServiceLocationErrorSnackBar(context, code);
    }
  }

  Future<void> _onDeactivate(
    BuildContext context,
    WidgetRef ref,
    CustomerLocationsController notifier,
    CustomerServiceLocation location,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.serviceLocationDeactivate),
        content: Text('${location.name} (${location.code})'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.serviceLocationDeactivate),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final code = await notifier.deactivateLocation(location.id);
    if (code != null && context.mounted) {
      showServiceLocationErrorSnackBar(context, code);
    }
  }

  Future<void> _onSetPrimary(
    BuildContext context,
    WidgetRef ref,
    CustomerLocationsController notifier,
    CustomerServiceLocation location,
  ) async {
    final code = await notifier.setPrimary(location.id);
    if (code != null && context.mounted) {
      showServiceLocationErrorSnackBar(context, code);
    }
  }

  void _copyMapsLink(BuildContext context, String url) {
    final l10n = AppLocalizations.of(context)!;
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.serviceLocationMapsCopied)));
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.location,
    required this.canEdit,
    required this.isMutating,
    required this.onEdit,
    required this.onDeactivate,
    this.onSetPrimary,
    this.onOpenMaps,
  });

  final CustomerServiceLocation location;
  final bool canEdit;
  final bool isMutating;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;
  final VoidCallback? onSetPrimary;
  final VoidCallback? onOpenMaps;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final summary = location.locationSummary();

    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    location.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (location.isPrimary)
                  Chip(
                    label: Text(l10n.serviceLocationPrimary),
                    visualDensity: VisualDensity.compact,
                  ),
                const SizedBox(width: 8),
                Text(
                  location.code,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(serviceLocationTypeLabel(l10n, location.locationType)),
            if (summary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(summary),
            ],
            if (location.hasCoordinates) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsetsDirectional.only(top: 2),
                    child: Icon(Icons.location_on_outlined, size: 18),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${location.latitude!.toStringAsFixed(6)}, '
                          '${location.longitude!.toStringAsFixed(6)}',
                        ),
                        if (location.resolutionSource != null ||
                            location.resolvedAt != null ||
                            location.coordinateAccuracyM != null)
                          Text(
                            _coordinateMetadata(context, location),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            if (location.contactPersonName?.isNotEmpty == true ||
                location.contactPersonPhone?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                [
                  if (location.contactPersonName?.isNotEmpty == true)
                    location.contactPersonName!,
                  if (location.contactPersonPhone?.isNotEmpty == true)
                    location.contactPersonPhone!,
                ].join(' · '),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onOpenMaps != null)
                  OutlinedButton.icon(
                    onPressed: isMutating ? null : onOpenMaps,
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: Text(l10n.serviceLocationOpenMaps),
                  ),
                if (canEdit) ...[
                  OutlinedButton(
                    onPressed: isMutating ? null : onEdit,
                    child: Text(l10n.serviceLocationEdit),
                  ),
                  if (onSetPrimary != null)
                    OutlinedButton(
                      onPressed: isMutating ? null : onSetPrimary,
                      child: Text(l10n.serviceLocationSetPrimary),
                    ),
                  TextButton(
                    onPressed: isMutating ? null : onDeactivate,
                    child: Text(l10n.serviceLocationDeactivate),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _coordinateMetadata(
    BuildContext context,
    CustomerServiceLocation location,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return [
      if (location.resolutionSource != null)
        '${l10n.serviceLocationCoordinateSource}: '
            '${coordinateResolutionSourceLabel(l10n, location.resolutionSource!)}',
      if (location.coordinateAccuracyM != null)
        l10n.serviceLocationCoordinateAccuracy(
          location.coordinateAccuracyM!.toStringAsFixed(1),
        ),
      if (location.resolvedAt != null)
        '${l10n.serviceLocationCoordinateResolvedAt}: '
            '${DateFormat.yMMMd(locale).add_jm().format(location.resolvedAt!.toLocal())}',
    ].join(' · ');
  }
}
