class UnitTimelineEvent {
  const UnitTimelineEvent({
    required this.tenantId,
    required this.productUnitId,
    required this.eventType,
    required this.occurredAt,
    this.sourceTable,
    this.sourceId,
    this.warehouseId,
    this.customerId,
    this.serviceLocationId,
    this.contractId,
    required this.titleKey,
    this.notes,
    this.metadataJson,
  });

  final String tenantId;
  final String productUnitId;
  final String eventType;
  final DateTime occurredAt;
  final String? sourceTable;
  final String? sourceId;
  final String? warehouseId;
  final String? customerId;
  final String? serviceLocationId;
  final String? contractId;
  final String titleKey;
  final String? notes;
  final Map<String, dynamic>? metadataJson;

  factory UnitTimelineEvent.fromRow(Map<String, dynamic> row) {
    return UnitTimelineEvent(
      tenantId: row['tenant_id'] as String,
      productUnitId: row['product_unit_id'] as String,
      eventType: row['event_type'] as String,
      occurredAt: DateTime.parse(row['occurred_at'] as String),
      sourceTable: row['source_table'] as String?,
      sourceId: row['source_id'] as String?,
      warehouseId: row['warehouse_id'] as String?,
      customerId: row['customer_id'] as String?,
      serviceLocationId: row['service_location_id'] as String?,
      contractId: row['contract_id'] as String?,
      titleKey: row['title_key'] as String,
      notes: row['notes'] as String?,
      metadataJson: row['metadata_json'] != null
          ? Map<String, dynamic>.from(row['metadata_json'] as Map)
          : null,
    );
  }
}
