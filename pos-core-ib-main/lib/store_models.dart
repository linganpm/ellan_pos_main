class StoreScope {
  final String orgId;
  final String storeId;

  const StoreScope({required this.orgId, required this.storeId});

  Map<String, dynamic> toRow() {
    return {'orgId': orgId, 'storeId': storeId};
  }
}

class StoreOrganisation {
  final String orgId;
  final String? remoteId;
  final String orgName;
  final String orgCode;
  final String logo;

  /// 4-digit POS code assigned by the gateway; namespaces uploaded orders.
  final String posCode;

  const StoreOrganisation({
    required this.orgId,
    required this.remoteId,
    required this.orgName,
    required this.orgCode,
    required this.logo,
    this.posCode = '',
  });

  factory StoreOrganisation.fromRow(Map<String, dynamic> row) {
    return StoreOrganisation(
      orgId: row['orgId'] as String? ?? '',
      remoteId: row['remote_id'] as String?,
      orgName: row['org_name'] as String? ?? row['orgName'] as String? ?? '',
      orgCode: row['org_code'] as String? ?? row['orgCode'] as String? ?? '',
      logo: row['logo'] as String? ?? '',
      posCode: row['pos_code'] as String? ?? row['posCode'] as String? ?? '',
    );
  }

  Map<String, dynamic> toRow() {
    return {
      'orgId': orgId,
      'remote_id': remoteId,
      'org_name': orgName,
      'org_code': orgCode,
      'logo': logo,
      if (posCode.isNotEmpty) 'pos_code': posCode,
    };
  }
}

class StoreDirectoryEntry {
  final String orgId;
  final String orgName;
  final String orgCode;
  final String storeId;
  final String? remoteId;
  final int serviceInstanceId;
  final String storeName;
  final String logo;
  final String uniqueId;
  final String contactEmail;
  final String phone;
  final String contactPerson;
  final String status;
  final String serviceVariantType;
  final String address;
  final String registrationNumber;
  final String taxNumber;
  final String identifier;

  const StoreDirectoryEntry({
    required this.orgId,
    required this.orgName,
    required this.orgCode,
    required this.storeId,
    required this.remoteId,
    required this.serviceInstanceId,
    required this.storeName,
    required this.logo,
    required this.uniqueId,
    required this.contactEmail,
    required this.phone,
    required this.contactPerson,
    required this.status,
    required this.serviceVariantType,
    this.address = '',
    this.registrationNumber = '',
    this.taxNumber = '',
    this.identifier = '',
  });

  factory StoreDirectoryEntry.fromRow(Map<String, dynamic> row) {
    return StoreDirectoryEntry(
      orgId: row['orgId'] as String? ?? row['org_id'] as String? ?? '',
      orgName: row['org_name'] as String? ?? row['orgName'] as String? ?? '',
      orgCode: row['org_code'] as String? ?? row['orgCode'] as String? ?? '',
      storeId: row['storeId'] as String? ?? row['store_id'] as String? ?? '',
      remoteId: row['remote_id'] as String?,
      serviceInstanceId:
          (row['serviceInstanceId'] as num?)?.toInt() ??
          (row['service_instance_id'] as num?)?.toInt() ??
          0,
      storeName:
          row['storeName'] as String? ?? row['store_name'] as String? ?? '',
      logo: row['logo'] as String? ?? '',
      uniqueId: row['uniqueId'] as String? ?? row['unique_id'] as String? ?? '',
      contactEmail:
          row['contactEmail'] as String? ??
          row['contact_email'] as String? ??
          '',
      phone: row['phone'] as String? ?? '',
      contactPerson:
          row['contactPerson'] as String? ??
          row['contact_person'] as String? ??
          '',
      status: row['status'] as String? ?? '',
      serviceVariantType:
          row['serviceVariantType'] as String? ??
          row['service_variant_type'] as String? ??
          '',
      address: row['address'] as String? ?? row['location'] as String? ?? '',
      registrationNumber:
          row['registration_number'] as String? ??
          row['company_registration_number'] as String? ??
          '',
      taxNumber:
          row['tax_number'] as String? ??
          row['company_tax_number'] as String? ??
          '',
      identifier: row['identifier'] as String? ?? '',
    );
  }

  Map<String, dynamic> toRow() {
    return {
      'orgId': orgId,
      'org_name': orgName,
      'org_code': orgCode,
      'storeId': storeId,
      'remote_id': remoteId,
      'serviceInstanceId': serviceInstanceId,
      'storeName': storeName,
      'logo': logo,
      'uniqueId': uniqueId,
      'contactEmail': contactEmail,
      'phone': phone,
      'contactPerson': contactPerson,
      'status': status,
      'serviceVariantType': serviceVariantType,
      'address': address,
      'registration_number': registrationNumber,
      'tax_number': taxNumber,
      'identifier': identifier,
    };
  }
}

class StoreRoleAccess {
  final String customerId;
  final String orgId;
  final String storeId;
  final String? remoteId;
  final String storeRole;
  final bool accessEnabled;

  const StoreRoleAccess({
    required this.customerId,
    required this.orgId,
    required this.storeId,
    required this.remoteId,
    required this.storeRole,
    required this.accessEnabled,
  });

  String get role => storeRole;

  factory StoreRoleAccess.fromRow(Map<String, dynamic> row) {
    final accessValue = row['access_enabled'];
    return StoreRoleAccess(
      customerId: row['customerId'] as String? ?? '',
      orgId: row['orgId'] as String? ?? '',
      storeId: row['storeId'] as String? ?? '',
      remoteId: row['remote_id'] as String?,
      storeRole: row['role'] as String? ?? '',
      accessEnabled: accessValue is bool
          ? accessValue
          : ((accessValue as num?)?.toInt() ?? 0) == 1,
    );
  }

  Map<String, dynamic> toRow() {
    return {
      'customerId': customerId,
      'orgId': orgId,
      'storeId': storeId,
      'remote_id': remoteId,
      'role': storeRole,
      'access_enabled': accessEnabled,
    };
  }
}

class StoreAccessibleStore {
  final StoreDirectoryEntry store;
  final StoreRoleAccess access;

  const StoreAccessibleStore({required this.store, required this.access});
}

class StoreOrganisationLoginResult {
  final StoreOrganisation organisation;
  final String customerId;
  final String customerName;
  final String email;
  final String organisationRole;
  final List<StoreAccessibleStore> accessibleStores;
  final Map<String, dynamic>? customerRow;

  /// Org JWT from `/api/pos/login` — used for online staff/admin APIs.
  final String? accessToken;
  final String? refreshToken;
  final String? sessionId;

  /// Tenant/org service instance id (string or numeric) from login.
  final String? serviceInstanceId;

  const StoreOrganisationLoginResult({
    required this.organisation,
    required this.customerId,
    required this.customerName,
    required this.email,
    required this.organisationRole,
    required this.accessibleStores,
    this.customerRow,
    this.accessToken,
    this.refreshToken,
    this.sessionId,
    this.serviceInstanceId,
  });

  Map<String, dynamic> toJson() {
    return {
      'organisation': organisation.toRow(),
      'customerId': customerId,
      'customerName': customerName,
      'email': email,
      'organisationRole': organisationRole,
      'accessibleStores': [
        for (final entry in accessibleStores)
          {'store': entry.store.toRow(), 'access': entry.access.toRow()},
      ],
      if (customerRow != null) 'customer': customerRow,
      if (accessToken != null && accessToken!.isNotEmpty)
        'access_token': accessToken,
      if (refreshToken != null && refreshToken!.isNotEmpty)
        'refresh_token': refreshToken,
      if (sessionId != null && sessionId!.isNotEmpty) 'session_id': sessionId,
      if (serviceInstanceId != null && serviceInstanceId!.isNotEmpty)
        'service_instance_id': serviceInstanceId,
    };
  }

  factory StoreOrganisationLoginResult.fromJson(Map<String, dynamic> json) {
    final accessibleRaw = json['accessibleStores'];
    final accessibleStores = <StoreAccessibleStore>[];
    if (accessibleRaw is List) {
      for (final entry in accessibleRaw) {
        if (entry is! Map) continue;
        final row = entry.cast<String, dynamic>();
        final storeRaw = row['store'];
        final accessRaw = row['access'];
        if (storeRaw is! Map || accessRaw is! Map) continue;
        accessibleStores.add(
          StoreAccessibleStore(
            store: StoreDirectoryEntry.fromRow(
              storeRaw.cast<String, dynamic>(),
            ),
            access: StoreRoleAccess.fromRow(accessRaw.cast<String, dynamic>()),
          ),
        );
      }
    }
    final organisationRaw = json['organisation'];
    final si = json['service_instance_id'];
    return StoreOrganisationLoginResult(
      organisation: organisationRaw is Map
          ? StoreOrganisation.fromRow(organisationRaw.cast<String, dynamic>())
          : const StoreOrganisation(
              orgId: '',
              remoteId: null,
              orgName: '',
              orgCode: '',
              logo: '',
            ),
      customerId: json['customerId'] as String? ?? '',
      customerName: json['customerName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      organisationRole: json['organisationRole'] as String? ?? '',
      accessibleStores: accessibleStores,
      customerRow: json['customer'] is Map
          ? (json['customer'] as Map).cast<String, dynamic>()
          : null,
      accessToken:
          '${json['access_token'] ?? json['accessToken'] ?? ''}'.trim().isEmpty
          ? null
          : '${json['access_token'] ?? json['accessToken']}'.trim(),
      refreshToken:
          '${json['refresh_token'] ?? json['refreshToken'] ?? ''}'
              .trim()
              .isEmpty
          ? null
          : '${json['refresh_token'] ?? json['refreshToken']}'.trim(),
      sessionId:
          '${json['session_id'] ?? json['sessionId'] ?? ''}'.trim().isEmpty
          ? null
          : '${json['session_id'] ?? json['sessionId']}'.trim(),
      serviceInstanceId: si == null
          ? null
          : '$si'.trim().isEmpty
          ? null
          : '$si'.trim(),
    );
  }
}

class StoreDeviceRegistrationRequest {
  final String deviceId;
  final String make;
  final String model;
  final double? lat;
  final double? lan;

  const StoreDeviceRegistrationRequest({
    required this.deviceId,
    required this.make,
    required this.model,
    this.lat,
    this.lan,
  });

  Map<String, dynamic> toJson({required String orgId}) {
    return {
      'orgId': orgId,
      'deviceId': deviceId,
      'make': make,
      'model': model,
      'lat': lat,
      'lan': lan,
    };
  }
}

class StoreDeviceRegistrationResult {
  final String orgId;
  final String deviceId;
  final String make;
  final String model;
  final double? lat;
  final double? lan;
  final String status;
  final String? message;
  final String? registeredAt;
  final String? updatedAt;

  const StoreDeviceRegistrationResult({
    required this.orgId,
    required this.deviceId,
    required this.make,
    required this.model,
    required this.lat,
    required this.lan,
    required this.status,
    required this.message,
    required this.registeredAt,
    required this.updatedAt,
  });

  bool get isActive => status.toLowerCase() == 'active';

