import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'recipe.dart';

/// Gestisce una foto reale e specifica per ogni ricetta.
///
/// Ordine di risoluzione:
/// 1. asset locali già verificati;
/// 2. imageUrl esplicito nel catalogo;
/// 3. URL memorizzato sul dispositivo per quella ricetta;
/// 4. ricerca mirata su Openverse (licenze riutilizzabili).
/// 5. ricerca mirata su Wikimedia Commons.
/// 6. logo ufficiale dell'app come fallback sicuro.
///
/// Le assegnazioni vengono persistite per evitare che una ricetta cambi foto
/// a ogni apertura e per evitare di riutilizzare la stessa immagine tra ricette.
class RecipePhotoService {
  RecipePhotoService._();
  static final RecipePhotoService instance = RecipePhotoService._();

  static const _prefsKey = 'rdm_recipe_photo_manifest_v6';
  final Map<String, String?> _cache = <String, String?>{};
  final Map<String, Future<String?>> _pending = <String, Future<String?>>{};
  final Set<String> _usedUrls = <String>{};
  SharedPreferences? _prefs;
  Future<void>? _initFuture;
  Timer? _persistTimer;
  Future<void> _networkQueue = Future<void>.value();

  static const Map<String, String> _verifiedLocal = {
    'R00001': 'assets/images/R001.jpg',
    'R00002': 'assets/images/R002.jpg',
    'R00003': 'assets/images/R003.jpg',
    'R00004': 'assets/images/R004.jpg',
    'R00005': 'assets/images/R005.jpg',
    'R00006': 'assets/images/R006.jpg',
    'R00007': 'assets/images/R007.jpg',
    'R00008': 'assets/images/R008.jpg',
  };

  Future<void> _ensureInit() {
    return _initFuture ??= _loadPersisted();
  }

