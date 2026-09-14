import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Gestisce il consenso pubblicitario tramite Google UMP.
///
/// Il consenso viene aggiornato ad ogni avvio, come richiesto dalla
/// documentazione Google. Gli annunci vengono richiesti solo quando UMP
/// segnala che possono essere richiesti.
class AdConsentService {
  AdConsentService._();
  static final AdConsentService instance = AdConsentService._();

  bool _initialized = false;
  bool _canRequestAds = false;
  bool _privacyOptionsRequired = false;

  bool get canRequestAds => _canRequestAds;
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  Future<bool> initialize() async {
    if (_initialized) return _canRequestAds;

    final info = ConsentInformation.instance;
    final params = ConsentRequestParameters();

    try {
      final completed = Completer<void>();
      info.requestConsentInfoUpdate(
        params,
        () async {
          try {
            await ConsentForm.loadAndShowConsentFormIfRequired((error) {
              if (error != null) {
                debugPrint('UMP consent form: ${error.errorCode} ${error.message}');
              }
            });
          } finally {
            if (!completed.isCompleted) completed.complete();
          }
        },
        (error) {
          debugPrint('UMP consent update: ${error.errorCode} ${error.message}');
          if (!completed.isCompleted) completed.complete();
        },
      );
      await completed.future;
    } catch (e) {
      debugPrint('UMP initialization error: $e');
    }

    try {
      _canRequestAds = await info.canRequestAds();
    } catch (e) {
      debugPrint('UMP canRequestAds error: $e');
      _canRequestAds = false;
    }

    try {
      _privacyOptionsRequired =
          await info.getPrivacyOptionsRequirementStatus() ==
              PrivacyOptionsRequirementStatus.required;
    } catch (e) {
      debugPrint('UMP privacy options status error: $e');
      _privacyOptionsRequired = false;
    }

    _initialized = true;
    return _canRequestAds;
  }

  Future<bool> refresh() async {
    _initialized = false;
    return initialize();
  }

  Future<bool> showPrivacyOptions() async {
    try {
      var dismissed = true;
      await ConsentForm.showPrivacyOptionsForm((error) {
        if (error != null) {
          dismissed = false;
          debugPrint('UMP privacy options: ${error.errorCode} ${error.message}');
        }
      });
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
      if (_canRequestAds) {
        await MobileAds.instance.initialize();
      }
      return dismissed;
    } catch (e) {
      debugPrint('UMP privacy options error: $e');
      return false;
    }
  }
}