  factory StoreDeviceRegistrationResult.fromJson(Map<String, dynamic> json) {
    final payload = json['registration'] is Map<String, dynamic>
        ? json['registration'] as Map<String, dynamic>
        : (json['registration'] is Map
              ? (json['registration'] as Map).cast<String, dynamic>()
              : json);
    return StoreDeviceRegistrationResult(
      orgId:
          _stringFromMap(payload, 'orgId') ??
          _stringFromMap(payload, 'org_id') ??
          '',
      deviceId:
          _stringFromMap(payload, 'deviceId') ??
          _stringFromMap(payload, 'device_id') ??
          '',
      make: _stringFromMap(payload, 'make') ?? '',
      model: _stringFromMap(payload, 'model') ?? '',
      lat: _doubleFromMap(payload, 'lat'),
      lan: _doubleFromMap(payload, 'lan'),
      status: _stringFromMap(payload, 'status') ?? 'inactive',
      message: _stringFromMap(payload, 'message'),
      registeredAt:
          _stringFromMap(payload, 'registered_at') ??
          _stringFromMap(payload, 'registeredAt'),
      updatedAt:
          _stringFromMap(payload, 'updated_at') ??
          _stringFromMap(payload, 'updatedAt'),
    );
  }
}

String? _stringFromMap(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  return '$value';
}

double? _doubleFromMap(Map<String, dynamic> row, String key) {
  return jsonAsDouble(row[key]);
}

/// Coerce JSON number-or-string values to double (handles Decimal `"1.000"`).
double? jsonAsDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return double.tryParse(trimmed);
  }
  return null;
}

/// Coerce JSON number-or-string values to int.
int? jsonAsInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return int.tryParse(trimmed) ?? double.tryParse(trimmed)?.toInt();
  }
  return null;
}

class StoreOrganisationRoleRecord {
  final String customerId;
  final String orgId;
  final String? remoteId;
  final String customerName;
  final String email;
  final String organisationRole;

  const StoreOrganisationRoleRecord({
    required this.customerId,
    required this.orgId,
    required this.remoteId,
    required this.customerName,
    required this.email,
    required this.organisationRole,
  });

  factory StoreOrganisationRoleRecord.fromRow(Map<String, dynamic> row) {
    return StoreOrganisationRoleRecord(
      customerId: row['customerId'] as String? ?? '',
      orgId: row['orgId'] as String? ?? row['org_id'] as String? ?? '',
      remoteId: row['remote_id'] as String?,
      customerName:
          row['name'] as String? ?? row['customer_name'] as String? ?? '',
      email: row['email'] as String? ?? '',
      organisationRole:
          row['role'] as String? ?? row['organisationRole'] as String? ?? '',
    );
  }

  factory StoreOrganisationRoleRecord.fromCustomerRow(
    Map<String, dynamic> row,
  ) {
    return StoreOrganisationRoleRecord(
      customerId: row['customerId'] as String? ?? '',
      orgId: row['orgId'] as String? ?? '',
      remoteId: row['remote_id'] as String?,
      customerName: row['name'] as String? ?? '',
      email: row['email'] as String? ?? '',
      organisationRole: row['role'] as String? ?? '',
    );
  }
}

class StoreOrganisationBootstrapSyncResult {
  final StoreOrganisation organisation;
  final List<StoreDirectoryEntry> stores;
  final List<StoreCustomer> customers;
  final List<StoreRoleAccess> storeRoles;
  final List<StoreOrganisationRoleRecord> organisationRoles;

  const StoreOrganisationBootstrapSyncResult({
    required this.organisation,
    required this.stores,
    required this.customers,
    required this.storeRoles,
    required this.organisationRoles,
  });
}

class StoreOrderType {
  static const String pickUp = 'pick-up';
  static const String delivery = 'delivery';
  static const String dineIn = 'dinein';
  static const String inStore = 'instore';
  static const String onSite = 'onsite';

  static const Set<String> supported = {
    pickUp,
    delivery,
    dineIn,
    inStore,
    onSite,
  };

  static String normalize(dynamic rawValue, {int? typeCode}) {
    final raw = (rawValue as String? ?? '').trim().toLowerCase();
    if (raw.isEmpty && typeCode != null) {
      switch (typeCode) {
        case 1:
          return delivery;
        case 2:
          return pickUp;
        case 3:
          return dineIn;
        case 4:
          return inStore;
      }
    }

    final compact = raw.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (compact == 'pickup' || compact == 'takeaway') {
      return pickUp;
    }
    if (compact == 'delivery') {
      return delivery;
    }
    if (compact == 'dinein') {
      return dineIn;
    }
    if (compact == 'instore' || compact == 'instoreorder') {
      return inStore;
    }
    if (compact == 'onsite' || compact == 'onsiteorder') {
      return onSite;
    }
    // Preserve custom synced order-type keys (e.g. CATERING) instead of
    // collapsing them to pickup.
    if (compact.isNotEmpty) {
      return compact;
    }
    return raw;
  }

  static String requireSupported(dynamic rawValue, {int? typeCode}) {
    final normalized = normalize(rawValue, typeCode: typeCode);
    if (normalized.isNotEmpty) {
      return normalized;
    }
    throw ArgumentError.value(rawValue, 'orderType', 'Unsupported order type.');
  }
}

class StoreOrderPricingMode {
  static const String selling = 'selling';
  static const String buying = 'buying';

  static const Set<String> supported = {selling, buying};

  static String normalize(dynamic rawValue) {
    final normalized = (rawValue as String? ?? '').trim().toLowerCase();
    if (normalized == buying) {
      return buying;
    }
    return selling;
  }

  static String requireSupported(dynamic rawValue) {
    final normalized = normalize(rawValue);
    if (supported.contains(normalized)) {
      return normalized;
    }
    throw ArgumentError.value(
      rawValue,
      'pricingMode',
      'Unsupported pricing mode. Use selling or buying.',
    );
  }
}

class StoreOfferTargetType {
  static const String product = 'product';
  static const String category = 'category';
  static const String bill = 'bill';

  static const Set<String> supported = {product, category, bill};

  static String normalize(dynamic rawValue) {
    final normalized = (rawValue as String? ?? '').trim().toLowerCase();
    if (normalized == bill) {
      return bill;
    }
    if (normalized == category) {
      return category;
    }
    return product;
  }

  static String requireSupported(dynamic rawValue) {
    final normalized = normalize(rawValue);
    if (supported.contains(normalized)) {
      return normalized;
    }
    throw ArgumentError.value(
      rawValue,
      'targetType',
      'Unsupported offer target type. Use product, category, or bill.',
    );
  }
}

class StoreOfferType {
  static const String percentage = 'percentage';
  static const String flat = 'flat';
  static const String buyNGetM = 'buy_n_get_m';
  static const String totalOffer = 'total_offer';

  static const Set<String> supported = {percentage, flat, buyNGetM, totalOffer};

  static String normalize(dynamic rawValue) {
    final normalized = (rawValue as String? ?? '').trim().toLowerCase();
    if (normalized == totalOffer || normalized == 'totaloffer') {
      return totalOffer;
    }
    if (normalized == flat) {
      return flat;
    }
    if (normalized == buyNGetM || normalized == 'buy_n_get_m') {
      return buyNGetM;
    }
    return percentage;
  }

  static String requireSupported(dynamic rawValue) {
    final normalized = normalize(rawValue);
    if (supported.contains(normalized)) {
      return normalized;
    }
    throw ArgumentError.value(
      rawValue,
      'offerType',
      'Unsupported offer type. Use percentage, flat, buy_n_get_m, or total_offer.',
    );
  }
}

class StoreSaveOfferRequest {
  final String? localId;
  final String? uniqueId;
  final String name;
  final String targetType;
  final String offerType;
  final List<String> targetIds;
  final double? percentageValue;
  final double? flatValue;
  final double? minimumBillAmount;
  final int? buyQuantity;
  final int? getQuantity;
  final bool active;
  final String? createdOn;
  final String? updatedOn;

  const StoreSaveOfferRequest({
    this.localId,
    this.uniqueId,
    required this.name,
    required this.targetType,
    required this.offerType,
    required this.targetIds,
    this.percentageValue,
    this.flatValue,
    this.minimumBillAmount,
    this.buyQuantity,
    this.getQuantity,
    this.active = true,
    this.createdOn,
    this.updatedOn,
  });
}

class StoreOfferRecord {
  final String localId;
  final String? uniqueId;
  final String orgId;
  final String storeId;
  final String name;
  final String targetType;
  final String offerType;
  final List<String> targetIds;
  final double? percentageValue;
  final double? flatValue;
  final double? minimumBillAmount;
  final int? buyQuantity;
  final int? getQuantity;
  final bool active;
  final String createdOn;
  final String updatedOn;

  const StoreOfferRecord({
    required this.localId,
    required this.uniqueId,
    required this.orgId,
    required this.storeId,
    required this.name,
    required this.targetType,
    required this.offerType,
    required this.targetIds,
    required this.percentageValue,
    required this.flatValue,
    required this.minimumBillAmount,
    required this.buyQuantity,
    required this.getQuantity,
    required this.active,
    required this.createdOn,
    required this.updatedOn,
  });

  factory StoreOfferRecord.fromRow(
    Map<String, dynamic> row, {
    List<String> targetIds = const [],
  }) {
    return StoreOfferRecord(
      localId: row['local_id'] as String? ?? '',
      uniqueId: row['unique_id'] as String?,
      orgId: row['orgId'] as String? ?? '',
      storeId: row['storeId'] as String? ?? '',
      name: row['name'] as String? ?? '',
      targetType: StoreOfferTargetType.normalize(row['target_type']),
      offerType: StoreOfferType.normalize(row['offer_type']),
      targetIds: targetIds,
      percentageValue: _doubleFromMap(row, 'percentage_value'),
      flatValue: _doubleFromMap(row, 'flat_value'),
      minimumBillAmount: _doubleFromMap(row, 'minimum_bill_amount'),
      buyQuantity: (row['buy_quantity'] as num?)?.toInt(),
      getQuantity: (row['get_quantity'] as num?)?.toInt(),
      active: ((row['active'] as num?)?.toInt() ?? 0) == 1,
      createdOn: row['created_on'] as String? ?? '',
      updatedOn: row['updated_on'] as String? ?? '',
    );
  }
}

class StoreAppliedOfferRecord {
  final String localId;
  final String name;
  final String targetType;
  final String offerType;
  final double discountAmount;
  final List<int> orderItemIds;

  const StoreAppliedOfferRecord({
    required this.localId,
    required this.name,
    required this.targetType,
    required this.offerType,
    required this.discountAmount,
    required this.orderItemIds,
  });
}

class StoreFloorRecord {
  final int id;
  final String orgId;
  final String storeId;
  final String floorId;
  final String name;
  final int sortingOrder;
  final bool active;

  const StoreFloorRecord({
    required this.id,
    required this.orgId,
    required this.storeId,
    required this.floorId,
    required this.name,
    required this.sortingOrder,
    required this.active,
  });

  factory StoreFloorRecord.fromRow(Map<String, dynamic> row) {
    return StoreFloorRecord(
      id: (row['id'] as num?)?.toInt() ?? 0,
      orgId: row['orgId'] as String? ?? '',
      storeId: row['storeId'] as String? ?? '',
      floorId: row['floor_id'] as String? ?? '',
      name: row['name'] as String? ?? '',
      sortingOrder: (row['sorting_order'] as num?)?.toInt() ?? 0,
      active: ((row['active'] as num?)?.toInt() ?? 1) == 1,
    );
  }
}

class StoreSaveFloorRequest {
  final String floorId;
  final String name;
  final int sortingOrder;
  final bool active;

  const StoreSaveFloorRequest({
    required this.floorId,
    required this.name,
    this.sortingOrder = 0,
    this.active = true,
  });

  Map<String, dynamic> toRow(StoreScope scope) {
    return {
      'orgId': scope.orgId,
      'storeId': scope.storeId,
      'floor_id': floorId,
      'name': name,
      'sorting_order': sortingOrder,
      'active': active ? 1 : 0,
    };
  }
}

