import '../../core/utils/result.dart';

/// Purchases — interface only in Phase 1 (Conventions §1.2). The
/// RevenueCat implementation (`purchase_service_impl.dart`, the only file
/// that may import `purchases_flutter`) lands in Phase 3, Task 3.1.
/// Prices ALWAYS come from the store through [offerings] — never
/// hard-coded (Requirements §9, AGENTS.md).
abstract interface class PurchaseService {
  /// Live entitlement state (true = Pro).
  Stream<bool> get isPro;

  /// Store offerings with live store prices.
  Future<Result<List<StoreOffering>>> offerings();

  /// Starts the store purchase flow for [offeringId].
  Future<Result<bool>> purchase(String offeringId);

  /// Restores previous purchases.
  Future<Result<bool>> restore();
}

/// One store product as presented by the store (price string included).
class StoreOffering {
  const StoreOffering({
    required this.id,
    required this.title,
    required this.priceString,
    required this.period,
  });

  final String id;
  final String title;

  /// Localised price exactly as supplied by the store.
  final String priceString;

  /// e.g. `year`, `month`, `lifetime`.
  final String period;
}
