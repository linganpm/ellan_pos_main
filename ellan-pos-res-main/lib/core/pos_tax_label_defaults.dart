/// Offline fallback tax bands when the gateway catalogue is unreachable.
///
/// Prefer live rows from `GET /api/pos/store/taxes` (seeded from the country
/// tax catalogue on company signup). These are only used when that list is empty.
class PosTaxLabelDefaults {
  PosTaxLabelDefaults._();

  static const List<Map<String, dynamic>> common = [
    {
      'local_id': 'tax-fallback-0',
      'name': 'Tax 0%',
      'total_percentage': 0.0,
    },
    {
      'local_id': 'tax-fallback-5',
      'name': 'Tax 5%',
      'total_percentage': 5.0,
    },
    {
      'local_id': 'tax-fallback-12',
      'name': 'Tax 12%',
      'total_percentage': 12.0,
    },
    {
      'local_id': 'tax-fallback-18',
      'name': 'Tax 18%',
      'total_percentage': 18.0,
    },
    {
      'local_id': 'tax-fallback-28',
      'name': 'Tax 28%',
      'total_percentage': 28.0,
    },
  ];
}
