part of 'store.dart';

class StoreCreditsService {
  final Store _store;

  StoreCreditsService._(this._store);

  Future<List<StoreCreditRecord>> listRecords(
    StoreScope scope, {
    String? customerId,
  }) {
    return _store._listCreditRecords(scope, customerId: customerId);
  }

  Future<List<StoreCustomerCreditSummary>> listCreditorsByCustomer(
    StoreScope scope, {
    String sortBy = StoreCreditCustomerSortBy.amount,
    bool descending = true,
  }) {
    return _store._listCustomerCreditSummaries(
      scope,
      sortBy: sortBy,
      descending: descending,
    );
  }

  Future<List<StoreCreditRecord>> listRecordsByDate(
    StoreScope scope, {
    required StoreCreditDateFilter filter,
    String? customerId,
  }) {
    return _store._listCreditRecordsByDate(
      scope,
      filter: filter,
      customerId: customerId,
    );
  }

  Future<int> create(StoreScope scope, StoreCreateCreditRequest request) {
    return _store._createCreditRecord(scope, request);
  }

  Future<List<StoreCreditInstallmentRecord>> listInstallments(
    StoreScope scope, {
    int? creditId,
  }) {
    return _store._listCreditInstallments(scope, creditId: creditId);
  }

  Future<int> recordRepayment(
    StoreScope scope,
    StoreCreateCreditRepaymentRequest request,
  ) {
    return _store._recordCreditRepayment(scope, request);
  }

  /// Collect payment against a customer's open credits (oldest first).
  Future<int> recordRepaymentFifo(
    StoreScope scope, {
    required String customerId,
    required double amount,
    required String paymentMode,
    String? referenceId,
    String? paidOn,
    int? preferCreditId,
  }) {
    return _store._recordCreditRepaymentFifo(
      scope,
      customerId: customerId,
      amount: amount,
      paymentMode: paymentMode,
      referenceId: referenceId,
      paidOn: paidOn,
      preferCreditId: preferCreditId,
    );
  }

  Future<int> deleteRepayment(
    StoreScope scope,
    int repaymentId,
    StoreDeleteCreditRepaymentRequest request,
  ) {
    return _store._deleteCreditRepayment(scope, repaymentId, request);
  }

  Future<StoreCreditAccountRecord?> getAccountByCustomer(
    StoreScope scope,
    String customerId,
  ) {
    return _store._getCreditAccountByCustomer(scope, customerId);
  }

  /// Store defaults from the most recent credits import (clears after read).
  Map<String, dynamic>? takeImportedStoreSettings() {
    return _store.takeImportedCreditStoreSettings();
  }

  Future<List<StoreCreditRepaymentRecord>> listRepayments(
    StoreScope scope, {
    String? customerId,
    bool includeDeleted = false,
  }) {
    return _store._listCreditRepaymentRecords(
      scope,
      customerId: customerId,
      includeDeleted: includeDeleted,
    );
  }

  Future<List<StoreCreditRepaymentRecord>> listRepaymentAudit(
    StoreScope scope, {
    String? customerId,
  }) {
    return _store._listCreditRepaymentRecords(
      scope,
      customerId: customerId,
      includeDeleted: true,
    );
  }

  Future<List<StoreCreditRepaymentAllocationRecord>> listRepaymentAllocations(
    StoreScope scope,
    int repaymentId,
  ) {
    return _store._listCreditRepaymentAllocationRecords(scope, repaymentId);
  }

  Future<List<StoreCustomerLedgerEntry>> customerLedger(
    StoreScope scope, {
    required String customerId,
    bool includeDeleted = false,
  }) {
    return _store._listCustomerLedgerEntries(
      scope,
      customerId: customerId,
      includeDeleted: includeDeleted,
    );
  }

  Future<List<StoreCustomerLedgerEntry>> customerLedgerAudit(
    StoreScope scope, {
    required String customerId,
  }) {
    return _store._listCustomerLedgerEntries(
      scope,
      customerId: customerId,
      includeDeleted: true,
    );
  }

  Future<List<StoreScheduledCreditRepayment>> listScheduledRepayments(
    StoreScope scope, {
    String? customerId,
    bool includeClosed = false,
  }) {
    return _store._listScheduledCreditRepayments(
      scope,
      customerId: customerId,
      includeClosed: includeClosed,
    );
  }

  Future<int> scheduleRepayment(
    StoreScope scope,
    StoreCreateScheduledCreditRepaymentRequest request,
  ) {
    return _store._createScheduledCreditRepayment(scope, request);
  }

  Future<int> cancelScheduledRepayment(StoreScope scope, int scheduleId) {
    return _store._cancelScheduledCreditRepayment(scope, scheduleId);
  }

  Future<int> collectScheduledRepayment(
    StoreScope scope, {
    required int scheduleId,
    required String paymentMode,
    String? referenceId,
    String? paidOn,
    double? amount,
  }) {
    return _store._collectScheduledCreditRepayment(
      scope,
      scheduleId: scheduleId,
      paymentMode: paymentMode,
      referenceId: referenceId,
      paidOn: paidOn,
      amountOverride: amount,
    );
  }
}
