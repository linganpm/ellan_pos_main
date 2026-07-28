/// Human-facing customer/staff identity for UI labels.
///
/// Prefers registration number over internal backend ids like `user_10`.
String displayCustomerIdentity({
  String? regNum,
  String? customerId,
  String? email,
  String fallback = '',
}) {
  final reg = (regNum ?? '').trim();
  if (reg.isNotEmpty) return reg;
  final id = (customerId ?? '').trim();
  if (id.isNotEmpty && !id.toLowerCase().startsWith('user_')) return id;
  final mail = (email ?? '').trim();
  if (mail.isNotEmpty) return mail;
  if (id.isNotEmpty) return id;
  return fallback;
}
