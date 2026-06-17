import '../domain/journal_entry_detail.dart';

class JournalDetailState {
  const JournalDetailState({
    this.isLoading = false,
    this.detail,
    this.errorCode,
  });

  final bool isLoading;
  final JournalEntryDetail? detail;
  final String? errorCode;

  bool get hasError => errorCode != null;

  JournalDetailState copyWith({
    bool? isLoading,
    JournalEntryDetail? detail,
    String? errorCode,
    bool clearError = false,
  }) {
    return JournalDetailState(
      isLoading: isLoading ?? this.isLoading,
      detail: detail ?? this.detail,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
    );
  }
}
