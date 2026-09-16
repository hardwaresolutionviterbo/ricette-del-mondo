import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PremiumPlan {
  final String id;
  final String durationLabel;
  final String fallbackPrice;
  final String typeLabel;
  final String detail;
  final bool autoRenew;
  final int months;

  const PremiumPlan({
    required this.id,
    required this.durationLabel,
    required this.fallbackPrice,
    required this.typeLabel,
    required this.detail,
    required this.autoRenew,
    required this.months,
  });
}

/// Integrazione Google Play Billing.
/// 
/// I prodotti vengono letti direttamente da Google Play quando l'app è
/// installata da un canale di test/produzione di Google Play. Prima che i
/// prodotti siano pubblicati in Play Console, la schermata Premium continua
/// a mostrare i prezzi configurati nell'app e spiega che il prodotto non è
/// ancora disponibile sullo store.
class GooglePlayBillingService extends ChangeNotifier {
  GooglePlayBillingService._() {
    _purchaseSubscription = InAppPurchase.instance.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object error, StackTrace stack) {
        _setMessage('Errore durante la comunicazione con Google Play.');
      },
    );
  }

  static final GooglePlayBillingService instance = GooglePlayBillingService._();

  static const plans = <PremiumPlan>[
    PremiumPlan(
      id: 'premium_monthly_auto',
      durationLabel: '1 mese',
      fallbackPrice: '€2,99',
      typeLabel: 'Rinnovo automatico',
      detail: 'Si rinnova ogni mese',
      autoRenew: true,
      months: 1,
    ),
    PremiumPlan(
      id: 'premium_6months_auto',
      durationLabel: '6 mesi',
      fallbackPrice: '€14,99',
      typeLabel: 'Rinnovo automatico',
      detail: 'Si rinnova ogni 6 mesi',
      autoRenew: true,
      months: 6,
    ),
    PremiumPlan(
      id: 'premium_yearly_auto',
      durationLabel: '12 mesi',
      fallbackPrice: '€24,99',
      typeLabel: 'Rinnovo automatico',
      detail: 'Si rinnova ogni 12 mesi',
      autoRenew: true,
      months: 12,
    ),
    PremiumPlan(
      id: 'premium_monthly_once',
      durationLabel: '1 mese',
      fallbackPrice: '€3,49',
      typeLabel: 'Una tantum',
      detail: 'Nessun rinnovo automatico',
      autoRenew: false,
      months: 1,
    ),
    PremiumPlan(
      id: 'premium_6months_once',
      durationLabel: '6 mesi',
      fallbackPrice: '€16,99',
      typeLabel: 'Una tantum',
      detail: 'Nessun rinnovo automatico',
      autoRenew: false,
      months: 6,
    ),
    PremiumPlan(
      id: 'premium_yearly_once',
      durationLabel: '12 mesi',
      fallbackPrice: '€29,99',
      typeLabel: 'Una tantum',
      detail: 'Nessun rinnovo automatico',
      autoRenew: false,
      months: 12,
    ),
  ];

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  bool _initialized = false;
  bool _loading = false;
  bool _available = false;
  String? _message;
  String? _purchasingProductId;
  Map<String, ProductDetails> _products = <String, ProductDetails>{};

  bool get initialized => _initialized;
  bool get loading => _loading;
  bool get available => _available;
  String? get message => _message;
  String? get purchasingProductId => _purchasingProductId;
  Map<String, ProductDetails> get products => Map.unmodifiable(_products);

  ProductDetails? productFor(PremiumPlan plan) => _products[plan.id];

  String priceFor(PremiumPlan plan) =>
      _products[plan.id]?.price ?? plan.fallbackPrice;

  Future<void> initialize() async {
    if (_loading) return;

    _loading = true;
    _message = null;
    notifyListeners();

    try {
      _available = await _iap.isAvailable();
      if (!_available) {
        _message = 'Google Play non è disponibile su questo dispositivo.';
        return;
      }

      final response = await _iap.queryProductDetails(
        plans.map((plan) => plan.id).toSet(),
      );

      _products = <String, ProductDetails>{
        for (final product in response.productDetails)
          product.id: product,
      };

      if (response.error != null) {
        _message = response.error!.message;
      } else if (response.notFoundIDs.isNotEmpty) {
        _message =
            'Alcuni prodotti non sono ancora disponibili su Google Play. '
            'Dopo la pubblicazione dei prodotti nel test interno verranno caricati automaticamente.';
      } else {
        _message = null;
      }

      _initialized = true;
    } catch (_) {
      _available = false;
      _message =
          'Non è stato possibile collegarsi a Google Play. Riprova dal test interno.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> buy(PremiumPlan plan) async {
    final product = productFor(plan);
    if (product == null) {
      _setMessage(
        'Il prodotto "${plan.id}" non è ancora disponibile su Google Play. '
        'Configuralo in Play Console e pubblicalo nel canale di test interno.',
      );
      return;
    }

    if (_purchasingProductId != null) return;

    _purchasingProductId = plan.id;
    _message = null;
    notifyListeners();

    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      // L'esito reale arriva da purchaseStream.
    } catch (_) {
      _purchasingProductId = null;
      _setMessage('Impossibile avviare il pagamento Google Play.');
    }
  }

  Future<void> restorePurchases() async {
    if (_loading) return;

    _loading = true;
    _message = null;
    notifyListeners();

    try {
      final available = await _iap.isAvailable();
      if (!available) {
        _available = false;
        _message = 'Google Play non è disponibile su questo dispositivo.';
        return;
      }

      await _iap.restorePurchases();
      _available = true;
      _message =
          'Ripristino acquisti avviato. Attendi qualche secondo per l’aggiornamento del Premium.';
    } catch (_) {
      _message = 'Non è stato possibile ripristinare gli acquisti.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        _purchasingProductId = purchase.productID;
        _setMessage('Pagamento in attesa di conferma da Google Play.');
        continue;
      }

      if (purchase.status == PurchaseStatus.error) {
        _purchasingProductId = null;
        _setMessage(
          purchase.error?.message ?? 'Google Play non ha completato il pagamento.',
        );
      } else if (purchase.status == PurchaseStatus.canceled) {
        _purchasingProductId = null;
        _setMessage('Pagamento annullato.');
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final plan = _findPlan(purchase.productID);
        if (plan != null) {
          await _saveEntitlement(plan);
          _message = purchase.status == PurchaseStatus.restored
              ? 'Acquisto Premium ripristinato.'
              : 'Pagamento completato. Premium attivato.';
        } else {
          _message = 'Acquisto ricevuto, ma piano Premium non riconosciuto.';
        }
        _purchasingProductId = null;
      }

      if (purchase.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(purchase);
        } catch (_) {
          _message =
              'Pagamento ricevuto, ma la conferma finale di Google Play non è riuscita. Riapri Premium per riprovare.';
        }
      }

      notifyListeners();
    }
  }

  PremiumPlan? _findPlan(String productId) {
    for (final plan in plans) {
      if (plan.id == productId) return plan;
    }
    return null;
  }

  Future<void> _saveEntitlement(PremiumPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    final until = _addMonths(DateTime.now(), plan.months);

    await prefs.setBool('rdm_premium_active', true);
    await prefs.setString('rdm_premium_plan', plan.durationLabel);
    await prefs.setBool('rdm_premium_auto_renew', plan.autoRenew);
    await prefs.setString('rdm_premium_until', until.toIso8601String());

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        <String, dynamic>{
          'isPremium': true,
          'premiumActive': true,
          'premiumPlan': plan.durationLabel,
          'premiumProductId': plan.id,
          'autoRenew': plan.autoRenew,
          'premiumUntil': Timestamp.fromDate(until),
          'premiumSource': 'google_play',
          'premiumUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Il pagamento non deve essere bloccato se Firebase non è raggiungibile.
    }
  }

  void _setMessage(String value) {
    _message = value;
    notifyListeners();
  }

  DateTime _addMonths(DateTime date, int months) {
    final targetYear = date.year + ((date.month - 1 + months) ~/ 12);
    final targetMonth = ((date.month - 1 + months) % 12) + 1;
    final lastDay = DateTime(targetYear, targetMonth + 1, 0).day;
    final day = date.day > lastDay ? lastDay : date.day;
    return DateTime(
      targetYear,
      targetMonth,
      day,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }
}
