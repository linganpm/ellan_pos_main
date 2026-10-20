import 'store_models.dart';

class StoreOfferEvaluationItem {
  final int orderItemId;
  final List<String> productTargetIds;
  final List<String> categoryTargetIds;
  final int quantity;
  final double unitPrice;

  const StoreOfferEvaluationItem({
    required this.orderItemId,
    required this.productTargetIds,
    required this.categoryTargetIds,
    required this.quantity,
    required this.unitPrice,
  });
}

class StoreOfferPricingResult {
  final double subtotal;
  final double orderLevelDiscount;
  final double totalDiscount;
  final double total;
  final Map<int, double> itemDiscounts;
  final Map<int, List<String>> itemAppliedOfferIds;
  final List<StoreAppliedOfferRecord> appliedOffers;

  const StoreOfferPricingResult({
    required this.subtotal,
    required this.orderLevelDiscount,
    required this.totalDiscount,
    required this.total,
    required this.itemDiscounts,
    required this.itemAppliedOfferIds,
    required this.appliedOffers,
  });
}

class StoreOfferEngine {
  static StoreOfferPricingResult calculate({
    required List<StoreOfferRecord> offers,
    required List<StoreOfferEvaluationItem> items,
  }) {
    final lineOffers = offers.where((offer) => offer.offerType != StoreOfferType.totalOffer).toList(growable: false);
    final billOffers = offers.where((offer) => offer.offerType == StoreOfferType.totalOffer).toList(growable: false);
    final units = <_OfferUnit>[];
    for (final item in items) {
      for (var index = 0; index < item.quantity; index++) {
        units.add(
          _OfferUnit(
            orderItemId: item.orderItemId,
            productTargetIds: item.productTargetIds,
            categoryTargetIds: item.categoryTargetIds,
            unitPrice: item.unitPrice,
          ),
        );
      }
    }

    final subtotal = units.fold<double>(0, (total, unit) => total + unit.unitPrice);
    final remainingUnitIndexes = <int>{for (var index = 0; index < units.length; index++) index};
    final itemDiscounts = <int, double>{
      for (final item in items) item.orderItemId: 0,
    };
    final itemAppliedOfferIds = <int, List<String>>{
      for (final item in items) item.orderItemId: <String>[],
    };
    final appliedOffers = <StoreAppliedOfferRecord>[];

    while (true) {
      _OfferCandidate? bestCandidate;
      for (final offer in lineOffers.where((offer) => offer.active)) {
        final candidate = _buildCandidate(offer, units, remainingUnitIndexes);
        if (candidate == null || candidate.totalDiscount <= 0) {
          continue;
        }
        if (bestCandidate == null
            || candidate.totalDiscount > bestCandidate.totalDiscount + 0.0001
            || ((candidate.totalDiscount - bestCandidate.totalDiscount).abs() <= 0.0001
                && candidate.consumedUnitIndexes.length < bestCandidate.consumedUnitIndexes.length)
            || ((candidate.totalDiscount - bestCandidate.totalDiscount).abs() <= 0.0001
                && candidate.consumedUnitIndexes.length == bestCandidate.consumedUnitIndexes.length
                && offer.localId.compareTo(bestCandidate.offer.localId) < 0)) {
          bestCandidate = candidate;
        }
      }

      if (bestCandidate == null) {
        break;
      }

      final resolvedCandidate = bestCandidate;

      for (final unitIndex in resolvedCandidate.consumedUnitIndexes) {
        remainingUnitIndexes.remove(unitIndex);
      }
      final matchedOrderItemIds = <int>{};
      resolvedCandidate.unitDiscounts.forEach((unitIndex, discount) {
        final unit = units[unitIndex];
        matchedOrderItemIds.add(unit.orderItemId);
        itemDiscounts[unit.orderItemId] = (itemDiscounts[unit.orderItemId] ?? 0) + discount;
        final offerIds = itemAppliedOfferIds.putIfAbsent(unit.orderItemId, () => <String>[]);
        if (!offerIds.contains(resolvedCandidate.offer.localId)) {
          offerIds.add(resolvedCandidate.offer.localId);
        }
      });
      appliedOffers.add(
        StoreAppliedOfferRecord(
          localId: resolvedCandidate.offer.localId,
          name: resolvedCandidate.offer.name,
          targetType: resolvedCandidate.offer.targetType,
          offerType: resolvedCandidate.offer.offerType,
          discountAmount: resolvedCandidate.totalDiscount,
          orderItemIds: matchedOrderItemIds.toList(growable: false),
        ),
      );
    }

    final itemLevelDiscount = itemDiscounts.values.fold<double>(0, (total, value) => total + value);
    final runningTotal = subtotal - itemLevelDiscount;
    final billOffer = _selectBestBillOffer(
      offers: billOffers,
      subtotal: subtotal,
      runningTotal: runningTotal,
      orderItemIds: items.map((item) => item.orderItemId).toList(growable: false),
    );
    final orderLevelDiscount = billOffer?.discountAmount ?? 0;
    final totalDiscount = itemLevelDiscount + orderLevelDiscount;
    if (billOffer != null) {
      appliedOffers.add(billOffer);
    }
    return StoreOfferPricingResult(
      subtotal: subtotal,
      orderLevelDiscount: orderLevelDiscount,
      totalDiscount: totalDiscount,
      total: subtotal - totalDiscount,
      itemDiscounts: itemDiscounts,
      itemAppliedOfferIds: itemAppliedOfferIds.map(
        (key, value) => MapEntry(key, value.toList(growable: false)),
      ),
      appliedOffers: appliedOffers,
    );
  }

