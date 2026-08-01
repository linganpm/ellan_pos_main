/// Encodes checkout extras into `orders.created_by` so staff + tips/tax can
/// be shown later without a schema migration.
class PosCheckoutMeta {
  final String staffName;
  final String staffReg;
  final double tips;
  final double serviceTax;
  final double discount;
  final double delivery;
  final double previousBalance;

  const PosCheckoutMeta({
    this.staffName = '',
    this.staffReg = '',
    this.tips = 0,
    this.serviceTax = 0,
    this.discount = 0,
    this.delivery = 0,
    this.previousBalance = 0,
  });

  static const _sep = '|';

  String encode() {
    final parts = <String>[
      _sanitize(staffName),
      _sanitize(staffReg),
      if (tips > 0.0001) 'tips=${tips.toStringAsFixed(2)}',
      if (serviceTax > 0.0001) 'tax=${serviceTax.toStringAsFixed(2)}',
      if (discount > 0.0001) 'disc=${discount.toStringAsFixed(2)}',
      if (delivery > 0.0001) 'del=${delivery.toStringAsFixed(2)}',
      if (previousBalance.abs() > 0.0001)
        'prev=${previousBalance.toStringAsFixed(2)}',
    ];
    return parts.join(_sep);
  }

  static PosCheckoutMeta parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const PosCheckoutMeta();
    }
    if (!trimmed.contains(_sep) &&
        !trimmed.contains('tips=') &&
        !trimmed.contains('tax=')) {
      return PosCheckoutMeta(staffName: trimmed);
    }

    final parts = trimmed.split(_sep);
    var name = '';
    var reg = '';
    var tips = 0.0;
    var tax = 0.0;
    var disc = 0.0;
    var del = 0.0;
    var previousBalance = 0.0;
    var indexed = 0;
    for (final part in parts) {
      final piece = part.trim();
      if (piece.isEmpty) continue;
      if (piece.startsWith('tips=')) {
        tips = double.tryParse(piece.substring(5)) ?? 0;
      } else if (piece.startsWith('tax=')) {
        tax = double.tryParse(piece.substring(4)) ?? 0;
      } else if (piece.startsWith('disc=')) {
        disc = double.tryParse(piece.substring(5)) ?? 0;
      } else if (piece.startsWith('del=')) {
        del = double.tryParse(piece.substring(4)) ?? 0;
      } else if (piece.startsWith('prev=')) {
        previousBalance = double.tryParse(piece.substring(5)) ?? 0;
      } else if (indexed == 0) {
        name = piece;
        indexed++;
      } else if (indexed == 1) {
        reg = piece;
        indexed++;
      }
    }
    return PosCheckoutMeta(
      staffName: name,
      staffReg: reg,
      tips: tips,
      serviceTax: tax,
      discount: disc,
      delivery: del,
      previousBalance: previousBalance,
    );
  }

  String get displayStaffName =>
      staffName.trim().isEmpty ? '—' : staffName.trim();

  String get displayStaffReg => staffReg.trim();

  static String _sanitize(String value) =>
      value.trim().replaceAll(_sep, ' ').replaceAll('\n', ' ');
}