class StoreTableRecord {
  final int id;
  final String orgId;
  final String storeId;
  final String tableId;
  final String floorId;
  final String floorName;
  final String name;
  final int? capacity;
  final int sortingOrder;
  final bool active;
  final bool occupied;
  final int? occupiedOrderId;
  final String? occupiedOrderStatus;

  const StoreTableRecord({
    required this.id,
    required this.orgId,
    required this.storeId,
    required this.tableId,
    required this.floorId,
    required this.floorName,
    required this.name,
    required this.capacity,
    required this.sortingOrder,
    required this.active,
    required this.occupied,
    required this.occupiedOrderId,
    required this.occupiedOrderStatus,
  });

  String get displayLabel => floorName.isEmpty ? name : '$floorName / $name';

  factory StoreTableRecord.fromRow(Map<String, dynamic> row) {
    return StoreTableRecord(
      id: (row['id'] as num?)?.toInt() ?? 0,
      orgId: row['orgId'] as String? ?? '',
      storeId: row['storeId'] as String? ?? '',
      tableId: row['table_id'] as String? ?? '',
      floorId: row['floor_id'] as String? ?? '',
      floorName: row['floor_name'] as String? ?? '',
      name: row['name'] as String? ?? '',
      capacity: (row['capacity'] as num?)?.toInt(),
      sortingOrder: (row['sorting_order'] as num?)?.toInt() ?? 0,
      active: ((row['active'] as num?)?.toInt() ?? 1) == 1,
      occupied: ((row['occupied'] as num?)?.toInt() ?? 0) == 1,
      occupiedOrderId: (row['occupied_order_id'] as num?)?.toInt(),
      occupiedOrderStatus: row['occupied_order_status'] as String?,
    );
  }
}

class StoreSaveTableRequest {
  final String tableId;
  final String floorId;
  final String name;
  final int? capacity;
  final int sortingOrder;
  final bool active;

  const StoreSaveTableRequest({
    required this.tableId,
    required this.floorId,
    required this.name,
    this.capacity,
    this.sortingOrder = 0,
    this.active = true,
  });

  Map<String, dynamic> toRow(StoreScope scope) {
    return {
      'orgId': scope.orgId,
      'storeId': scope.storeId,
      'table_id': tableId,
      'floor_id': floorId,
      'name': name,
      'capacity': capacity,
      'sorting_order': sortingOrder,
      'active': active ? 1 : 0,
    };
  }
}

class StoreOrderTableRecord {
  final String tableId;
  final String tableName;
  final String floorId;
  final String floorName;

  const StoreOrderTableRecord({
    required this.tableId,
    required this.tableName,
    required this.floorId,
    required this.floorName,
  });

  String get displayLabel =>
      floorName.isEmpty ? tableName : '$floorName / $tableName';
}

class StoreOrderSummary {
  final String orgId;
  final String storeId;
  final String? uniqueId;
  final String localId;
  final int? remoteId;
  final int orderId;
  final String restaurantName;
  final String customerName;
  final String mobile;
  final String? customerUniqueId;
  final String customerEmail;
  final String statusName;
  final String orderType;
  final String paymentStatus;
  final String pricingMode;
  final double totalValue;
  final double offerAppliedValue;
  final double finalValue;
  final double total;

  /// Actual sale time recorded on the device (ISO string) — not sync time.
  final String? createdOn;

  /// POS checkout staff meta (`Name|reg|tips=…`) from `orders.created_by`.
  final String createdBy;
  final int itemCount;
  final double paidTotal;
  final bool exported;
  final String? lastImportedAt;
  final String? lastExportedAt;

  /// Rotating kitchen/serve reference in range 10–99.
  final int? serveNumber;

  const StoreOrderSummary({
    required this.orgId,
    required this.storeId,
    required this.uniqueId,
    required this.localId,
    required this.remoteId,
    required this.orderId,
    required this.restaurantName,
    this.customerName = '',
    this.mobile = '',
    this.customerUniqueId,
    this.customerEmail = '',
    required this.statusName,
    this.orderType = '',
    this.paymentStatus = '',
    required this.pricingMode,
    required this.totalValue,
    required this.offerAppliedValue,
    required this.finalValue,
    required this.total,
    this.createdOn,
    this.createdBy = '',
    this.itemCount = 0,
    this.paidTotal = 0,
    required this.exported,
    required this.lastImportedAt,
    required this.lastExportedAt,
    this.serveNumber,
  });

  double get balanceDue {
    final due = (finalValue > 0 ? finalValue : total) - paidTotal;
    return due <= 0 ? 0 : double.parse(due.toStringAsFixed(2));
  }

  factory StoreOrderSummary.fromRow(Map<String, dynamic> row) {
    return StoreOrderSummary(
      orgId: row['orgId'] as String? ?? '',
      storeId: row['storeId'] as String? ?? '',
      uniqueId: row['unique_id'] as String?,
      localId: row['local_id'] as String? ?? '',
      remoteId: (row['remote_id'] as num?)?.toInt(),
      orderId: (row['order_id'] as num?)?.toInt() ?? 0,
      restaurantName: row['restaurant_name'] as String? ?? '',
      customerName: row['name'] as String? ?? '',
      mobile: row['mobile'] as String? ?? '',
      customerUniqueId: row['customer_unique_id'] as String?,
      customerEmail: row['customer_email'] as String? ?? '',
      statusName: row['status_name'] as String? ?? '',
      orderType: row['order_type'] as String? ?? '',
      paymentStatus: row['payment_status'] as String? ?? '',
      createdOn: row['created_on'] as String?,
      createdBy: row['created_by'] as String? ?? '',
      itemCount: (row['item_count'] as num?)?.toInt() ?? 0,
      paidTotal: (row['paid_total'] as num?)?.toDouble() ?? 0,
      pricingMode: StoreOrderPricingMode.normalize(row['pricing_mode']),
      totalValue:
          (row['total_value'] as num?)?.toDouble() ??
          (row['total'] as num?)?.toDouble() ??
          0,
      offerAppliedValue: (row['offer_applied_value'] as num?)?.toDouble() ?? 0,
      finalValue:
          (row['final_value'] as num?)?.toDouble() ??
          (row['total'] as num?)?.toDouble() ??
          0,
      total:
          (row['final_value'] as num?)?.toDouble() ??
          (row['total'] as num?)?.toDouble() ??
          0,
      exported: ((row['exported'] as num?)?.toInt() ?? 0) == 1,
      lastImportedAt: row['last_imported_at'] as String?,
      lastExportedAt: row['last_exported_at'] as String?,
      serveNumber: (row['serve_number'] as num?)?.toInt(),
    );
  }
}

class StoreOrderDetails {
  final String orgId;
  final String storeId;
  final int id;
  final String? uniqueId;
  final String localId;
  final int? remoteId;
  final int orderId;
  final String restaurantName;
  final String customerName;
  final String mobile;
  final String? customerUniqueId;
  final String statusName;
  final double totalValue;
  final double offerAppliedValue;
  final double finalValue;
  final double total;
  final int serviceInstance;
  final String createdBy;
  final String createdOn;
  final String paymentStatus;
  final String orderType;
  final String pricingMode;
  final double subtotal;
  final double totalDiscount;
  final List<StoreOrderTableRecord> tables;
  final List<StoreOrderItemDetails> items;
  final List<StoreAppliedOfferRecord> appliedOffers;
  final List<StoreOrderPaymentRecord> payments;
  final bool exported;
  final String? lastImportedAt;
  final String? lastExportedAt;
  final int? serveNumber;

  const StoreOrderDetails({
    required this.orgId,
    required this.storeId,
    required this.id,
    required this.uniqueId,
    required this.localId,
    required this.remoteId,
    required this.orderId,
    required this.restaurantName,
    required this.customerName,
    required this.mobile,
    required this.customerUniqueId,
    required this.statusName,
    required this.totalValue,
    required this.offerAppliedValue,
    required this.finalValue,
    required this.total,
    required this.serviceInstance,
    required this.createdBy,
    required this.createdOn,
    required this.paymentStatus,
    required this.orderType,
    required this.pricingMode,
    required this.subtotal,
    required this.totalDiscount,
    required this.tables,
    required this.items,
    required this.appliedOffers,
    required this.payments,
    required this.exported,
    required this.lastImportedAt,
    required this.lastExportedAt,
    this.serveNumber,
  });

  factory StoreOrderDetails.fromRow(Map<String, dynamic> row) {
    return StoreOrderDetails(
      orgId: row['orgId'] as String? ?? '',
      storeId: row['storeId'] as String? ?? '',
      id: (row['id'] as num?)?.toInt() ?? 0,
      uniqueId: row['unique_id'] as String?,
      localId: row['local_id'] as String? ?? '',
      remoteId: (row['remote_id'] as num?)?.toInt(),
      orderId: (row['order_id'] as num?)?.toInt() ?? 0,
      restaurantName: row['restaurant_name'] as String? ?? '',
      customerName: row['name'] as String? ?? '',
      mobile: row['mobile'] as String? ?? '',
      customerUniqueId: row['customer_unique_id'] as String?,
      statusName: row['status_name'] as String? ?? '',
      totalValue:
          (row['total_value'] as num?)?.toDouble() ??
          (row['total'] as num?)?.toDouble() ??
          0,
      offerAppliedValue:
          (row['offer_applied_value'] as num?)?.toDouble() ??
          (((row['total_value'] as num?)?.toDouble() ?? 0) -
              ((row['final_value'] as num?)?.toDouble() ??
                  (row['total'] as num?)?.toDouble() ??
                  0)),
      finalValue:
          (row['final_value'] as num?)?.toDouble() ??
          (row['total'] as num?)?.toDouble() ??
          0,
      total:
          (row['final_value'] as num?)?.toDouble() ??
          (row['total'] as num?)?.toDouble() ??
          0,
      serviceInstance: (row['service_instance'] as num?)?.toInt() ?? 0,
      createdBy: row['created_by'] as String? ?? '',
      createdOn: row['created_on'] as String? ?? '',
      paymentStatus: row['payment_status'] as String? ?? '',
      orderType: StoreOrderType.normalize(row['order_type'] as String? ?? ''),
      pricingMode: StoreOrderPricingMode.normalize(row['pricing_mode']),
      subtotal:
          (row['subtotal'] as num?)?.toDouble() ??
          (row['total'] as num?)?.toDouble() ??
          0,
      totalDiscount: (row['total_discount'] as num?)?.toDouble() ?? 0,
      tables: const [],
      items: const [],
      appliedOffers: const [],
      payments: const [],
      exported: ((row['exported'] as num?)?.toInt() ?? 0) == 1,
      lastImportedAt: row['last_imported_at'] as String?,
      lastExportedAt: row['last_exported_at'] as String?,
      serveNumber: (row['serve_number'] as num?)?.toInt(),
    );
  }
}

class StoreCreateOrderRequest {
  final int? id;
  final String? uniqueId;
  final String? localId;
  final int? remoteId;
  final int? orderId;
  final String restaurantName;
  final String customerName;
  final String mobile;

  /// Stable backend user id reference (``user_{id}``) — never a local SQLite PK.
  final String? customerUniqueId;
  final String statusName;
  final double total;
  final double? totalValue;
  final double? offerAppliedValue;
  final double? finalValue;
  final int serviceInstance;
  final String createdBy;
  final String createdOn;
  final String paymentStatus;
  final String orderType;
  final String pricingMode;
  final List<StoreCreateOrderPaymentRequest> payments;
  final bool exported;
  final String? lastImportedAt;
  final String? lastExportedAt;

