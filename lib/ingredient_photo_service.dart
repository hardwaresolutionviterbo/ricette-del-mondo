import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Cerca una fotografia riutilizzabile per un ingrediente e la memorizza in
/// cache. Le richieste sono serializzate e non partono mai dalle schermate
/// elenco: questo servizio viene usato solo nel dettaglio della ricetta.
class IngredientPhotoService {
  IngredientPhotoService._();
  static final IngredientPhotoService instance = IngredientPhotoService._();

  static const _prefsKey = 'rdm_ingredient_photo_manifest_v1';
  final Map<String, String?> _cache = <String, String?>{};
  final Map<String, Future<String?>> _pending = <String, Future<String?>>{};
  Future<void>? _initFuture;
  Future<void> _queue = Future<void>.value();
  SharedPreferences? _prefs;
  Timer? _persistTimer;

  Future<void> _ensureInit() => _initFuture ??= _loadPersisted();

  Future<void> _loadPersisted() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs?.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      for (final entry in decoded.entries) {
        final value = entry.value?.toString();
        if (value != null && value.isNotEmpty) {
          _cache[entry.key.toString()] = value;
        }
      }
    } catch (_) {
      // Una cache corrotta non deve mai impedire l'apertura di una ricetta.
    }
  }

  String normalize(String value) {
    var text = value.trim().toLowerCase();
    text = text.replaceAll(RegExp(r'^\d+(?:[\.,]\d+)?\s*'), '');
    text = text.replaceAll(RegExp(r'^\d+\s*/\s*\d+\s*'), '');
    text = text.replaceAll(RegExp(r'\s+q\.b\.?$'), '');
    text = text.replaceAll(RegExp(r'\s+\(.*?\)$'), '');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  String displayName(String value) {
    var text = value.trim();
    text = text.replaceFirst(
      RegExp(r'^\s*\d+(?:[\.,]\d+)?\s*(?:g|kg|mg|ml|cl|l|dl|cucchiaini?|cucchiai?|pz|pezzi)?\s+', caseSensitive: false),
      '',
    );
    text = text.replaceFirst(RegExp(r'^\s*\d+\s*/\s*\d+\s+'), '');
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<String?> resolve(String ingredient) async {
    final key = normalize(ingredient);
    if (key.isEmpty) return null;
    if (_cache.containsKey(key)) return _cache[key];

    final pending = _pending[key];
    if (pending != null) return pending;

    final future = _lookup(key).whenComplete(() => _pending.remove(key));
    _pending[key] = future;
    return future;
  }

  Future<T> _runQueued<T>(Future<T> Function() action) async {
    final previous = _queue;
    final gate = Completer<void>();
    _queue = gate.future;
    await previous;
    try {
      return await action();
    } finally {
      gate.complete();
    }
  }

  Future<String?> _lookup(String key) async {
    await _ensureInit();
    final persisted = _cache[key];
    if (persisted != null && persisted.isNotEmpty) return persisted;

    return _runQueued(() async {
      final uri = Uri.https('api.openverse.org', '/v1/images/', {
        'q': '$key ingredient food',
        'page_size': '6',
        'mature': 'false',
      });
      try {
        final response = await http.get(uri, headers: const {
          'Accept': 'application/json',
          'User-Agent': 'RicetteDelMondo/6.0 (ingredient-photo-service)',
        }).timeout(const Duration(seconds: 2));
        if (response.statusCode != 200) {
          _cache[key] = null;
          return null;
        }

        final decoded = jsonDecode(response.body);
        final results = decoded is Map ? decoded['results'] : null;
        if (results is! List) {
          _cache[key] = null;
          return null;
        }

        final target = _tokens(key);
        String? bestUrl;
        double bestScore = double.negativeInfinity;

        for (final raw in results.whereType<Map>()) {
          final item = Map<String, dynamic>.from(raw);
          final license = '${item['license'] ?? ''}'.toLowerCase();
          if (!_licenseAllowed(license)) continue;
          final url = '${item['thumbnail'] ?? item['url'] ?? ''}'.trim();
          if (url.isEmpty) continue;
          final title = '${item['title'] ?? item['name'] ?? ''}';
          final description = '${item['description'] ?? ''}';
          final tags = item['tags'];
          final tagText = tags is List
              ? tags.map((tag) => '${tag is Map ? tag['name'] ?? '' : tag}').join(' ')
              : '';
          final tokens = _tokens('$title $description $tagText');
          final hits = target.where(tokens.contains).length;
          var score = hits * 8.0;
          if (title.toLowerCase().contains(key)) score += 10;
          if (RegExp(r'logo|icon|map|poster|diagram|symbol', caseSensitive: false).hasMatch(title)) {
            score -= 20;
          }
          if (score > bestScore) {
            bestScore = score;
            bestUrl = url;
          }
        }

        if (bestScore < 5 || bestUrl == null) {
          _cache[key] = null;
          _schedulePersist();
          return null;
        }
        _cache[key] = bestUrl;
        _schedulePersist();
        return bestUrl;
      } catch (_) {
        _cache[key] = null;
        _schedulePersist();
        return null;
      }
    });
  }

  bool _licenseAllowed(String license) {
    if (license.isEmpty) return false;
    if (license.contains('nc') || license.contains('noncommercial') || license.contains('non-commercial')) return false;
    return license.contains('cc0') ||
        license.contains('public domain') ||
        license == 'pdm' ||
        license.contains('cc by') ||
        license.contains('cc-by') ||
        license.contains('cc by-sa') ||
        license.contains('cc-by-sa');
  }

  Set<String> _tokens(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-zàèéìòù0-9]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((token) => token.length >= 3)
      .toSet();

  void _schedulePersist() {
    _persistTimer ??= Timer(const Duration(seconds: 2), () async {
      _persistTimer = null;
      final prefs = _prefs;
      if (prefs == null) return;
      final values = <String, String>{
        for (final entry in _cache.entries)
          if (entry.value != null && entry.value!.isNotEmpty) entry.key: entry.value!,
      };
      try {
        await prefs.setString(_prefsKey, jsonEncode(values));
      } catch (_) {
        // La persistenza è solo un'ottimizzazione.
      }
    });
  }
}
