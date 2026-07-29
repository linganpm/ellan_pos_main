/// Measurable sell units from product-variant proportions (Kg, Litre, Meter…).
class SellUnitInfo {
  final int unitCode;
  final String unitLabel;
  final String unitShort;
  final double baseQty;

  const SellUnitInfo({
    required this.unitCode,
    required this.unitLabel,
    required this.unitShort,
    required this.baseQty,
  });
}

const Map<int, String> kMeasurableSellUnitShort = {
  1: 'kg',
  2: 'g',
  3: 'L',
  4: 'mL',
  5: 'cm',
  6: 'in',
  7: 'm',
};

const Map<int, String> kMeasurableSellUnitLong = {
  1: 'Kilogram',
  2: 'Gram',
  3: 'Litre',
  4: 'Millilitre',
  5: 'Centimetre',
  6: 'Inch',
  7: 'Meter',
};

SellUnitInfo? resolveSellUnitFromProportions(dynamic raw) {
  if (raw is! List) return null;
  for (final entry in raw) {
    if (entry is! Map) continue;
    final row = entry.cast<String, dynamic>();
    final active = row['active'];
    if (active == 0 || active == false || active == '0') continue;
    final proportionData = row['proportion_data'] is Map
        ? (row['proportion_data'] as Map).cast<String, dynamic>()
        : row;
    final unitCode = int.tryParse(
      '${proportionData['unit'] ?? row['unit'] ?? ''}',
    );
    if (unitCode == null || !kMeasurableSellUnitShort.containsKey(unitCode)) {
      continue;
    }
    final baseQty =
        double.tryParse(
          '${proportionData['quantity'] ?? row['quantity'] ?? proportionData['value'] ?? row['value'] ?? ''}',
        ) ??
        1.0;
    if (baseQty <= 0) continue;
    final short = kMeasurableSellUnitShort[unitCode]!;
    final label = (proportionData['label'] ?? row['label'] ?? '')
        .toString()
        .trim();
    return SellUnitInfo(
      unitCode: unitCode,
      unitLabel: label.isEmpty
          ? (kMeasurableSellUnitLong[unitCode] ?? short)
          : label,
      unitShort: short,
      baseQty: baseQty,
    );
  }
  return null;
}

String formatSellQty(double qty) {
  if (qty == qty.roundToDouble()) return '${qty.toInt()}';
  return qty
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String formatSellQtyWithUnit(double qty, SellUnitInfo? unit) {
  final text = formatSellQty(qty);
  if (unit == null) return text;
  return '$text ${unit.unitShort}';
}

double sellUnitBillableQty(double enteredQty, SellUnitInfo? unit) {
  if (enteredQty <= 0) return 0;
  if (unit == null || unit.baseQty <= 0) return enteredQty;
  return (enteredQty / unit.baseQty).ceilToDouble();
}

/// Line total: sell_price × ceil(qty / sell_unit_qty).
/// Example: £10 for 4kg, buy 5kg → £20.
double computeSellLineTotal(
  double unitPrice,
  double enteredQty,
  SellUnitInfo? unit,
) {
  return unitPrice * sellUnitBillableQty(enteredQty, unit);
}