  /// Optional kitchen/serve ref (1–configured maximum).
  final int? serveNumber;

  const StoreCreateOrderRequest({
    this.id,
    this.uniqueId,
    this.localId,
    this.remoteId,
    this.orderId,
    required this.restaurantName,
    required this.customerName,
    required this.mobile,
    this.customerUniqueId,
    required this.statusName,
    required this.total,
    this.totalValue,
    this.offerAppliedValue,
    this.finalValue,
    required this.serviceInstance,
    required this.createdBy,
    required this.createdOn,
    required this.paymentStatus,
    required this.orderType,
    this.pricingMode = StoreOrderPricingMode.selling,
    this.payments = const [],
    this.exported = false,
    this.lastImportedAt,
    this.lastExportedAt,
    this.serveNumber,
  });

  Map<String, dynamic> toRow(StoreScope scope, {required int resolvedOrderId}) {
    // Draft / Initiated stay local-only — never stage them for upload.
    final syncExcluded = StoreOrderStatus.isSyncExcluded(statusName);
    return {
      'orgId': scope.orgId,
      'storeId': scope.storeId,
      'unique_id': uniqueId,
      'local_id': localId,
      'remote_id':
          remoteId ?? ((lastImportedAt != null || exported) ? id : null),
      'order_id': resolvedOrderId,
      'restaurant_name': restaurantName,
      'name': customerName,
      'mobile': mobile,
      'customer_unique_id': customerUniqueId,
      'status_name': statusName,
      'total': finalValue ?? total,
      'total_value': totalValue ?? total,
      'offer_applied_value': offerAppliedValue ?? 0,
      'final_value': finalValue ?? total,
      'service_instance': serviceInstance,
      'created_by': createdBy,
      'created_on': createdOn,
      'updated_on': createdOn,
      'payment_status': paymentStatus,
      'order_type': StoreOrderType.requireSupported(orderType),
      'pricing_mode': StoreOrderPricingMode.requireSupported(pricingMode),
      'exported': (syncExcluded || exported) ? 1 : 0,
      'last_imported_at': lastImportedAt,
      'last_exported_at': lastExportedAt,
      'serve_number': serveNumber,
    };
  }
}

class StoreOrderPaymentMode {
  static const String cash = 'cash';
  static const String card = 'card';
  static const String online = 'online';
  static const String credit = 'credit';

  static const Set<String> supported = {cash, card, online, credit};
}

class StoreWalletRecord {
  final int id;
  final String orgId;
  final String storeId;
  final String localId;
  final int? remoteId;
  final int? walletVariantId;
  final int? walletVariantType;
  final int? walletVariantPgType;
  final String? walletVariantName;
  final String? accName;
  final String label;
  final String paymentMode;
  final String? currency;
  final int sortingOrder;
  final bool active;

  const StoreWalletRecord({
    required this.id,
    required this.orgId,
    required this.storeId,
    required this.localId,
    required this.remoteId,
    required this.walletVariantId,
    required this.walletVariantType,
    required this.walletVariantPgType,
    required this.walletVariantName,
    required this.accName,
    required this.label,
    required this.paymentMode,
    required this.currency,
    required this.sortingOrder,
    required this.active,
  });

  factory StoreWalletRecord.fromRow(Map<String, Object?> row) {
    return StoreWalletRecord(
      id: (row['id'] as num).toInt(),
      orgId: row['orgId'] as String? ?? '',
      storeId: row['storeId'] as String? ?? '',
      localId: row['local_id'] as String? ?? '',
      remoteId: (row['remote_id'] as num?)?.toInt(),
      walletVariantId: (row['wallet_variant_id'] as num?)?.toInt(),
      walletVariantType: (row['wallet_variant_type'] as num?)?.toInt(),
      walletVariantPgType: (row['wallet_variant_pg_type'] as num?)?.toInt(),
      walletVariantName: row['wallet_variant_name'] as String?,
      accName: row['acc_name'] as String?,
      label: row['label'] as String? ?? '',
      paymentMode: row['payment_mode'] as String? ?? StoreOrderPaymentMode.cash,
      currency: row['currency'] as String?,
      sortingOrder: (row['sorting_order'] as num?)?.toInt() ?? 0,
      active: ((row['active'] as num?)?.toInt() ?? 1) == 1,
    );
  }
}

class StoreOrderStatus {
  static const String draft = 'Draft';
  static const String initiated = 'Initiated';
  static const String pending = 'Pending';
  static const String closed = 'Closed';
  static const String completed = 'Completed';
  static const String cancelled = 'Cancelled';

  static String normalize(String raw) => raw.trim().toLowerCase();

  static bool isDraft(String raw) {
    final value = normalize(raw);
    return value == 'draft' || value.contains('draft');
  }

  static bool isInitiated(String raw) {
    final value = normalize(raw);
    return value == 'initiated' || value.contains('initiated');
  }

  /// Local-only statuses that must never upload or download via sync.
  static bool isSyncExcluded(String raw) => isDraft(raw) || isInitiated(raw);

  static bool isCancelled(String raw) => normalize(raw).contains('cancel');

  static bool isCompleted(String raw) {
    final value = normalize(raw);
    return value.contains('complet') || value == 'closed';
  }

  static bool canDelete(String raw) => isDraft(raw);

  static bool canCancel(String raw) =>
      !isDraft(raw) && !isCompleted(raw) && !isCancelled(raw);
}

class StoreOrderPaymentRecord {
  final int id;
  final String orgId;
  final String storeId;
  final String localId;
  final int? remoteId;
  final int orderId;
  final String paymentMode;
  final double amount;
  final String? customerId;
  final String? referenceId;
  final String createdOn;
  final String updatedOn;
  final double refundedAmount;

  const StoreOrderPaymentRecord({
    required this.id,
    required this.orgId,
    required this.storeId,
    required this.localId,
    required this.remoteId,
    required this.orderId,
    required this.paymentMode,
    required this.amount,
    required this.customerId,
    required this.referenceId,
    required this.createdOn,
    required this.updatedOn,
    this.refundedAmount = 0,
  });

  double get refundableAmount {
    final remaining = amount - refundedAmount;
    return remaining <= 0 ? 0 : double.parse(remaining.toStringAsFixed(2));
  }

  bool get isFullyRefunded => refundableAmount <= 0.0001;

