/// Fixed POS payment-method variants (no payment gateways).
///
/// IDs match master-data `org_wallet_variants.sql` and
/// `prod_mgmt_be.pos_gateway.wallet_variant_defaults`.
/// Default on new branches: Cash, Card, UPI, Credit.
class PosWalletVariantDefaults {
  static const List<Map<String, dynamic>> catalogue = [
    {
      'id': 1,
      'key': 'cash',
      'name': 'Cash',
      'type': 1,
      'type_name': 'Cash',
      'locked': true,
      'default_on_branch': true,
    },
    {
      'id': 2,
      'key': 'card',
      'name': 'Card',
      'type': 3,
      'type_name': 'Bank',
      'locked': true,
      'default_on_branch': true,
    },
    {
      'id': 4,
      'key': 'ewallet',
      'name': 'E-Wallet',
      'type': 4,
      'type_name': 'E-Wallet',
      'locked': true,
      'default_on_branch': false,
    },
    {
      'id': 5,
      'key': 'upi',
      'name': 'UPI',
      'type': 5,
      'type_name': 'UPI',
      'locked': true,
      'default_on_branch': true,
    },
    {
      'id': 12,
      'key': 'credit',
      'name': 'Credit',
      'type': 1,
      'type_name': 'Cash',
      'locked': true,
      'default_on_branch': true,
    },
    {
      'id': 13,
      'key': 'pay_later',
      'name': 'Pay Later',
      'type': 1,
      'type_name': 'Cash',
      'locked': true,
      'default_on_branch': false,
    },
  ];

  static const Set<int> ids = {1, 2, 4, 5, 12, 13};

  static const Set<String> defaultBranchKeys = {
    'cash',
    'card',
    'upi',
    'credit',
  };

  static List<Map<String, dynamic>> get defaultBranchVariants => [
    for (final row in catalogue)
      if (row['default_on_branch'] == true) Map<String, dynamic>.from(row),
  ];

  /// Prefer gateway rows; fill any missing fixed ids from the local catalogue.
  static List<Map<String, dynamic>> mergeWithRemote(
    List<Map<String, dynamic>> remote,
  ) {
    final byId = <int, Map<String, dynamic>>{};
    for (final row in catalogue) {
      final id = row['id'] as int;
      byId[id] = Map<String, dynamic>.from(row);
    }
    for (final row in remote) {
      final id = (row['id'] as num?)?.toInt();
      if (id == null || !ids.contains(id)) continue;
      byId[id] = {...byId[id]!, ...Map<String, dynamic>.from(row), 'id': id};
    }
    return [for (final row in catalogue) byId[row['id'] as int]!];
  }
}
