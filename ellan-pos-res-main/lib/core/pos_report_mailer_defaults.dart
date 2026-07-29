/// Fixed Ellan POS system mailers (IONOS).
///
/// Gateway is the source of truth for non-secret fields (host/port/user/from).
/// Password is never synced from the server — it is only used locally when the
/// tablet must send mail offline, and is never editable in the UI.
class PosReportMailerDefaults {
  static const host = 'smtp.ionos.com';
  static const port = 587;
  static const useTls = true;
  static const username = 'ellanpos-reports@ellantec.com';

  /// Local-only. Never write this into a sync payload or UI field.
  static const password = 'Ellan@Report2021';

  static const fromEmail = 'ellanpos-reports@ellantec.com';
  static const reportsFromName = 'Ellan POS Reports';
  static const invoicesFromName = 'Ellan POS Invoices';

  static const purpose = 'sales_reports';
  static const invoicePurpose = 'invoice_booking';

  /// @Deprecated Use [reportsFromName].
  static const fromName = reportsFromName;

  static bool isLockedPurpose(String purpose) {
    final p = purpose.trim().toLowerCase();
    return p == PosReportMailerDefaults.purpose ||
        p == PosReportMailerDefaults.invoicePurpose;
  }

  static List<Map<String, dynamic>> localPublicRows() => [
        {
          'purpose': purpose,
          'host': host,
          'port': port,
          'username': username,
          'from_email': fromEmail,
          'from_name': reportsFromName,
          'use_tls': useTls,
          'locked': true,
        },
        {
          'purpose': invoicePurpose,
          'host': host,
          'port': port,
          'username': username,
          'from_email': fromEmail,
          'from_name': invoicesFromName,
          'use_tls': useTls,
          'locked': true,
        },
      ];
}
