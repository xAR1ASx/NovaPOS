import 'package:flutter_test/flutter_test.dart';
import 'package:mi_fruver_pos/main.dart';

void main() {
  testWidgets('NovaPOS inicia correctamente', (WidgetTester tester) async {
    await tester.pumpWidget(const NovaPOSApp());

    expect(find.text('NovaPOS'), findsOneWidget);
  });
}