  Future<void> _loadPersisted() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      for (final entry in map.entries) {
        final value = entry.value?.toString();
        if (value != null && value.isNotEmpty) {
          _cache[entry.key] = value;
          if (!value.startsWith('asset://')) _usedUrls.add(value);
        }
      }
    } catch (_) {
      // Un manifest corrotto non deve impedire il caricamento delle ricette.
    }
  }

  void _persist(String id, String? value) {
    _cache[id] = value;
    if (value != null && !value.startsWith('asset://')) _usedUrls.add(value);
    _persistTimer ??= Timer(const Duration(seconds: 2), () async {
      _persistTimer = null;
      final prefs = _prefs;
      if (prefs == null) return;
      final serializable = <String, String>{
        for (final e in _cache.entries)
          if (e.value != null && e.value!.isNotEmpty) e.key: e.value!,
      };
      try {
        await prefs.setString(_prefsKey, jsonEncode(serializable));
      } catch (_) {
        // La cache immagini non deve mai bloccare l'interfaccia.
      }
    });
  }

  Future<T> _runNetworkLookup<T>(Future<T> Function() action) async {
    final previous = _networkQueue;
    final gate = Completer<void>();
    _networkQueue = gate.future;
    await previous;
    try {
      return await action();
    } finally {
      gate.complete();
    }
  }

  String queryFor(Recipe r) {
    final base = _cleanTitle(r.title);
    final country = r.country.trim();
    final cuisine = r.cuisine.trim();
    return '$base $cuisine $country food';
  }

  String _cleanTitle(String title) {
    var value = title.trim();
    // Le 10.000 schede contengono varianti con suffissi editoriali.
    // Per la foto cerchiamo il piatto reale, non il numero della variante.
    value = value.split(RegExp(r'\s+[—–-]\s+')).first.trim();
    value = value.replaceAll(RegExp(r'\s+\d+$'), '').trim();
    value = value.replaceAll(RegExp(r'\s+\([^)]*\)$'), '').trim();
    return value;
  }

  Future<String?> resolve(Recipe r) async {
    await _ensureInit();
    if (_cache.containsKey(r.id)) return _cache[r.id];
    final existing = _pending[r.id];
    if (existing != null) return existing;
    final future = _lookup(r).whenComplete(() => _pending.remove(r.id));
    _pending[r.id] = future;
    return future;
  }

  Future<String?> _lookup(Recipe r) async {
    String? local = _verifiedLocal[r.id];
    // Nel progetto sono presenti 120 foto locali validate (R001-R120).
    // Usarle direttamente elimina 120 ricerche di rete e rende le prime
    // schermate molto più rapide e affidabili anche senza connessione.
    if (local == null && r.id.startsWith('R')) {
      final number = int.tryParse(r.id.substring(1));
      if (number != null && number >= 1 && number <= 120) {
        local = 'assets/images/R${number.toString().padLeft(3, '0')}.jpg';
      }
    }
    if (local != null) {
      final value = 'asset://$local';
      _persist(r.id, value);
      return value;
    }

    final explicit = r.imageUrl.trim();
    if (explicit.isNotEmpty && !_usedUrls.contains(explicit)) {
      _persist(r.id, explicit);
      return explicit;
    }

    return _runNetworkLookup(() async {
      // Una sola ricerca per volta evita che una schermata con molte card
      // apra decine di richieste HTTP contemporaneamente.
      final openverse = await _searchOpenverse(r);
      final bestOpenverse = _chooseBest(r, openverse);
      if (bestOpenverse != null) {
        _persist(r.id, bestOpenverse);
        return bestOpenverse;
      }

      final candidates = await _searchCommons(r);
      final bestCommons = _chooseBest(r, candidates);
      if (bestCommons != null) {
        _persist(r.id, bestCommons);
        return bestCommons;
      }

      const fallback = 'asset://assets/logo_rdm.png';
      _persist(r.id, fallback);
      return fallback;
    });

  }

  Future<List<Map<String, dynamic>>> _searchOpenverse(Recipe r) async {
    final queries = <String>[
      '${_cleanTitle(r.title)} ${r.country}',
    ];
    final all = <Map<String, dynamic>>[];
    final seen = <String>{};
    // Solo licenze adatte a un'app commerciale: CC0, pubblico dominio,
    // CC BY e CC BY-SA. Le licenze NC vengono escluse.
    // Una sola richiesta: filtriamo poi le licenze localmente. Evitiamo
    // quattro richieste consecutive per ogni card e code di rete troppo lunghe.
    for (final q in queries) {
      try {
        final uri = Uri.https('api.openverse.org', '/v1/images/', {
          'q': q,
          'page_size': '8',
          'mature': 'false',
        });
        final response = await http.get(uri, headers: const {
          'Accept': 'application/json',
          'User-Agent': 'RicetteDelMondo/6.0 (recipe-photo-service)',
        }).timeout(const Duration(seconds: 2));
        if (response.statusCode != 200) continue;
        final data = jsonDecode(response.body);
        final results = data['results'];
        if (results is! List) continue;
        for (final item in results.whereType<Map>()) {
          final copy = Map<String, dynamic>.from(item);
          final id = '${copy['id'] ?? copy['identifier'] ?? copy['url'] ?? ''}';
          if (id.isNotEmpty && seen.add(id)) all.add(copy);
        }
      } catch (_) {
        // Se Openverse non risponde, passa direttamente a Commons.
      }
      if (all.length >= 16) break;
    }
    return all;
  }

  Future<List<Map<String, dynamic>>> _searchCommons(Recipe r) async {
    final queries = <String>[
      '"${_cleanTitle(r.title)}" ${r.country}',
    ];
    final all = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final q in queries) {
      try {
        final uri = Uri.https('commons.wikimedia.org', '/w/api.php', {
          'action': 'query',
          'generator': 'search',
          'gsrsearch': q,
          'gsrnamespace': '6',
          'gsrlimit': '8',
          'prop': 'imageinfo',
          'iiprop': 'url|mime|size|extmetadata',
          'iiurlwidth': '1200',
          'format': 'json',
          'origin': '*',
        });
        final response = await http.get(uri, headers: const {
          'Accept': 'application/json',
          'User-Agent': 'RicetteDelMondo/6.0 (recipe-photo-service)',
        }).timeout(const Duration(seconds: 2));
        if (response.statusCode != 200) continue;
        final data = jsonDecode(response.body);
        final pages = (data['query']?['pages'] as Map?)?.values.toList() ?? const [];
        for (final page in pages.whereType<Map>()) {
          final copy = Map<String, dynamic>.from(page);
          final title = '${copy['title'] ?? ''}';
          if (seen.add(title.toLowerCase())) all.add(copy);
        }
        if (all.length >= 12) break;
      } catch (_) {
        // Prova la query successiva senza bloccare la UI.
      }
    }
    return all;
  }

  String? _chooseBest(Recipe r, List<Map<String, dynamic>> pages) {
    final titleTokens = _tokens(_cleanTitle(r.title));
    final cuisineTokens = _tokens(r.cuisine);
    final countryTokens = _tokens(r.country);
    double bestScore = double.negativeInfinity;
    String? best;

    for (final raw in pages) {
      final info = raw['imageinfo'];
      final item = info is List && info.isNotEmpty && info.first is Map
          ? Map<String, dynamic>.from(info.first as Map)
          : raw;
      final mime = '${item['mime'] ?? raw['filetype'] ?? ''}'.toLowerCase();
      final pageTitle = '${raw['title'] ?? raw['originalTitle'] ?? raw['foreign_landing_url'] ?? ''}';
      final meta = item['extmetadata'];
      final commonsLicense = meta is Map
          ? '${meta['LicenseShortName']?['value'] ?? meta['License']?['value'] ?? ''}'.toLowerCase()
          : '';
      final license = '${raw['license'] ?? item['license'] ?? commonsLicense}'.toLowerCase().replaceAll('_', '-');
      // Openverse aggrega metadata di terze parti e raccomanda di verificare
      // la licenza del singolo elemento. Accettiamo solo licenze note e
      // compatibili con l'uso commerciale; gli elementi senza licenza
      // riconoscibile vengono scartati invece di essere usati alla cieca.
      if (!_commercialLicenseAllowed(license)) continue;
      final lowerTitle = pageTitle.toLowerCase();
      if (mime.isNotEmpty && (!mime.startsWith('image/') || mime == 'image/svg+xml' || mime == 'image/gif')) continue;
      if (RegExp(r'logo|icon|flag|map|poster|cover|diagram|symbol|coat of arms', caseSensitive: false).hasMatch(lowerTitle)) continue;
      final url = '${item['thumbnail'] ?? item['thumburl'] ?? item['url'] ?? ''}'.trim();
      if (url.isEmpty || _usedUrls.contains(url)) continue;

      final description = meta is Map ? '${meta['ImageDescription']?['value'] ?? ''}' : '${raw['description'] ?? ''}';
      final tags = raw['tags'];
      final tagText = tags is List ? tags.map((e) => '${e is Map ? e['name'] ?? '' : e}').join(' ') : '';
      final haystack = '$pageTitle $description $tagText';
      final tokens = _tokens(haystack);
      final titleHits = titleTokens.where(tokens.contains).length;
      final cuisineHits = cuisineTokens.where(tokens.contains).length;
      final countryHits = countryTokens.where(tokens.contains).length;
      var score = titleHits * 8.0 + cuisineHits * 2.0 + countryHits * 1.5;
      if (tokens.contains('food') || tokens.contains('dish') || tokens.contains('recipe')) score += 0.5;
      if (titleTokens.isNotEmpty && titleHits == 0) score -= 7.0;
      if (lowerTitle.contains(_cleanTitle(r.title).toLowerCase())) score += 10.0;
      if (score > bestScore) {
        bestScore = score;
        best = url;
      }
    }

    // Se la ricerca era sul titolo esatto, una corrispondenza forte di Commons
    // è preferibile al logo generico. Mai assegnare un URL già usato.
    if (bestScore < 6.0) return null;
    return best;
  }

  bool _commercialLicenseAllowed(String license) {
    final v = license.trim().toLowerCase();
    if (v.isEmpty) return false;
    if (v.contains('noncommercial') || v.contains('non-commercial') || v.contains('cc by-nc') || v.contains('cc-by-nc')) return false;
    if (v == 'cc0' || v.contains('cc0 1.0') || v.contains('public domain') || v == 'pdm') return true;
    if (v.contains('cc by-sa') || v.contains('cc-by-sa') || v == 'by-sa') return true;
    if (v.contains('cc by') || v.contains('cc-by') || v == 'by') return true;
    return false;
  }

  Set<String> _tokens(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-zàèéìòù0-9]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((x) => x.length >= 3)
      .toSet();
}

