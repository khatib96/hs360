/// Asset return condition for trial return and rental closure RPCs.
enum ContractReturnCondition {
  availableUsed('available_used'),
  maintenance('maintenance'),
  damaged('damaged'),
  lost('lost');

  const ContractReturnCondition(this.dbValue);

  final String dbValue;

  static ContractReturnCondition fromDb(String? value) {
    if (value == null) {
      throw FormatException('ContractReturnCondition value is null');
    }
    for (final condition in ContractReturnCondition.values) {
      if (condition.dbValue == value) return condition;
    }
    throw FormatException('Unknown ContractReturnCondition: $value');
  }

  String toDb() => dbValue;
}

/// Rental contract closure type for `close_contract`.
enum ContractClosureType {
  normal('normal'),
  earlyTermination('early_termination');

  const ContractClosureType(this.dbValue);

  final String dbValue;

  static ContractClosureType fromDb(String? value) {
    if (value == null) {
      throw FormatException('ContractClosureType value is null');
    }
    for (final type in ContractClosureType.values) {
      if (type.dbValue == value) return type;
    }
    throw FormatException('Unknown ContractClosureType: $value');
  }

  String toDb() => dbValue;
}
