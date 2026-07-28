part of 'store.dart';

class StoreTablesService {
  final Store _store;

  StoreTablesService._(this._store);

  Future<String> saveFloor(StoreScope scope, StoreSaveFloorRequest request) {
    return _store._saveFloor(scope, request);
  }

  Future<List<StoreFloorRecord>> listFloors(StoreScope scope) {
    return _store._listFloorRecords(scope);
  }

  Future<void> importFromJsonFile(StoreScope scope, String filePath) {
    return _store._importTablesFromJsonFile(scope, filePath);
  }

  Future<void> importFromData(StoreScope scope, Map<String, dynamic> data) {
    return _store._importTablesFromData(scope, data);
  }

  Future<Map<String, dynamic>> exportToJsonData(StoreScope scope) {
    return _store._exportTablesToJsonData(scope);
  }

  Future<void> exportToJsonFile(StoreScope scope, String filePath) {
    return _store._exportTablesToJsonFile(scope, filePath);
  }

  Future<String> saveTable(StoreScope scope, StoreSaveTableRequest request) {
    return _store._saveTable(scope, request);
  }

  Future<List<StoreTableRecord>> listTables(
    StoreScope scope, {
    String? floorId,
    bool includeInactive = true,
    bool includeOccupied = true,
  }) {
    return _store._listTableRecords(
      scope,
      floorId: floorId,
      includeInactive: includeInactive,
      includeOccupied: includeOccupied,
    );
  }

  Future<List<StoreTableRecord>> listAvailableTables(
    StoreScope scope, {
    String? floorId,
  }) {
    return _store._listTableRecords(
      scope,
      floorId: floorId,
      includeInactive: false,
      includeOccupied: false,
    );
  }
}
