import 'package:flutter_test/flutter_test.dart';
import 'package:app_auditoria_financiera/main.dart';

void main() {
  testWidgets('Smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AuditoriaFinancieraApp());
  });
}