  static StoreAppliedOfferRecord? _selectBestBillOffer({
    required List<StoreOfferRecord> offers,
    required double subtotal,
    required double runningTotal,
    required List<int> orderItemIds,
  }) {
    StoreAppliedOfferRecord? bestOffer;
    for (final offer in offers.where((offer) => offer.active)) {
      final percentage = offer.percentageValue ?? 0;
      final minimumBillAmount = offer.minimumBillAmount ?? 0;
      if (percentage <= 0 || minimumBillAmount <= 0 || subtotal + 0.0001 < minimumBillAmount || runningTotal <= 0) {
        continue;
      }
      final discountAmount = runningTotal * percentage / 100;
      if (discountAmount <= 0) {
        continue;
      }
      final candidate = StoreAppliedOfferRecord(
        localId: offer.localId,
        name: offer.name,
        targetType: offer.targetType,
        offerType: offer.offerType,
        discountAmount: discountAmount,
        orderItemIds: orderItemIds,
      );
      if (bestOffer == null
          || candidate.discountAmount > bestOffer.discountAmount + 0.0001
          || ((candidate.discountAmount - bestOffer.discountAmount).abs() <= 0.0001
              && candidate.localId.compareTo(bestOffer.localId) < 0)) {
        bestOffer = candidate;
      }
    }
    return bestOffer;
  }

