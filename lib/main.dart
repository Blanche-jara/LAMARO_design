import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/recipe_service.dart';
import 'screens/recipe_editor_screen.dart';

void main() {
  runApp(const LamaroApp());
}

class LamaroApp extends StatelessWidget {
  const LamaroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RecipeService(),
      child: MaterialApp(
        title: 'LAMARO Espresso',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7C5CFC)),
          useMaterial3: true,
        ),
        home: const RecipeEditorScreen(),
      ),
    );
  }
}
