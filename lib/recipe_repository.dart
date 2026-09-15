import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'recipe.dart';

class RecipeRepository {
  static List<Recipe>? _cache;
  static List<Recipe>? get cachedRecipes => _cache;
  static Future<List<Recipe>>? _loading;

  Future<List<Recipe>> loadRecipes({void Function(double progress)? onProgress}) {
    final cached = _cache;
    if (cached != null) {
      onProgress?.call(1.0);
      return Future.value(cached);
    }

    final running = _loading;
    if (running != null) {
      return running.then((recipes) {
        onProgress?.call(1.0);
        return recipes;
      });
    }

    final future = _loadRecipes(onProgress);
    _loading = future;
    return future.whenComplete(() => _loading = null);
  }

  Future<List<Recipe>> _loadRecipes(void Function(double progress)? onProgress) async {
    onProgress?.call(0.03);

    // Lettura reale dell'asset: questa fase rappresenta l'apertura del catalogo.
    final raw = await rootBundle.loadString('assets/recipes.json');
    onProgress?.call(0.28);

    // Decodifica reale del JSON. jsonDecode è un'operazione indivisibile, quindi
    // la percentuale viene aggiornata prima e dopo questa fase, senza inventare
    // un tempo di caricamento.
    final data = jsonDecode(raw) as List<dynamic>;
    onProgress?.call(0.38);

    final result = <Recipe>[];
    const chunkSize = 200;
    for (var start = 0; start < data.length; start += chunkSize) {
      final end = (start + chunkSize < data.length) ? start + chunkSize : data.length;
      for (var i = start; i < end; i++) {
        result.add(Recipe.fromJson(data[i] as Map<String, dynamic>));
      }
      onProgress?.call(0.38 + (0.60 * end / data.length));
      // Cede il thread UI tra i blocchi di parsing/mapping.
      await Future<void>.delayed(Duration.zero);
    }

    final recipes = List<Recipe>.unmodifiable(result);
    _cache = recipes;
    onProgress?.call(1.0);
    return recipes;
  }
}
