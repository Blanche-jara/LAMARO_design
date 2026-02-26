import 'package:flutter_test/flutter_test.dart';
import 'package:lamaro_espresso/main.dart';

void main() {
  testWidgets('App renders RecipeEditorScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const LamaroApp());
    expect(find.text('레시피 편집'), findsOneWidget);
  });
}