  factory StoreOrderPaymentRecord.fromRow(Map<String, dynamic> row) {
    return StoreOrderPaymentRecord(
      id: (row['id'] as num?)?.toInt() ?? 0,
      orgId: row['orgId'] as String? ?? '',
      storeId: row['storeId'] as String? ?? '',
      localId: row['local_id'] as String? ?? '',
      remoteId: (row['remote_id'] as num?)?.toInt(),
      orderId: (row['order_id'] as num?)?.toInt() ?? 0,
      paymentMode: row['payment_mode'] as String? ?? '',
      amount: (row['amount'] as num?)?.toDouble() ?? 0,
      customerId: row['customerId'] as String?,
      referenceId: row['reference_id'] as String?,
      createdOn: row['created_on'] as String? ?? '',
      updatedOn: row['updated_on'] as String? ?? '',
      refundedAmount: (row['refunded_amount'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toSyncJson() {
    return {
      'id': remoteId,
      'local_id': localId,
      'remote_id': remoteId,
      'order_id': orderId,
      'payment_mode': paymentMode,
      'amount': amount,
      'customerId': customerId,
      'reference_id': referenceId,
      'created_on': createdOn,
      'updated_on': updatedOn,
    };
  }
}

class StoreOrderRefundRecord {
  final int id;
  final String orgId;
  final String storeId;
  final String localId;
  final int? remoteId;
  final int orderId;
  final int paymentId;
  final String? paymentLocalId;
  final String? paymentReferenceId;
  final double amount;
  final String? reason;
  final String status;
  final String createdOn;
  final bool exported;

  const StoreOrderRefundRecord({
    required this.id,
    required this.orgId,
    required this.storeId,
    required this.localId,
    required this.remoteId,
    required this.orderId,
    required this.paymentId,
    required this.paymentLocalId,
    required this.paymentReferenceId,
    required this.amount,
    required this.reason,
    required this.status,
    required this.createdOn,
    required this.exported,
  });

  factory StoreOrderRefundRecord.fromRow(Map<String, dynamic> row) {
    return StoreOrderRefundRecord(
      id: (row['id'] as num?)?.toInt() ?? 0,
      orgId: row['orgId'] as String? ?? '',
      storeId: row['storeId'] as String? ?? '',
      localId: row['local_id'] as String? ?? '',
      remoteId: (row['remote_id'] as num?)?.toInt(),
      orderId: (row['order_id'] as num?)?.toInt() ?? 0,
      paymentId: (row['payment_id'] as num?)?.toInt() ?? 0,
      paymentLocalId: row['payment_local_id'] as String?,
      paymentReferenceId: row['payment_reference_id'] as String?,
      amount: (row['amount'] as num?)?.toDouble() ?? 0,
      reason: row['reason'] as String?,
      status: row['status'] as String? ?? 'success',
      createdOn: row['created_on'] as String? ?? '',
      exported: ((row['exported'] as num?)?.toInt() ?? 0) == 1,
    );
  }

  Map<String, dynamic> toSyncJson() {
    return {
      'local_id': localId,
      'remote_id': remoteId,
      'order_id': orderId,
      'payment_id': paymentId,
      'payment_local_id': paymentLocalId,
      'payment_reference_id': paymentReferenceId,
      'amount': amount,
      'reason': reason,
      'status': status,
      'created_on': createdOn,
    };
  }
}

class StoreCreateOrderRefundRequest {
  final String? localId;
  final int paymentId;
  final double amount;
  final String? reason;
  final String? createdOn;

  const StoreCreateOrderRefundRequest({
    this.localId,
    required this.paymentId,
    required this.amount,
    this.reason,
    this.createdOn,
  });
}

class StoreCreateOrderPaymentRequest {
  final String? localId;
  final int? remoteId;
  final String paymentMode;
  final double amount;
  final String? customerId;
  final String? referenceId;
  final String? createdOn;
  final String? updatedOn;

  const StoreCreateOrderPaymentRequest({
    this.localId,
    this.remoteId,
    required this.paymentMode,
    required this.amount,
    this.customerId,
    this.referenceId,
    this.createdOn,
    this.updatedOn,
  });

  Map<String, dynamic> toRow(StoreScope scope, int orderId) {
    final normalizedMode = paymentMode.trim().toLowerCase();
    if (!StoreOrderPaymentMode.supported.contains(normalizedMode)) {
      throw ArgumentError.value(
        paymentMode,
        'paymentMode',
        'Unsupported payment mode.',
      );
    }
    if (normalizedMode == StoreOrderPaymentMode.credit &&
        (customerId == null || customerId!.isEmpty)) {
      throw ArgumentError.value(
        customerId,
        'customerId',
        'customerId is required for credit payments.',
      );
    }
    final timestamp = createdOn ?? DateTime.now().toIso8601String();
    return {
      'orgId': scope.orgId,
      'storeId': scope.storeId,
      'local_id': localId,
      'remote_id': remoteId,
      'order_id': orderId,
      'payment_mode': normalizedMode,
      'amount': amount,
      'customerId': normalizedMode == StoreOrderPaymentMode.credit
          ? customerId
          : null,
      'reference_id': referenceId,
      'created_on': timestamp,
      'updated_on': updatedOn ?? timestamp,
    };
  }
}

class StoreOrderItemRecord {
  final int id;
  final String orgId;
  final String storeId;
  final String? uniqueId;
  final int orderId;
  final String productVariantId;
  final String productId;

  /// Display name for free-text / misc lines (and optional catalogue override).
  final String itemName;
  final String? tableId;
  final String? tableName;
  final String? floorId;
  final String? floorName;
  final int quantity;
  final String pricingMode;
  final double sellPrice;
  final double? buyPrice;
  final double mrpPrice;
  final double baseUnitPrice;
  final double unitPrice;
  final double finalPrice;
  final int kitchenSentQuantity;
  final int? kitchenSentBatch;
  final String? kitchenSentAt;

  const StoreOrderItemRecord({
    required this.id,
    required this.orgId,
    required this.storeId,
    required this.uniqueId,
    required this.orderId,
    required this.productVariantId,
    required this.productId,
    this.itemName = '',
    required this.tableId,
    required this.tableName,
    required this.floorId,
    required this.floorName,
    required this.quantity,
    required this.pricingMode,
    required this.sellPrice,
    required this.buyPrice,
    required this.mrpPrice,
    required this.baseUnitPrice,
    required this.unitPrice,
    required this.finalPrice,
    required this.kitchenSentQuantity,
    required this.kitchenSentBatch,
    required this.kitchenSentAt,
  });

  factory StoreOrderItemRecord.fromRow(Map<String, dynamic> row) {
    return StoreOrderItemRecord(
      id: (row['id'] as num?)?.toInt() ?? 0,
      orgId: row['orgId'] as String? ?? '',
      storeId: row['storeId'] as String? ?? '',
      uniqueId: row['unique_id'] as String?,
      orderId: (row['order_id'] as num?)?.toInt() ?? 0,
      productVariantId: row['product_variant_id'] as String? ?? '',
      productId: row['product_id'] as String? ?? '',
      itemName:
          '${row['item_name'] ?? row['product_name'] ?? row['name'] ?? ''}'
              .trim(),
      tableId: row['table_id'] as String?,
      tableName: row['table_name'] as String?,
      floorId: row['floor_id'] as String?,
      floorName: row['floor_name'] as String?,
      quantity: (row['qty'] as num?)?.toInt() ?? 0,
      pricingMode: StoreOrderPricingMode.normalize(row['pricing_mode']),
      sellPrice:
          (row['sell_price'] as num?)?.toDouble() ??
          (row['unit_price'] as num?)?.toDouble() ??
          0,
      buyPrice: (row['buy_price'] as num?)?.toDouble(),
      mrpPrice:
          (row['mrp_price'] as num?)?.toDouble() ??
          (row['sell_price'] as num?)?.toDouble() ??
          (row['unit_price'] as num?)?.toDouble() ??
          0,
      baseUnitPrice:
          (row['base_unit_price'] as num?)?.toDouble() ??
          (row['unit_price'] as num?)?.toDouble() ??
          0,
      unitPrice: (row['unit_price'] as num?)?.toDouble() ?? 0,
      finalPrice: (row['final_price'] as num?)?.toDouble() ?? 0,
      kitchenSentQuantity: (row['kitchen_sent_quantity'] as num?)?.toInt() ?? 0,
      kitchenSentBatch: (row['kitchen_sent_batch'] as num?)?.toInt(),
      kitchenSentAt: row['kitchen_sent_at'] as String?,
    );
  }
}

class StoreKitchenCancellationRecord {
  final int id;
  final String orgId;
  final String storeId;
  final int orderId;
  final int orderItemId;
  final String productVariantId;
  final String productId;
  final int cancelledQuantity;
  final String? cancelledBy;
  final int? sourceKitchenBatch;
  final String createdOn;
  final String? note;

  const StoreKitchenCancellationRecord({
    required this.id,
    required this.orgId,
    required this.storeId,
    required this.orderId,
    required this.orderItemId,
    required this.productVariantId,
    required this.productId,
    required this.cancelledQuantity,
    required this.cancelledBy,
    required this.sourceKitchenBatch,
    required this.createdOn,
    required this.note,
  });

  factory StoreKitchenCancellationRecord.fromRow(Map<String, dynamic> row) {
    return StoreKitchenCancellationRecord(
      id: (row['id'] as num?)?.toInt() ?? 0,
      orgId: row['orgId'] as String? ?? '',
      storeId: row['storeId'] as String? ?? '',
      orderId: (row['order_id'] as num?)?.toInt() ?? 0,
      orderItemId: (row['order_item_id'] as num?)?.toInt() ?? 0,
      productVariantId: row['product_variant_id'] as String? ?? '',
      productId: row['product_id'] as String? ?? '',
      cancelledQuantity: (row['cancelled_qty'] as num?)?.toInt() ?? 0,
      cancelledBy: row['cancelled_by'] as String?,
      sourceKitchenBatch: (row['source_kitchen_batch'] as num?)?.toInt(),
      createdOn: row['created_on'] as String? ?? '',
      note: row['note'] as String?,
    );
  }
}

class StoreOrderItemAddonRecord {
  final int id;
  final String orgId;
  final String storeId;
  final int orderId;
  final int orderItemId;
  final String addonGroupId;
  final String addonGroupName;
  final int minSelections;
  final int? maxSelections;
  final String addonItemId;
  final String addonItemName;
  final int quantity;
  final String pricingMode;
  final double sellPrice;
  final double? buyPrice;
  final double mrpPrice;
  final double unitPrice;
  final double totalPrice;
  final String createdOn;

  const StoreOrderItemAddonRecord({
    required this.id,
    required this.orgId,
    required this.storeId,
    required this.orderId,
    required this.orderItemId,
    required this.addonGroupId,
    required this.addonGroupName,
    required this.minSelections,
    required this.maxSelections,
    required this.addonItemId,
    required this.addonItemName,
    required this.quantity,
    required this.pricingMode,
    required this.sellPrice,
    required this.buyPrice,
    required this.mrpPrice,
    required this.unitPrice,
    required this.totalPrice,
    required this.createdOn,
  });

  factory StoreOrderItemAddonRecord.fromRow(Map<String, dynamic> row) {
    return StoreOrderItemAddonRecord(
      id: (row['id'] as num?)?.toInt() ?? 0,
      orgId: row['orgId'] as String? ?? '',
      storeId: row['storeId'] as String? ?? '',
      orderId: (row['order_id'] as num?)?.toInt() ?? 0,
      orderItemId: (row['order_item_id'] as num?)?.toInt() ?? 0,
      addonGroupId: row['addon_group_id'] as String? ?? '',
      addonGroupName: row['addon_group_name'] as String? ?? '',
      minSelections: (row['min_selections'] as num?)?.toInt() ?? 0,
      maxSelections: (row['max_selections'] as num?)?.toInt(),
      addonItemId: row['addon_item_id'] as String? ?? '',
      addonItemName: row['addon_item_name'] as String? ?? '',
      quantity: (row['qty'] as num?)?.toInt() ?? 0,
      pricingMode: StoreOrderPricingMode.normalize(row['pricing_mode']),
      sellPrice:
          (row['sell_price'] as num?)?.toDouble() ??
          (row['unit_price'] as num?)?.toDouble() ??
          0,
      buyPrice: (row['buy_price'] as num?)?.toDouble(),
      mrpPrice:
          (row['mrp_price'] as num?)?.toDouble() ??
          (row['sell_price'] as num?)?.toDouble() ??
          (row['unit_price'] as num?)?.toDouble() ??
          0,
      unitPrice: (row['unit_price'] as num?)?.toDouble() ?? 0,
      totalPrice: (row['total_price'] as num?)?.toDouble() ?? 0,
      createdOn: row['created_on'] as String? ?? '',
    );
  }
}

class StoreOrderItemDetails {
  final StoreOrderItemRecord item;
  final List<StoreOrderItemAddonRecord> addons;
  final double discountAmount;
  final double totalAfterDiscount;
  final List<String> appliedOfferLocalIds;

  const StoreOrderItemDetails({
    required this.item,
    required this.addons,
    required this.discountAmount,
    required this.totalAfterDiscount,
    required this.appliedOfferLocalIds,
  });
}

class StoreAddOrderItemAddonRequest {
  final int? orderItemId;
  final String addonGroupId;
  final String addonGroupName;
  final int minSelections;
  final int? maxSelections;
  final String addonItemId;
  final String addonItemName;
  final int quantity;
  final String? pricingMode;
  final double? sellPrice;
  final double? buyPrice;
  final double? mrpPrice;
  final double? unitPrice;
  final String? createdOn;

  const StoreAddOrderItemAddonRequest({
    this.orderItemId,
    required this.addonGroupId,
    required this.addonGroupName,
    this.minSelections = 0,
    this.maxSelections,
    required this.addonItemId,
    required this.addonItemName,
    this.quantity = 1,
    this.pricingMode,
    this.sellPrice,
    this.buyPrice,
    this.mrpPrice,
    this.unitPrice,
    this.createdOn,
  });

  Map<String, dynamic> toRow(
    StoreScope scope, {
    required int orderId,
    required int resolvedOrderItemId,
    required int resolvedMinSelections,
    required int? resolvedMaxSelections,
    required String resolvedPricingMode,
    required double resolvedSellPrice,
    required double? resolvedBuyPrice,
    required double resolvedMrpPrice,
    required double resolvedUnitPrice,
  }) {
    if (quantity <= 0) {
      throw ArgumentError.value(
        quantity,
        'quantity',
        'Add-on quantity must be greater than zero.',
      );
    }
    return {
      'orgId': scope.orgId,
      'storeId': scope.storeId,
      'order_id': orderId,
      'order_item_id': orderItemId ?? resolvedOrderItemId,
      'addon_group_id': addonGroupId,
      'addon_group_name': addonGroupName,
      'min_selections': resolvedMinSelections,
      'max_selections': resolvedMaxSelections,
      'addon_item_id': addonItemId,
      'addon_item_name': addonItemName,
      'qty': quantity,
      'pricing_mode': StoreOrderPricingMode.requireSupported(
        resolvedPricingMode,
      ),
      'sell_price': resolvedSellPrice,
      'buy_price': resolvedBuyPrice,
      'mrp_price': resolvedMrpPrice,
      'unit_price': resolvedUnitPrice,
      'total_price': resolvedUnitPrice * quantity,
      'created_on': createdOn ?? DateTime.now().toIso8601String(),
    };
  }
}

class StoreAddOrderItemRequest {
  final int orderId;
  final String? uniqueId;
  final String productVariantId;
  final String productId;
  final String? itemName;
  final String? tableId;
  final num quantity;
  final String? pricingMode;
  final double? sellPrice;
  final double? buyPrice;
  final double? mrpPrice;
  final double? unitPrice;
  final double? finalPrice;
  final String createdBy;
  final String createdOn;
  final List<StoreAddOrderItemAddonRequest> addons;

  const StoreAddOrderItemRequest({
    required this.orderId,
    this.uniqueId,
    required this.productVariantId,
    required this.productId,
    this.itemName,
    this.tableId,
    required this.quantity,
    this.pricingMode,
    this.sellPrice,
    this.buyPrice,
    this.mrpPrice,
    this.unitPrice,
    this.finalPrice,
    required this.createdBy,
    required this.createdOn,
    this.addons = const [],
  });

  Map<String, dynamic> toRow(
    StoreScope scope, {
    required String resolvedPricingMode,
    required double resolvedSellPrice,
    required double? resolvedBuyPrice,
    required double resolvedMrpPrice,
    required double resolvedUnitPrice,
    String? resolvedTableId,
    String? resolvedTableName,
    String? resolvedFloorId,
    String? resolvedFloorName,
  }) {
    return {
      'orgId': scope.orgId,
      'storeId': scope.storeId,
      'unique_id': uniqueId,
      'order_id': orderId,
      'product_variant_id': productVariantId,
      'product_id': productId,
      'item_name': (itemName ?? '').trim(),
      'table_id': resolvedTableId,
      'table_name': resolvedTableName,
      'floor_id': resolvedFloorId,
      'floor_name': resolvedFloorName,
      'qty': quantity,
      'pricing_mode': StoreOrderPricingMode.requireSupported(
        resolvedPricingMode,
      ),
      'sell_price': resolvedSellPrice,
      'buy_price': resolvedBuyPrice,
      'mrp_price': resolvedMrpPrice,
      'base_unit_price': resolvedUnitPrice,
      'unit_price': resolvedUnitPrice,
      'final_price': finalPrice ?? (resolvedUnitPrice * quantity),
      'created_by': createdBy,
      'created_on': createdOn,
    };
  }
}

class StoreUpdateOrderItemQuantityRequest {
  final int quantity;

  const StoreUpdateOrderItemQuantityRequest({required this.quantity});
}

class StoreCustomerRecord {
  final String customerId;
  final String? remoteId;
  final String name;
  final String phone;
  final String storeId;
  final String orgId;

  const StoreCustomerRecord({
    required this.customerId,
    required this.remoteId,
    required this.name,
    required this.phone,
    required this.storeId,
    required this.orgId,
  });

  factory StoreCustomerRecord.fromRow(Map<String, dynamic> row) {
    return StoreCustomerRecord(
      customerId: row['customerId'] as String? ?? '',
      remoteId: row['remote_id'] as String?,
      name: row['name'] as String? ?? '',
      phone: row['phone'] as String? ?? '',
      storeId: row['storeId'] as String? ?? '',
      orgId: row['orgId'] as String? ?? '',
    );
  }
}

class StoreCustomer {
  final String customerId;
  final String? remoteId;
  final String orgId;
  final String storeId;
  final String name;
  final String email;
  final String phone;
  final String country;
  final String status;
  final String role;
  final String usrRegNum;
  final String photoPath;

  const StoreCustomer({
    required this.customerId,
    required this.remoteId,
    required this.orgId,
    required this.storeId,
    required this.name,
    required this.email,
    required this.phone,
    required this.country,
    required this.status,
    required this.role,
    this.usrRegNum = '',
    this.photoPath = '',
  });

  factory StoreCustomer.fromRow(Map<String, dynamic> row) {
    return StoreCustomer(
      customerId: row['customerId'] as String? ?? '',
      remoteId: row['remote_id'] as String?,
      orgId: row['orgId'] as String? ?? '',
      storeId: row['storeId'] as String? ?? '',
      name: row['name'] as String? ?? '',
      email: row['email'] as String? ?? '',
      phone: row['phone'] as String? ?? '',
      country: row['country'] as String? ?? '',
      status: row['status'] as String? ?? '',
      role: row['role'] as String? ?? '',
      usrRegNum: '${row['usr_reg_num'] ?? row['reg_num'] ?? ''}',
      photoPath: '${row['photo_path'] ?? ''}',
    );
  }
}

class StoreCreateCustomerRequest {
  final String? customerId;
  final String? remoteId;
  final String? orgId;
  final String? storeId;
  final String name;
  final String email;
  final String phone;
  final String country;
  final String status;
  final String role;
  final String password;

  const StoreCreateCustomerRequest({
    this.customerId,
    this.remoteId,
    this.orgId,
    this.storeId,
    required this.name,
    required this.email,
    required this.phone,
    required this.country,
    required this.status,
    required this.role,
    required this.password,
  });

  Map<String, dynamic> toRow(
    String hashedPassword, {
    required String resolvedCustomerId,
    required String resolvedOrgId,
    required String resolvedStoreId,
  }) {
    return {
      'customerId': resolvedCustomerId,
      'remote_id': remoteId ?? resolvedCustomerId,
      'orgId': resolvedOrgId,
      'storeId': resolvedStoreId,
      'name': name,
      'email': email,
      'phone': phone,
      'country': country,
      'status': status,
      'role': role,
      'password': hashedPassword,
    };
  }
}

class StoreUpdateCustomerRequest {
  final String? remoteId;
  final String? name;
  final String? email;
  final String? phone;
  final String? country;
  final String? status;
  final String? role;
  final String? password;

  const StoreUpdateCustomerRequest({
    this.remoteId,
    this.name,
    this.email,
    this.phone,
    this.country,
    this.status,
    this.role,
    this.password,
  });
}

class StoreCustomerQuery {
  final StoreScope scope;
  final String? nameQuery;
  final String? phoneQuery;
  final int? limit;
  final int? offset;

  const StoreCustomerQuery({
    required this.scope,
    this.nameQuery,
    this.phoneQuery,
    this.limit,
    this.offset,
  });
}

class StoreLoginRequest {
  /// Staff id (reg number), email, or phone.
  final String email;
  final String password;

  const StoreLoginRequest({required this.email, required this.password});

  String get identifier => email;
}

class StoreSession {
  final String customerId;
  final String email;
  final String loginAt;
  final String organisationRole;
  final String storeRole;

  const StoreSession({
    required this.customerId,
    required this.email,
    required this.loginAt,
    required this.organisationRole,
    required this.storeRole,
  });

  String get role => storeRole;

  factory StoreSession.fromRow(Map<String, dynamic> row) {
    return StoreSession(
      customerId: row['customerId'] as String? ?? '',
      email: row['email'] as String? ?? '',
      loginAt: row['loginAt'] as String? ?? '',
      organisationRole:
          row['org_role'] as String? ?? row['role'] as String? ?? '',
      storeRole: row['store_role'] as String? ?? row['role'] as String? ?? '',
    );
  }
}

class StoreProductCategoryRecord {
  final String orgId;
  final String storeId;
  final String localId;
  final String? uniqueId;
  final int categoryId;
  final String name;
  final String? slug;
  final String? logo;
  final int sortingOrder;

  const StoreProductCategoryRecord({
    required this.orgId,
    required this.storeId,
    required this.localId,
    required this.uniqueId,
    required this.categoryId,
    required this.name,
    required this.slug,
    required this.logo,
    required this.sortingOrder,
  });

  factory StoreProductCategoryRecord.fromRow(Map<String, dynamic> row) {
    final localId = row['localId'] as String? ?? '';
    return StoreProductCategoryRecord(
      orgId: row['orgId'] as String? ?? '',
      storeId: row['storeId'] as String? ?? '',
      localId: localId,
      uniqueId: row['unique_id'] as String?,
      categoryId:
          (row['categoryId'] as num?)?.toInt() ??
          int.tryParse(localId.replaceFirst('cat_', '')) ??
          0,
      name: row['name'] as String? ?? '',
      slug: row['slug'] as String?,
      logo: row['logo'] as String?,
      sortingOrder: (row['sorting_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class StoreProductVariantRecord {
  final String orgId;
  final String storeId;
  final String localId;
  final String? uniqueId;
  final int? variantId;
  final String categoryLocalId;
  final int categoryId;
  final String productName;
  final String productVariantName;
  final String? barcode;
  final double sellPrice;
  final double? buyPrice;
  final double mrpPrice;
  final bool exported;
  final String? lastImportedAt;
  final String? lastExportedAt;
  final int? sellUnitCode;
  final String? sellUnitShort;
  final String? sellUnitLabel;
  final double? sellUnitBaseQty;
  final String? taxLabel;

  const StoreProductVariantRecord({
    required this.orgId,
    required this.storeId,
    required this.localId,
    required this.uniqueId,
    required this.variantId,
    this.categoryLocalId = '',
    required this.categoryId,
    required this.productName,
    required this.productVariantName,
    required this.barcode,
    required this.sellPrice,
    required this.buyPrice,
    required this.mrpPrice,
    required this.exported,
    required this.lastImportedAt,
    required this.lastExportedAt,
    this.sellUnitCode,
    this.sellUnitShort,
    this.sellUnitLabel,
    this.sellUnitBaseQty,
    this.taxLabel,
  });

  factory StoreProductVariantRecord.fromRow(Map<String, dynamic> row) {
    final categoryLocalId = row['categoryLocalId'] as String? ?? '';
    return StoreProductVariantRecord(
      orgId: row['orgId'] as String? ?? '',
      storeId: row['storeId'] as String? ?? '',
      localId: row['localId'] as String? ?? '',
      uniqueId: row['unique_id'] as String?,
      variantId: (row['variantId'] as num?)?.toInt(),
      categoryLocalId: categoryLocalId,
      categoryId: int.tryParse(categoryLocalId.replaceFirst('cat_', '')) ?? 0,
      productName: row['product_name'] as String? ?? '',
      productVariantName: row['product_variant_name'] as String? ?? '',
      barcode: row['barcode'] as String?,
      sellPrice: _doubleFromMap(row, 'sell_price') ?? 0,
      buyPrice: _doubleFromMap(row, 'buy_price'),
      mrpPrice:
          _doubleFromMap(row, 'mrp_price') ??
          (_doubleFromMap(row, 'sell_price') ?? 0),
      exported: ((row['exported'] as num?)?.toInt() ?? 0) == 1,
      lastImportedAt: row['last_imported_at'] as String?,
      lastExportedAt: row['last_exported_at'] as String?,
      sellUnitCode: (row['sell_unit_code'] as num?)?.toInt(),
      sellUnitShort: row['sell_unit_short'] as String?,
      sellUnitLabel: row['sell_unit_label'] as String?,
      sellUnitBaseQty: _doubleFromMap(row, 'sell_unit_base_qty'),
      taxLabel: (row['tax_label'] as String?)?.trim(),
    );
  }
}

class StoreProductAddonItemRecord {
  final String addonGroupId;
  final String addonGroupName;
  final String addonItemId;
  final String addonItemName;
  final int minSelections;
  final int? maxSelections;
  final bool active;
  final bool defaultSelected;
  final double sellPrice;
  final double? buyPrice;
  final double mrpPrice;

  const StoreProductAddonItemRecord({
    required this.addonGroupId,
    required this.addonGroupName,
    required this.addonItemId,
    required this.addonItemName,
    required this.minSelections,
    required this.maxSelections,
    required this.active,
    required this.defaultSelected,
    required this.sellPrice,
    required this.buyPrice,
    required this.mrpPrice,
  });
}

class StoreProductAddonGroupRecord {
  final String addonGroupId;
  final String addonGroupName;
  final int minSelections;
  final int? maxSelections;
  final String source;
  final List<StoreProductAddonItemRecord> items;

  const StoreProductAddonGroupRecord({
    required this.addonGroupId,
    required this.addonGroupName,
    required this.minSelections,
    required this.maxSelections,
    required this.source,
    required this.items,
  });
}

class StoreCreditRecord {
  final int id;
  final String orgId;
  final String storeId;
  final String localId;
  final int? remoteId;
  final String customerId;
  final String customerName;
  final int orderId;
  final double amount;
  final double paidAmount;
  final double outstandingAmount;
  final bool settled;
  final String? dueDate;
  final String createdOn;
  final String updatedOn;

  const StoreCreditRecord({
    required this.id,
    required this.orgId,
    required this.storeId,
    required this.localId,
    required this.remoteId,
    required this.customerId,
    required this.customerName,
    required this.orderId,
    required this.amount,
    required this.paidAmount,
    required this.outstandingAmount,
    required this.settled,
    this.dueDate,
    required this.createdOn,
    required this.updatedOn,
  });

  factory StoreCreditRecord.fromRow(Map<String, dynamic> row) {
    return StoreCreditRecord(
      id: (row['id'] as num?)?.toInt() ?? 0,
      orgId: row['orgId'] as String? ?? '',
      storeId: row['storeId'] as String? ?? '',
      localId: row['local_id'] as String? ?? '',
      remoteId: (row['remote_id'] as num?)?.toInt(),
      customerId: row['customerId'] as String? ?? '',
      customerName: row['customer_name'] as String? ?? '',
      orderId: (row['order_id'] as num?)?.toInt() ?? 0,
      amount: (row['amount'] as num?)?.toDouble() ?? 0,
      paidAmount: (row['paid_amount'] as num?)?.toDouble() ?? 0,
      outstandingAmount:
          (row['outstanding_amount'] as num?)?.toDouble() ??
          ((row['amount'] as num?)?.toDouble() ?? 0),
      settled: ((row['settled'] as num?)?.toInt() ?? 0) == 1,
      dueDate: row['due_date'] as String?,
      createdOn: row['created_on'] as String? ?? '',
      updatedOn: row['updated_on'] as String? ?? '',
    );
  }
}

class StoreCreditCustomerSortBy {
  static const String amount = 'amount';
  static const String name = 'name';

  /// Oldest unpaid credit first (longest pending).
  static const String pending = 'pending';

  static const Set<String> supported = {amount, name, pending};
}

class StoreCreditDateFilterType {
  static const String today = 'today';
  static const String yesterday = 'yesterday';
  static const String custom = 'custom';

  static const Set<String> supported = {today, yesterday, custom};
}

class StoreCreditDateFilter {
  final String type;
  final DateTime? date;

  StoreCreditDateFilter.today()
    : type = StoreCreditDateFilterType.today,
      date = null;

  StoreCreditDateFilter.yesterday()
    : type = StoreCreditDateFilterType.yesterday,
      date = null;

  StoreCreditDateFilter.custom(DateTime date)
    : type = StoreCreditDateFilterType.custom,
      date = date;
}

class StoreCustomerCreditSummary {
  final String customerId;
  final String customerName;
  final double totalCreditAmount;
  final double totalPaidAmount;
  final double totalOutstandingAmount;
  final int creditCount;
  final String latestCreditOn;

  /// Created/due timestamp of the oldest still-unpaid credit for this customer.
  final String? oldestOutstandingOn;

  const StoreCustomerCreditSummary({
    required this.customerId,
    required this.customerName,
    required this.totalCreditAmount,
    required this.totalPaidAmount,
    required this.totalOutstandingAmount,
    required this.creditCount,
    required this.latestCreditOn,
    this.oldestOutstandingOn,
  });

  factory StoreCustomerCreditSummary.fromRow(Map<String, dynamic> row) {
    return StoreCustomerCreditSummary(
      customerId: row['customerId'] as String? ?? '',
      customerName: row['customer_name'] as String? ?? '',
      totalCreditAmount: (row['total_credit_amount'] as num?)?.toDouble() ?? 0,
      totalPaidAmount: (row['total_paid_amount'] as num?)?.toDouble() ?? 0,
      totalOutstandingAmount:
          (row['total_outstanding_amount'] as num?)?.toDouble() ?? 0,
      creditCount: (row['credit_count'] as num?)?.toInt() ?? 0,
      latestCreditOn: row['latest_credit_on'] as String? ?? '',
      oldestOutstandingOn: row['oldest_outstanding_on'] as String?,
    );
  }
}

/// Synced per-customer credit account (receivables) for a store.
class StoreCreditAccountRecord {
  final String customerId;
  final double? creditLimitAmount;
  final double outstandingBalance;
  final double totalCreditSoFar;
  final double totalRepaid;
  final int? remoteId;
  final String localId;
  final String updatedOn;

  const StoreCreditAccountRecord({
    required this.customerId,
    required this.creditLimitAmount,
    required this.outstandingBalance,
    required this.totalCreditSoFar,
    required this.totalRepaid,
    required this.remoteId,
    required this.localId,
    required this.updatedOn,
  });

  factory StoreCreditAccountRecord.fromRow(Map<String, dynamic> row) {
    final rawLimit = row['credit_limit_amount'];
    return StoreCreditAccountRecord(
      customerId: row['customerId'] as String? ?? '',
      creditLimitAmount: rawLimit == null
          ? null
          : (rawLimit as num?)?.toDouble(),
      outstandingBalance: (row['outstanding_balance'] as num?)?.toDouble() ?? 0,
      totalCreditSoFar: (row['total_credit_so_far'] as num?)?.toDouble() ?? 0,
      totalRepaid: (row['total_repaid'] as num?)?.toDouble() ?? 0,
      remoteId: (row['remote_id'] as num?)?.toInt(),
      localId: row['local_id'] as String? ?? '',
      updatedOn: row['updated_on'] as String? ?? '',
    );
  }
}

class StoreCreditRepaymentMode {
  static const String cash = 'cash';
  static const String card = 'card';
  static const String voucher = 'voucher';

  static const Set<String> supported = {cash, card, voucher};
}

class StoreScheduledCreditRepaymentStatus {
  static const String scheduled = 'scheduled';
  static const String collected = 'collected';
  static const String cancelled = 'cancelled';
}

class StoreScheduledCreditRepayment {
  final int id;
  final String orgId;
  final String storeId;
  final String localId;
  final String customerId;
  final double amount;
  final String dueDate;
  final String status;
  final int? collectedRepaymentId;
  final String createdOn;
  final String updatedOn;

  const StoreScheduledCreditRepayment({
    required this.id,
    required this.orgId,
    required this.storeId,
    required this.localId,
    required this.customerId,
    required this.amount,
    required this.dueDate,
    required this.status,
    required this.collectedRepaymentId,
    required this.createdOn,
    required this.updatedOn,
  });

  bool get isOpen => status == StoreScheduledCreditRepaymentStatus.scheduled;

  bool get isOverdue {
    if (!isOpen || dueDate.isEmpty) return false;
    final due = DateTime.tryParse(dueDate);
    if (due == null) return false;
    final today = DateTime.now();
    final dueDay = DateTime(due.year, due.month, due.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    return dueDay.isBefore(todayDay);
  }

  factory StoreScheduledCreditRepayment.fromRow(Map<String, Object?> row) {
    return StoreScheduledCreditRepayment(
      id: (row['id'] as num).toInt(),
      orgId: row['orgId'] as String? ?? '',
      storeId: row['storeId'] as String? ?? '',
      localId: row['local_id'] as String? ?? '',
      customerId: row['customerId'] as String? ?? '',
      amount: (row['amount'] as num?)?.toDouble() ?? 0,
      dueDate: row['due_date'] as String? ?? '',
      status:
          row['status'] as String? ??
          StoreScheduledCreditRepaymentStatus.scheduled,
      collectedRepaymentId: (row['collected_repayment_id'] as num?)?.toInt(),
      createdOn: row['created_on'] as String? ?? '',
      updatedOn: row['updated_on'] as String? ?? '',
    );
  }
}

class StoreCreateScheduledCreditRepaymentRequest {
  final String customerId;
  final double amount;
  final String dueDate;
  final String? localId;
  final String? createdOn;

  const StoreCreateScheduledCreditRepaymentRequest({
    required this.customerId,
    required this.amount,
    required this.dueDate,
    this.localId,
    this.createdOn,
  });
}

class StoreCreditRepaymentAllocationRecord {
  final int id;
  final int repaymentId;
  final int creditId;
  final double allocatedAmount;

  const StoreCreditRepaymentAllocationRecord({
    required this.id,
    required this.repaymentId,
    required this.creditId,
    required this.allocatedAmount,
  });

  factory StoreCreditRepaymentAllocationRecord.fromRow(
    Map<String, dynamic> row,
  ) {
    return StoreCreditRepaymentAllocationRecord(
      id: (row['id'] as num?)?.toInt() ?? 0,
      repaymentId: (row['repayment_id'] as num?)?.toInt() ?? 0,
      creditId: (row['credit_id'] as num?)?.toInt() ?? 0,
      allocatedAmount: (row['allocated_amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class StoreCreditRepaymentRecord {
  final int id;
  final String orgId;
  final String storeId;
  final String localId;
  final int? remoteId;
  final String customerId;
  final String paymentMode;
  final double totalAmount;
  final double allocatedAmount;
  final double advanceAmount;
  final String? referenceId;
  final String paidOn;
  final String createdOn;
  final String updatedOn;
  final bool deleted;
  final String? deletedReason;
  final String? deletedByCustomerId;
  final String? deletedOn;

  const StoreCreditRepaymentRecord({
    required this.id,
    required this.orgId,
    required this.storeId,
    required this.localId,
    required this.remoteId,
    required this.customerId,
    required this.paymentMode,
    required this.totalAmount,
    required this.allocatedAmount,
    required this.advanceAmount,
    required this.referenceId,
    required this.paidOn,
    required this.createdOn,
    required this.updatedOn,
    required this.deleted,
    required this.deletedReason,
    required this.deletedByCustomerId,
    required this.deletedOn,
  });

  factory StoreCreditRepaymentRecord.fromRow(Map<String, dynamic> row) {
    return StoreCreditRepaymentRecord(
      id: (row['id'] as num?)?.toInt() ?? 0,
      orgId: row['orgId'] as String? ?? '',
      storeId: row['storeId'] as String? ?? '',
      localId: row['local_id'] as String? ?? '',
      remoteId: (row['remote_id'] as num?)?.toInt(),
      customerId: row['customerId'] as String? ?? '',
      paymentMode: row['payment_mode'] as String? ?? '',
      totalAmount: (row['total_amount'] as num?)?.toDouble() ?? 0,
      allocatedAmount: (row['allocated_amount'] as num?)?.toDouble() ?? 0,
      advanceAmount: (row['advance_amount'] as num?)?.toDouble() ?? 0,
      referenceId: row['reference_id'] as String?,
      paidOn: row['paid_on'] as String? ?? '',
      createdOn: row['created_on'] as String? ?? '',
      updatedOn: row['updated_on'] as String? ?? '',
      deleted: (row['deleted_on'] as String?) != null,
      deletedReason: row['deleted_reason'] as String?,
      deletedByCustomerId: row['deleted_by_customer_id'] as String?,
      deletedOn: row['deleted_on'] as String?,
    );
  }
}

class StoreCreateCreditRepaymentAllocationRequest {
  final int creditId;
  final double allocatedAmount;

  const StoreCreateCreditRepaymentAllocationRequest({
    required this.creditId,
    required this.allocatedAmount,
  });
}

class StoreCreateCreditRepaymentRequest {
  final String customerId;
  final String? localId;
  final int? remoteId;
  final String paymentMode;
  final double totalAmount;
  final String paidOn;
  final String? referenceId;
  final String? createdOn;
  final String? updatedOn;
  final List<StoreCreateCreditRepaymentAllocationRequest> allocations;

  const StoreCreateCreditRepaymentRequest({
    required this.customerId,
    this.localId,
    this.remoteId,
    required this.paymentMode,
    required this.totalAmount,
    required this.paidOn,
    required this.allocations,
    this.referenceId,
    this.createdOn,
    this.updatedOn,
  });

  double get allocatedTotal =>
      allocations.fold(0, (sum, item) => sum + item.allocatedAmount);
}

class StoreDeleteCreditRepaymentRequest {
  final String deletedByCustomerId;
  final String reason;
  final String? deletedOn;

  const StoreDeleteCreditRepaymentRequest({
    required this.deletedByCustomerId,
    required this.reason,
    this.deletedOn,
  });
}

class StoreCreateCreditRequest {
  final String orgId;
  final String? localId;
  final int? remoteId;
  final String customerId;
  final int orderId;
  final double amount;
  final String createdOn;
  final String? updatedOn;

  /// Optional ISO date (`YYYY-MM-DD`) for net terms.
  final String? dueDate;

  /// Formal installment count (2–4). Null/0 = one-shot.
  final int? installmentCount;

  /// `weekly` or `monthly`.
  final String? installmentCadence;

  const StoreCreateCreditRequest({
    required this.orgId,
    this.localId,
    this.remoteId,
    required this.customerId,
    required this.orderId,
    required this.amount,
    required this.createdOn,
    this.updatedOn,
    this.dueDate,
    this.installmentCount,
    this.installmentCadence,
  });

  Map<String, dynamic> toRow(StoreScope scope) {
    return {
      'orgId': orgId,
      'storeId': scope.storeId,
      'local_id': localId,
      'remote_id': remoteId,
      'customerId': customerId,
      'order_id': orderId,
      'amount': amount,
      'due_date': dueDate,
      'created_on': createdOn,
      'updated_on': updatedOn ?? createdOn,
    };
  }
}

/// Built installment preview / persist row for a credit schedule.
class StoreCreditInstallmentPlanItem {
  final int sequence;
  final double amount;
  final String dueDate;

  const StoreCreditInstallmentPlanItem({
    required this.sequence,
    required this.amount,
    required this.dueDate,
  });
}

class StoreCreditInstallmentRecord {
  final int id;
  final String? localId;
  final int? remoteId;
  final int creditId;
  final String? creditLocalId;
  final int sequence;
  final double amount;
  final double paidAmount;
  final String? dueDate;
  final String status;
  final String createdOn;
  final String updatedOn;

  const StoreCreditInstallmentRecord({
    required this.id,
    this.localId,
    this.remoteId,
    required this.creditId,
    this.creditLocalId,
    required this.sequence,
    required this.amount,
    required this.paidAmount,
    this.dueDate,
    required this.status,
    required this.createdOn,
    required this.updatedOn,
  });

  double get outstandingAmount {
    final left = amount - paidAmount;
    return left < 0 ? 0 : left;
  }

  bool get overdue {
    if (dueDate == null || dueDate!.isEmpty || outstandingAmount <= 0.0001) {
      return false;
    }
    if (status == 'paid' || status == 'void') return false;
    final due = DateTime.tryParse(dueDate!);
    if (due == null) return false;
    final today = DateTime.now();
    final dueDay = DateTime(due.year, due.month, due.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    return dueDay.isBefore(todayDay);
  }

  factory StoreCreditInstallmentRecord.fromRow(Map<String, dynamic> row) {
    return StoreCreditInstallmentRecord(
      id: (row['id'] as num).toInt(),
      localId: row['local_id'] as String?,
      remoteId: (row['remote_id'] as num?)?.toInt(),
      creditId: (row['credit_id'] as num).toInt(),
      creditLocalId: row['credit_local_id'] as String?,
      sequence: (row['sequence'] as num?)?.toInt() ?? 1,
      amount: (row['amount'] as num?)?.toDouble() ?? 0,
      paidAmount: (row['paid_amount'] as num?)?.toDouble() ?? 0,
      dueDate: row['due_date'] as String?,
      status: row['status'] as String? ?? 'open',
      createdOn: row['created_on'] as String? ?? '',
      updatedOn: row['updated_on'] as String? ?? '',
    );
  }
}

/// Build equal installment amounts with last-penny adjust.
List<StoreCreditInstallmentPlanItem> buildCreditInstallmentPlan({
  required double totalAmount,
  required int count,
  required String cadence,
  DateTime? startDate,
}) {
  final n = count < 1 ? 0 : count;
  if (n <= 0 || totalAmount <= 0) return const [];
  final cadenceKey = cadence.trim().toLowerCase() == 'monthly'
      ? 'monthly'
      : 'weekly';
  final base = startDate ?? DateTime.now();
  final unit = double.parse((totalAmount / n).toStringAsFixed(2));
  final amounts = List<double>.filled(n, unit);
  final allocated = double.parse((unit * (n - 1)).toStringAsFixed(2));
  amounts[n - 1] = double.parse((totalAmount - allocated).toStringAsFixed(2));

  return List.generate(n, (i) {
    late final DateTime due;
    if (cadenceKey == 'monthly') {
      due = DateTime(base.year, base.month + (i + 1), base.day);
    } else {
      due = base.add(Duration(days: 7 * (i + 1)));
    }
    final dueDate =
        '${due.year.toString().padLeft(4, '0')}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';
    return StoreCreditInstallmentPlanItem(
      sequence: i + 1,
      amount: amounts[i],
      dueDate: dueDate,
    );
  });
}

class StoreCustomerLedgerEntryType {
  static const String credit = 'credit';
  static const String repayment = 'repayment';
}

class StoreCustomerLedgerEntry {
  final String entryType;
  final int entryId;
  final String orgId;
  final String storeId;
  final String customerId;
  final String timestamp;
  final double amount;
  final int? orderId;
  final String? paymentMode;
  final String? referenceId;
  final double? paidAmount;
  final double? outstandingAmount;
  final bool? settled;
  final bool deleted;
  final String? deletedReason;
  final String? deletedByCustomerId;
  final String? deletedOn;
  final List<StoreCreditRepaymentAllocationRecord> allocations;

  const StoreCustomerLedgerEntry({
    required this.entryType,
    required this.entryId,
    required this.orgId,
    required this.storeId,
    required this.customerId,
    required this.timestamp,
    required this.amount,
    required this.orderId,
    required this.paymentMode,
    required this.referenceId,
    required this.paidAmount,
    required this.outstandingAmount,
    required this.settled,
    required this.deleted,
    required this.deletedReason,
    required this.deletedByCustomerId,
    required this.deletedOn,
    this.allocations = const [],
  });

  factory StoreCustomerLedgerEntry.credit(StoreCreditRecord credit) {
    return StoreCustomerLedgerEntry(
      entryType: StoreCustomerLedgerEntryType.credit,
      entryId: credit.id,
      orgId: credit.orgId,
      storeId: credit.storeId,
      customerId: credit.customerId,
      timestamp: credit.createdOn,
      amount: credit.amount,
      orderId: credit.orderId,
      paymentMode: null,
      referenceId: null,
      paidAmount: credit.paidAmount,
      outstandingAmount: credit.outstandingAmount,
      settled: credit.settled,
      deleted: false,
      deletedReason: null,
      deletedByCustomerId: null,
      deletedOn: null,
    );
  }

  factory StoreCustomerLedgerEntry.repayment(
    StoreCreditRepaymentRecord repayment, {
    List<StoreCreditRepaymentAllocationRecord> allocations = const [],
  }) {
    return StoreCustomerLedgerEntry(
      entryType: StoreCustomerLedgerEntryType.repayment,
      entryId: repayment.id,
      orgId: repayment.orgId,
      storeId: repayment.storeId,
      customerId: repayment.customerId,
      timestamp: repayment.paidOn,
      amount: repayment.totalAmount,
      orderId: null,
      paymentMode: repayment.paymentMode,
      referenceId: repayment.referenceId,
      paidAmount: null,
      outstandingAmount: null,
      settled: null,
      deleted: repayment.deleted,
      deletedReason: repayment.deletedReason,
      deletedByCustomerId: repayment.deletedByCustomerId,
      deletedOn: repayment.deletedOn,
      allocations: allocations,
    );
  }
}

class StoreSyncOperationResult {
  final String entity;
  final String direction;
  final int processedCount;
  final int successCount;
  final int failureCount;
  final bool skipped;
  final bool success;
  final String startedAt;
  final String completedAt;
  final String message;

  const StoreSyncOperationResult({
    required this.entity,
    required this.direction,
    required this.processedCount,
    required this.successCount,
    required this.failureCount,
    required this.skipped,
    required this.success,
    required this.startedAt,
    required this.completedAt,
    required this.message,
  });

  StoreSyncOperationResult copyWith({
    String? entity,
    String? direction,
    int? processedCount,
    int? successCount,
    int? failureCount,
    bool? skipped,
    bool? success,
    String? startedAt,
    String? completedAt,
    String? message,
  }) {
    return StoreSyncOperationResult(
      entity: entity ?? this.entity,
      direction: direction ?? this.direction,
      processedCount: processedCount ?? this.processedCount,
      successCount: successCount ?? this.successCount,
      failureCount: failureCount ?? this.failureCount,
      skipped: skipped ?? this.skipped,
      success: success ?? this.success,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      message: message ?? this.message,
    );
  }
}

/// Outcome of applying one orders import page.
class StoreOrderImportOutcome {
  final int appliedCount;
  final int skippedCount;
  final String? maxAppliedUpdatedOn;

  const StoreOrderImportOutcome({
    required this.appliedCount,
    required this.skippedCount,
    this.maxAppliedUpdatedOn,
  });
}

enum StoreSyncProgressStage { running, completed, skipped, failed }

class StoreSyncProgressUpdate {
  final String entity;
  final String direction;
  final StoreSyncProgressStage stage;
  final int processedCount;
  final int totalCount;
  final int successCount;
  final int failureCount;
  final int batchIndex;
  final int totalBatches;
  final String message;
  final String updatedAt;

  const StoreSyncProgressUpdate({
    required this.entity,
    required this.direction,
    required this.stage,
    required this.processedCount,
    required this.totalCount,
    required this.successCount,
    required this.failureCount,
    required this.batchIndex,
    required this.totalBatches,
    required this.message,
    required this.updatedAt,
  });

  double get progressFraction {
    if (totalCount <= 0) {
      return stage == StoreSyncProgressStage.completed ||
              stage == StoreSyncProgressStage.skipped
          ? 1
          : 0;
    }
    return processedCount / totalCount;
  }

  int get remainingCount {
    final remaining = totalCount - processedCount;
    return remaining > 0 ? remaining : 0;
  }

  bool get isFinished {
    return stage == StoreSyncProgressStage.completed ||
        stage == StoreSyncProgressStage.skipped ||
        stage == StoreSyncProgressStage.failed;
  }
}

class StoreSyncAttemptRecord {
  final int id;
  final String entity;
  final String direction;
  final String startedAt;
  final String completedAt;
  final int processedCount;
  final int successCount;
  final int failureCount;
  final bool skipped;
  final bool success;
  final String message;

  const StoreSyncAttemptRecord({
    required this.id,
    required this.entity,
    required this.direction,
    required this.startedAt,
    required this.completedAt,
    required this.processedCount,
    required this.successCount,
    required this.failureCount,
    required this.skipped,
    required this.success,
    required this.message,
  });

  factory StoreSyncAttemptRecord.fromRow(Map<String, dynamic> row) {
    return StoreSyncAttemptRecord(
      id: (row['id'] as num?)?.toInt() ?? 0,
      entity: row['entity'] as String? ?? '',
      direction: row['direction'] as String? ?? '',
      startedAt: row['started_at'] as String? ?? '',
      completedAt: row['completed_at'] as String? ?? '',
      processedCount: (row['processed_count'] as num?)?.toInt() ?? 0,
      successCount: (row['success_count'] as num?)?.toInt() ?? 0,
      failureCount: (row['failure_count'] as num?)?.toInt() ?? 0,
      skipped: ((row['skipped'] as num?)?.toInt() ?? 0) == 1,
      success: ((row['success'] as num?)?.toInt() ?? 0) == 1,
      message: row['message'] as String? ?? '',
    );
  }
}

class StoreSyncBatchResult {
  final List<StoreSyncOperationResult> operations;

  const StoreSyncBatchResult({required this.operations});

  int get processedCount =>
      operations.fold(0, (sum, item) => sum + item.processedCount);
}
