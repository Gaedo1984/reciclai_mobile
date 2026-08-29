import 'package:flutter_test/flutter_test.dart';

import 'package:reciclai_mobile/main.dart';

void main() {
  testWidgets('Muestra el saludo Hola mundo', (WidgetTester tester) async {
    await tester.pumpWidget(const ReciclaiApp());

    expect(find.text('¡Hola mundo!'), findsOneWidget);
  });
}
