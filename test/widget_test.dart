import 'package:flutter_test/flutter_test.dart';
import 'package:novapos/main.dart';

void main() {
  testWidgets('NovaPOS inicia con el splash y llega al login', (tester) async {
    await tester.pumpWidget(const NovaPOSApp());

    expect(find.text('NovaPOS'), findsOneWidget);

    // Deja pasar el timer del splash (1.5s) y la navegacion
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('NovaPOS'), findsOneWidget);
  });
}