import 'dart:convert';
import 'package:flutter/services.dart';
import 'main.dart';

class RecipeRepository {
  Future<List<Recipe>> loadRecipes() async {
    final raw = await rootBundle.loadString('assets/recipes.json');
    final data = jsonDecode(raw) as List<dynamic>;
    return data.map((x) => Recipe.fromJson(x as Map<String, dynamic>)).toList();
  }
}
