import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'recipe.dart';

/// Risoluzione fotografica reale per le ricette.
/// Priorità: asset locale già presente -> URL salvato nel JSON -> Wikimedia Commons.
/// Il risultato viene memorizzato in memoria per evitare richieste duplicate durante la sessione.
class RecipePhotoService {
  RecipePhotoService._();
  static final RecipePhotoService instance = RecipePhotoService._();
  final Map<String, String?> _cache = {};
  final Map<String, Future<String?>> _pending = {};
  final Set<String> _usedUrls = <String>{};

  // Solo gli abbinamenti locali verificati manualmente vengono usati.
  // I file storici oltre R008 contengono duplicati o abbinamenti non affidabili,
  // quindi non devono mai essere mostrati come se fossero foto della ricetta.
  static const Map<String, String> _verifiedLocal = {
    'R00001': 'assets/images/R001.jpg', // Spaghetti alla Carbonara
    'R00002': 'assets/images/R002.jpg', // California Roll
    'R00003': 'assets/images/R003.jpg', // Tacos di pollo
    'R00004': 'assets/images/R004.jpg', // Chicken Curry
    'R00005': 'assets/images/R005.jpg', // Insalata greca
    'R00006': 'assets/images/R006.jpg', // Pasta primavera vegana
    'R00007': 'assets/images/R007.jpg', // Pizza senza glutine
    'R00008': 'assets/images/R008.jpg', // Salmone al forno
  };

  String queryFor(Recipe r) {
    final title = r.title.trim();
    final country = r.country.trim();
    final cuisine = r.cuisine.trim();
    return '$title $cuisine $country food dish';
  }

  Future<String?> resolve(Recipe r) {
    final cached = _cache[r.id];
    if (cached != null || _cache.containsKey(r.id)) return Future.value(cached);
    final existing = _pending[r.id];
    if (existing != null) return existing;
    final future = _lookup(r).whenComplete(() => _pending.remove(r.id));
    _pending[r.id] = future;
    return future;
  }

  Future<String?> _lookup(Recipe r) async {
    // 1) Foto locale verificata: mai usare un file solo perché ha un ID simile.
    final local = _verifiedLocal[r.id];
    if (local != null) {
      try {
        await rootBundle.load(local);
        final value = 'asset://$local';
        _cache[r.id] = value;
        return value;
      } catch (_) {}
    }

    // 2) Un imageUrl esplicito nel catalogo ha precedenza, ma solo se non è già
    // stato assegnato a un'altra ricetta nella sessione.
    if (r.imageUrl.trim().isNotEmpty && !_usedUrls.contains(r.imageUrl.trim())) {
      final value = r.imageUrl.trim();
      _usedUrls.add(value);
      _cache[r.id] = value;
      return value;
    }

    // 3) Wikimedia Commons: selezione conservativa. Se non trova una foto
    // abbastanza coerente, restituisce null invece di mostrare una foto sbagliata.
    final candidates = await _searchCommons(r);
    final best = _chooseBest(r, candidates);
    if (best != null) _usedUrls.add(best);
    _cache[r.id] = best;
    return best;
  }

  Future<List<Map<String, dynamic>>> _searchCommons(Recipe r) async {
    try {
      final uri = Uri.https('commons.wikimedia.org', '/w/api.php', {
        'action': 'query',
        'generator': 'search',
        'gsrsearch': queryFor(r),
        'gsrnamespace': '6',
        'gsrlimit': '10',
        'prop': 'imageinfo',
        'iiprop': 'url|mime|size|extmetadata',
        'iiurlwidth': '1200',
        'format': 'json',
        'origin': '*',
      });
      final response = await http.get(uri, headers: const {
        'Accept': 'application/json',
        'User-Agent': 'RicetteDelMondo/6.0 (recipe-photo-service)',
      }).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return const [];
      final data = jsonDecode(response.body);
      final pages = (data['query']?['pages'] as Map?)?.values.toList() ?? const [];
      return pages.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return const [];
    }
  }

  String? _chooseBest(Recipe r, List<Map<String, dynamic>> pages) {
    final titleTokens = _tokens(r.title);
    final cuisineTokens = _tokens(r.cuisine);
    final countryTokens = _tokens(r.country);
    double bestScore = 0;
    String? best;

    for (final raw in pages) {
      final info = raw['imageinfo'];
      if (info is! List || info.isEmpty || info.first is! Map) continue;
      final item = Map<String, dynamic>.from(info.first as Map);
      final mime = '${item['mime'] ?? ''}'.toLowerCase();
      final pageTitle = '${raw['title'] ?? ''}';
      final lowerTitle = pageTitle.toLowerCase();
      if (!mime.startsWith('image/') || mime == 'image/svg+xml' || mime == 'image/gif') continue;
      if (RegExp(r'logo|icon|flag|map|poster|cover|diagram|symbol', caseSensitive: false).hasMatch(lowerTitle)) continue;
      final url = '${item['thumburl'] ?? item['url'] ?? ''}'.trim();
      if (url.isEmpty || _usedUrls.contains(url)) continue;

      final tokens = _tokens(pageTitle);
      final titleHits = titleTokens.where(tokens.contains).length;
      final cuisineHits = cuisineTokens.where(tokens.contains).length;
      final countryHits = countryTokens.where(tokens.contains).length;
      var score = titleHits * 6.0 + cuisineHits * 2.0 + countryHits * 1.5;
      if (tokens.contains('food') || tokens.contains('dish')) score += 0.5;
      if (titleTokens.isNotEmpty && titleHits == 0) score -= 4.0;
      if (score > bestScore) {
        bestScore = score;
        best = url;
      }
    }

    // Soglia volutamente severa: meglio nessuna foto che una foto di un piatto diverso.
    if (bestScore < 6.0) return null;
    return best;
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
              child: Image.asset('assets/logo_rdm.png', fit: BoxFit.contain),
            );
          }
          if (url.startsWith('asset://')) {
            return Image.asset(url.substring('asset://'.length), fit: BoxFit.cover, filterQuality: FilterQuality.high);
          }
          return Image.network(
            url,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : Container(color: const Color(0xFFF2E8D8), alignment: Alignment.center, child: const CircularProgressIndicator(strokeWidth: 2)),
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFFF2E8D8),
              padding: const EdgeInsets.all(18),
              child: Image.asset('assets/logo_rdm.png', fit: BoxFit.contain),
            ),
          );
        },
      ),
    ),
  );
}
