import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Store UI is enabled only when an approved product id is supplied. Receipt
/// verification happens in the callable before a transaction is completed.
class PurchaseService {
  PurchaseService({InAppPurchase? store, FirebaseFunctions? functions})
      : _store = store ?? InAppPurchase.instance,
        _functions = functions ?? FirebaseFunctions.instance;
  final InAppPurchase _store;
  final FirebaseFunctions _functions;
  StreamSubscription<List<PurchaseDetails>>? _updates;
  ProductDetails? annualProduct;
  String? unavailableReason;

  Future<void> initialise() async {
    final productId = dotenv.env['PARTWK_ANNUAL_PRODUCT_ID'];
    if (productId == null || productId.trim().isEmpty) { unavailableReason = 'Purchases are not configured for this build.'; return; }
    if (!await _store.isAvailable()) { unavailableReason = 'The store is unavailable. Try again later.'; return; }
    _updates ??= _store.purchaseStream.listen(_handlePurchases);
    final response = await _store.queryProductDetails({productId});
    if (response.error != null || response.productDetails.isEmpty) { unavailableReason = 'The annual subscription is not currently available.'; return; }
    annualProduct = response.productDetails.single;
  }

  Future<void> buyAnnual() async {
    final product = annualProduct;
    if (product == null) throw StateError(unavailableReason ?? 'Purchase setup is incomplete.');
    await _store.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));
  }
  Future<void> restore() => _store.restorePurchases();

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        try {
          await _functions.httpsCallable('verifyStorePurchase').call({
            'productId': purchase.productID,
            'source': purchase.verificationData.source,
            'serverVerificationData': purchase.verificationData.serverVerificationData,
            'localVerificationData': purchase.verificationData.localVerificationData,
          });
        } on FirebaseFunctionsException {
          // Do not complete/deliver an unverified transaction. It will be
          // redelivered and can be retried after server configuration.
          continue;
        }
      }
      if (purchase.pendingCompletePurchase) await _store.completePurchase(purchase);
    }
  }

  Future<void> dispose() async => _updates?.cancel();
}
