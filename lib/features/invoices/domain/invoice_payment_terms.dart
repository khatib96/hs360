/// UI-only payment terms selection for the invoice form.
///
/// This drives presentation only (helper text vs. due-date field). It is NOT
/// sent to the backend: the invoice posting RPCs do not accept a payment
/// method, so [cash] never fakes an immediate cash/bank collection. Real
/// payment posting (immediate cash/bank, installments, reminders) is tracked
/// as future scope in `ai_memory.md`.
enum InvoicePaymentTerms {
  /// Cash / immediate. Payment is recorded later from vouchers.
  cash,

  /// Credit. Uses the existing due-date field.
  credit,
}