class RecipePhoto extends StatefulWidget {
  final Recipe recipe;
  final double height;
  final BorderRadius radius;
  const RecipePhoto({super.key, required this.recipe, required this.height, required this.radius});
  @override State<RecipePhoto> createState() => _RecipePhotoState();
}

class _RecipePhotoState extends State<RecipePhoto> {
  late Future<String?> _future;
  @override void initState() { super.initState(); _future = RecipePhotoService.instance.resolve(widget.recipe); }
  @override void didUpdateWidget(covariant RecipePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recipe.id != widget.recipe.id) {
      _future = RecipePhotoService.instance.resolve(widget.recipe);
    }
  }

  @override Widget build(BuildContext context) => ClipRRect(
    borderRadius: widget.radius,
    child: SizedBox(
      height: widget.height,
      width: double.infinity,
      child: FutureBuilder<String?>(
        future: _future,
        builder: (context, snapshot) {
          final url = snapshot.data;
          if (url == null || url.isEmpty) {
            return Container(
              color: const Color(0xFFF2E8D8),
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/logo_rdm.png', height: 54, fit: BoxFit.contain),
                  const SizedBox(height: 6),
                  const Text('Ricette del Mondo', style: TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            );
          }
          if (url.startsWith('asset://')) {
            return Image.asset(url.substring('asset://'.length), fit: BoxFit.cover, filterQuality: FilterQuality.low, cacheWidth: (widget.height * MediaQuery.devicePixelRatioOf(context) * 1.5).round());
          }
          return Image.network(
            url,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.low,
              cacheWidth: (widget.height * MediaQuery.devicePixelRatioOf(context) * 1.5).round(),
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : Container(color: const Color(0xFFF2E8D8), alignment: Alignment.center, child: const CircularProgressIndicator(strokeWidth: 2)),
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFFF2E8D8),
              alignment: Alignment.center,
              child: Image.asset('assets/logo_rdm.png', height: 54, fit: BoxFit.contain),
            ),
          );
        },
      ),
    ),
  );
}
