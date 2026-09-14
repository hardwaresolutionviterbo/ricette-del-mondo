import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ad_consent_service.dart';

/// Gestisce gli annunci interstitial delle ricette gratuite.
///
/// Unità interstitial reale di AdMob per Ricette del Mondo.
/// Durante lo sviluppo su dispositivi/test build va usato un dispositivo di test
/// o la modalità di test di AdMob per evitare impressioni non valide.
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  static const _interstitialId = 'ca-app-pub-3671849539323271/8124810636';
  InterstitialAd? _interstitial;
  bool _loading = false;
  DateTime? _lastShown;

  bool get _cooldownActive =>
      _lastShown != null && DateTime.now().difference(_lastShown!) < const Duration(seconds: 60);

  void preload() {
    if (!AdConsentService.instance.canRequestAds) return;
    if (_loading || _interstitial != null) return;
    _loading = true;
    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loading = false;
          _interstitial = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitial = null;
              preload();
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              _interstitial = null;
              preload();
            },
          );
        },
        onAdFailedToLoad: (_) {
          _loading = false;
          _interstitial = null;
        },
      ),
    );
  }

  Future<void> showInterstitialIfReady() async {
    final prefs = await SharedPreferences.getInstance();
    if (!AdConsentService.instance.canRequestAds) return;
    // Premium reale verrà collegato in seguito al sistema di acquisto.
    // Quando attivo, questo flag impedisce qualsiasi richiesta di pubblicità.
    if (prefs.getBool('rdm_premium_active') ?? false) return;
    if (_cooldownActive) {
      preload();
      return;
    }

    final ad = _interstitial;
    if (ad == null) {
      preload();
      return;
    }

    _interstitial = null;
    _lastShown = DateTime.now();
    final completer = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        preload();
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        preload();
        if (!completer.isCompleted) completer.complete();
      },
    );

    try {
      await ad.show();
      await completer.future;
    } catch (_) {
      ad.dispose();
      preload();
      if (!completer.isCompleted) completer.complete();
    }
  }
}
