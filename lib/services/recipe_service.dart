import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/espresso_recipe.dart';

/// 레시피 CRUD 서비스
///
/// SharedPreferences에 JSON으로 로컬 저장.
/// ChangeNotifier 패턴 (Provider).
class RecipeService extends ChangeNotifier {
  static const String _storageKey = 'espresso_recipes';

  List<EspressoRecipe> _recipes = [];
  List<EspressoRecipe> get recipes => List.unmodifiable(_recipes);

  RecipeService() {
    _loadRecipes();
  }

  /// 저장된 레시피 목록 불러오기
  Future<void> _loadRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString != null) {
      final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
      _recipes = jsonList
          .map((e) => EspressoRecipe.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    }
  }

  /// 전체 레시피 목록 저장
  Future<void> _saveRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_recipes.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }

  /// 새 레시피 추가
  Future<void> addRecipe(EspressoRecipe recipe) async {
    _recipes.add(recipe);
    await _saveRecipes();
    notifyListeners();
  }

  /// 레시피 업데이트
  Future<void> updateRecipe(EspressoRecipe recipe) async {
    final index = _recipes.indexWhere((r) => r.id == recipe.id);
    if (index != -1) {
      _recipes[index] = recipe;
      await _saveRecipes();
      notifyListeners();
    }
  }

  /// 레시피 삭제
  Future<void> deleteRecipe(String id) async {
    _recipes.removeWhere((r) => r.id == id);
    await _saveRecipes();
    notifyListeners();
  }

  /// ID로 레시피 조회
  EspressoRecipe? getRecipeById(String id) {
    try {
      return _recipes.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 새 고유 ID 생성
  String generateId() =>
      DateTime.now().millisecondsSinceEpoch.toString();
}
