import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Recupera una foto rappresentativa dell'ingrediente senza bloccare la UI.
/// Le richieste sono limitate e vengono mantenute in memoria per la sessione.
class IngredientPhotoService {
  IngredientPhotoService._();
  static final IngredientPhotoService instance = IngredientPhotoService._();

  final Map<String, String?> _cache = <String, String?>{};
  final Map<String, Future<String?>> _pending = <String, Future<String?>>{};
  final List<Future<void>> _queues = List<Future<void>>.filled(3, Future<void>.value());
  int _nextQueue = 0;

  Future<T> _enqueue<T>(Future<T> Function() action) async {
    final slot = _nextQueue++ % _queues.length;
    final previous = _queues[slot];
    final gate = Completer<void>();
    _queues[slot] = previous.then((_) => gate.future);
    await previous;
    try {
      return await action();
    } finally {
      gate.complete();
    }
  }

  Future<String?> resolve(String ingredient) {
    final key = _cleanIngredient(ingredient).toLowerCase();
    if (key.isEmpty) return Future<String?>.value(null);
    if (_cache.containsKey(key)) return Future<String?>.value(_cache[key]);
    final existing = _pending[key];
    if (existing != null) return existing;

    final future = _lookup(key).whenComplete(() => _pending.remove(key));
    _pending[key] = future;
    return future;
  }

  String _cleanIngredient(String raw) {
    var value = raw.trim();
    value = value.replaceFirst(
      RegExp(r'^\s*\d+(?:[\.,]\d+)?\s*(?:g|kg|mg|ml|cl|l|dl|oz|lb|cucchiai?|cucchiaini?|pezzi?|fette?|spicchi?|rametti?)?\s*', caseSensitive: false),
      '',
    );
    value = value.replaceFirst(RegExp(r'^\s*[–-]\s*'), '');
    value = value.replaceAll(RegExp(r'\s*\([^)]*\)'), '');
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return value;
  }

  String _queryTerm(String value) {
    const translations = <String, String>{
      'pomodori': 'tomatoes', 'pomodoro': 'tomato', 'patate': 'potatoes', 'patata': 'potato',
      'cipolla': 'onion', 'cipolle': 'onions', 'aglio': 'garlic', 'carota': 'carrot', 'carote': 'carrots',
      'sedano': 'celery', 'zucchina': 'zucchini', 'zucchine': 'zucchini', 'melanzana': 'eggplant', 'melanzane': 'eggplant',
      'peperone': 'bell pepper', 'peperoni': 'bell peppers', 'peperoncino': 'chili pepper', 'peperoncini': 'chili peppers',
      'limone': 'lemon', 'limoni': 'lemons', 'lime': 'lime', 'zenzero': 'ginger', 'basilico': 'basil',
      'prezzemolo': 'parsley', 'coriandolo': 'cilantro', 'rosmarino': 'rosemary', 'salvia': 'sage', 'timo': 'thyme',
      'menta': 'mint', 'origano': 'oregano', 'olio': 'olive oil', 'burro': 'butter', 'latte': 'milk',
      'panna': 'cream', 'farina': 'flour', 'zucchero': 'sugar', 'sale': 'salt', 'pepe': 'black pepper',
      'riso': 'rice', 'pasta': 'pasta', 'spaghetti': 'spaghetti', 'uova': 'eggs', 'uovo': 'egg',
      'formaggio': 'cheese', 'parmigiano': 'parmesan cheese', 'mozzarella': 'mozzarella', 'pecorino': 'pecorino cheese',
      'pollo': 'chicken', 'manzo': 'beef', 'carne': 'beef meat', 'maiale': 'pork', 'pesce': 'fish',
      'salmone': 'salmon', 'tonno': 'tuna', 'gamberi': 'shrimp', 'gamberetto': 'shrimp', 'ceci': 'chickpeas',
      'fagioli': 'beans', 'lenticchie': 'lentils', 'olive': 'olives', 'mandorle': 'almonds', 'noci': 'walnuts',
      'miele': 'honey', 'aceto': 'vinegar', 'senape': 'mustard', 'soia': 'soy sauce', 'pane': 'bread',
    };
    final lower = value.toLowerCase();
    return translations[lower] ?? value;
  }

  Future<String?> _lookup(String key) async {
    final query = '${_queryTerm(key)} food ingredient';
    return _enqueue(() async {
      try {
        final uri = Uri.https('api.openverse.org', '/v1/images/', {
          'q': query,
          'page_size': '6',
          'mature': 'false',
        });
        final response = await http.get(uri, headers: const {
          'Accept': 'application/json',
          'User-Agent': 'RicetteDelMondo/6.0 (ingredient-photo-service)',
        }).timeout(const Duration(milliseconds: 1500));
        if (response.statusCode != 200) {
          _cache[key] = null;
          return null;
        }
        final data = jsonDecode(response.body);
        final results = data is Map ? data['results'] : null;
        if (results is! List) {
          _cache[key] = null;
          return null;
        }
        for (final item in results.whereType<Map>()) {
          final mime = '${item['mimetype'] ?? item['mime_type'] ?? ''}'.toLowerCase();
          if (mime.isNotEmpty && !mime.startsWith('image/')) continue;
          final license = '${item['license'] ?? item['license_version'] ?? ''}'.toLowerCase();
          if (license.contains('nc') || license.contains('noncommercial')) continue;
          final url = '${item['thumbnail'] ?? item['url'] ?? ''}'.trim();
          if (url.isEmpty) continue;
          _cache[key] = url;
          return url;
        }
      } catch (_) {
        // Il caricamento dell'immagine è opzionale: la riga resta utilizzabile.
      }
      _cache[key] = null;
      return null;
    });
  }
}