  static _OfferCandidate? _buildCandidate(
    StoreOfferRecord offer,
    List<_OfferUnit> units,
    Set<int> remainingUnitIndexes,
  ) {
    final eligibleIndexes = remainingUnitIndexes.where((index) => _matchesOffer(offer, units[index])).toList(growable: false);
    if (eligibleIndexes.isEmpty) {
      return null;
    }

    switch (offer.offerType) {
      case StoreOfferType.percentage:
        final percentage = offer.percentageValue ?? 0;
        if (percentage <= 0) {
          return null;
        }
        final unitDiscounts = _allocateProportionalDiscount(
          eligibleIndexes,
          units,
          eligibleIndexes.fold<double>(0, (total, index) => total + units[index].unitPrice) * percentage / 100,
        );
        return _OfferCandidate(
          offer: offer,
          consumedUnitIndexes: eligibleIndexes,
          unitDiscounts: unitDiscounts,
          totalDiscount: unitDiscounts.values.fold<double>(0, (total, value) => total + value),
        );
      case StoreOfferType.flat:
        final flatValue = offer.flatValue ?? 0;
        final eligibleSubtotal = eligibleIndexes.fold<double>(0, (total, index) => total + units[index].unitPrice);
        final totalDiscount = flatValue <= eligibleSubtotal ? flatValue : eligibleSubtotal;
        if (totalDiscount <= 0) {
          return null;
        }
        final unitDiscounts = _allocateProportionalDiscount(eligibleIndexes, units, totalDiscount);
        return _OfferCandidate(
          offer: offer,
          consumedUnitIndexes: eligibleIndexes,
          unitDiscounts: unitDiscounts,
          totalDiscount: unitDiscounts.values.fold<double>(0, (total, value) => total + value),
        );
      case StoreOfferType.fixedPrice:
        final fixedPrice = offer.flatValue;
        final bundleSize = offer.buyQuantity ?? 1;
        if (fixedPrice == null || fixedPrice < 0 || bundleSize <= 0 || eligibleIndexes.length < bundleSize) {
          return null;
        }
        // Bundle the most expensive units first so the customer gets the best deal.
        final sortedByPriceDesc = eligibleIndexes.toList(growable: false)
          ..sort((left, right) => units[right].unitPrice.compareTo(units[left].unitPrice));
        final consumedIndexes = <int>[];
        final unitDiscounts = <int, double>{};
        for (var start = 0; start + bundleSize <= sortedByPriceDesc.length; start += bundleSize) {
          final bundle = sortedByPriceDesc.sublist(start, start + bundleSize);
          final bundleTotal = bundle.fold<double>(0, (total, index) => total + units[index].unitPrice);
          final discount = bundleTotal - fixedPrice;
          if (discount <= 0) {
            continue;
          }
          consumedIndexes.addAll(bundle);
          unitDiscounts.addAll(_allocateProportionalDiscount(bundle, units, discount));
        }
        if (unitDiscounts.isEmpty) {
          return null;
        }
        return _OfferCandidate(
          offer: offer,
          consumedUnitIndexes: consumedIndexes,
          unitDiscounts: unitDiscounts,
          totalDiscount: unitDiscounts.values.fold<double>(0, (total, value) => total + value),
        );
      case StoreOfferType.buyNGetM:
      case StoreOfferType.buyNGetMDiscount:
        final isDiscounted = offer.offerType == StoreOfferType.buyNGetMDiscount;
        final getPercentage = isDiscounted ? (offer.percentageValue ?? 0) : 100.0;
        if (getPercentage <= 0 || getPercentage > 100) {
          return null;
        }
        final buyQuantity = offer.buyQuantity ?? 0;
        final getQuantity = offer.getQuantity ?? 0;
        final groupSize = buyQuantity + getQuantity;
        if (buyQuantity <= 0 || getQuantity <= 0 || eligibleIndexes.length < groupSize) {
          return null;
        }
        final bundleCount = eligibleIndexes.length ~/ groupSize;
        final freeUnitCount = bundleCount * getQuantity;
        final paidUnitCount = bundleCount * buyQuantity;
        final sortedByPriceAsc = eligibleIndexes.toList(growable: false)
          ..sort((left, right) => units[left].unitPrice.compareTo(units[right].unitPrice));
        final freeIndexes = sortedByPriceAsc.take(freeUnitCount).toList(growable: false);
        final remainingAfterFree = sortedByPriceAsc.skip(freeUnitCount).toList(growable: false)
          ..sort((left, right) => units[right].unitPrice.compareTo(units[left].unitPrice));
        final paidIndexes = remainingAfterFree.take(paidUnitCount).toList(growable: false);
        final consumedIndexes = [...freeIndexes, ...paidIndexes];
        if (freeIndexes.isEmpty || consumedIndexes.isEmpty) {
          return null;
        }
        final unitDiscounts = <int, double>{
          for (final index in freeIndexes) index: units[index].unitPrice * getPercentage / 100,
        };
        return _OfferCandidate(
          offer: offer,
          consumedUnitIndexes: consumedIndexes,
          unitDiscounts: unitDiscounts,
          totalDiscount: unitDiscounts.values.fold<double>(0, (total, value) => total + value),
        );
    }
    return null;
  }

  static bool _matchesOffer(StoreOfferRecord offer, _OfferUnit unit) {
    if (offer.targetType == StoreOfferTargetType.category) {
      return unit.categoryTargetIds.any(offer.targetIds.contains);
    }
    return unit.productTargetIds.any(offer.targetIds.contains);
  }

  static Map<int, double> _allocateProportionalDiscount(
    List<int> eligibleIndexes,
    List<_OfferUnit> units,
    double totalDiscount,
  ) {
    if (eligibleIndexes.isEmpty || totalDiscount <= 0) {
      return const {};
    }
    final eligibleSubtotal = eligibleIndexes.fold<double>(0, (total, index) => total + units[index].unitPrice);
    if (eligibleSubtotal <= 0) {
      return const {};
    }
    final discounts = <int, double>{};
    var remainingDiscount = totalDiscount;
    for (var index = 0; index < eligibleIndexes.length; index++) {
      final unitIndex = eligibleIndexes[index];
      final unitPrice = units[unitIndex].unitPrice;
      final discount = index == eligibleIndexes.length - 1
          ? remainingDiscount
          : totalDiscount * (unitPrice / eligibleSubtotal);
      final safeDiscount = discount <= unitPrice ? discount : unitPrice;
      discounts[unitIndex] = safeDiscount;
      remainingDiscount -= safeDiscount;
    }
    return discounts;
  }
}

class _OfferUnit {
  final int orderItemId;
  final List<String> productTargetIds;
  final List<String> categoryTargetIds;
  final double unitPrice;

  const _OfferUnit({
    required this.orderItemId,
    required this.productTargetIds,
    required this.categoryTargetIds,
    required this.unitPrice,
  });
}

class _OfferCandidate {
  final StoreOfferRecord offer;
  final List<int> consumedUnitIndexes;
  final Map<int, double> unitDiscounts;
  final double totalDiscount;

  const _OfferCandidate({
    required this.offer,
    required this.consumedUnitIndexes,
    required this.unitDiscounts,
    required this.totalDiscount,
  });
}