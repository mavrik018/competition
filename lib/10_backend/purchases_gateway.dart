/// In-app subscriptions through RevenueCat, behind a small interface so the
/// purchase logic can be tested with a fake.
///
/// Source: Cookly `features/subscription/application/purchases_gateway.dart`
/// and `domain/plan_tier.dart`. The interface exists because `Purchases` is
/// entirely static: Cookly's real bug was a customer-info listener detached
/// on sign-in and never re-attached, and only a fake that counts listeners
/// can catch that. Kept from the source:
///
/// * Configure **once** per process with the app's own user id, then switch
///   accounts with [PurchasesGateway.logIn] — never `logOut`, which strands
///   purchases on an anonymous customer.
/// * Google Play product ids arrive as `subscription:base-plan`; strip the
///   suffix before matching ([baseProductId]).
/// * Unlock features from your *server's* entitlement record (written by the
///   RevenueCat webhook), not from the SDK's `CustomerInfo`, which knows
///   about a purchase before your backend does.
///
/// ```dart
/// final purchases = ref.read(purchasesGatewayProvider);
/// if (!await purchases.isConfigured) {
///   await purchases.configure(apiKey: key, appUserId: uid);
/// } else {
///   await purchases.logIn(uid);
/// }
/// final offerings = await purchases.getOfferings();
/// await purchases.purchasePackage(offerings.current!.monthly!);
/// ```
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

abstract interface class PurchasesGateway {
  Future<bool> get isConfigured;
  Future<void> configure({required String apiKey, required String appUserId});
  Future<void> logIn(String appUserId);
  Future<Offerings> getOfferings();
  Future<PurchaseResult> purchasePackage(Package package);
  Future<CustomerInfo> restorePurchases();
  void addCustomerInfoUpdateListener(void Function(CustomerInfo) listener);
  void removeCustomerInfoUpdateListener(void Function(CustomerInfo) listener);
}

class RevenueCatGateway implements PurchasesGateway {
  const RevenueCatGateway();

  @override
  Future<bool> get isConfigured => Purchases.isConfigured;

  @override
  Future<void> configure({required String apiKey, required String appUserId}) =>
      // Supplying the id at configure time means an anonymous customer never
      // exists, even briefly.
      Purchases.configure(
        PurchasesConfiguration(apiKey)..appUserID = appUserId,
      );

  @override
  Future<void> logIn(String appUserId) => Purchases.logIn(appUserId);

  @override
  Future<Offerings> getOfferings() => Purchases.getOfferings();

  @override
  Future<PurchaseResult> purchasePackage(Package package) =>
      Purchases.purchase(PurchaseParams.package(package));

  @override
  Future<CustomerInfo> restorePurchases() => Purchases.restorePurchases();

  @override
  void addCustomerInfoUpdateListener(void Function(CustomerInfo) listener) =>
      Purchases.addCustomerInfoUpdateListener(listener);

  @override
  void removeCustomerInfoUpdateListener(void Function(CustomerInfo) listener) =>
      Purchases.removeCustomerInfoUpdateListener(listener);
}

final purchasesGatewayProvider = Provider<PurchasesGateway>(
  (ref) => const RevenueCatGateway(),
);

/// `premium_monthly:monthly-base` → `premium_monthly`.
String baseProductId(String productId) => productId.split(':').first;

/// The plan a store product grants, from a `{productId: plan}` table that
/// must match App Store Connect, the Play Console and your server.
/// Unknown products grant [fallback].
T planForProduct<T>(String? productId, Map<String, T> plans, T fallback) {
  if (productId == null) return fallback;
  return plans[baseProductId(productId)] ?? fallback;
}
