import 'package:flutter_test/flutter_test.dart';
import 'package:app_auditoria_financiera/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FamFinanceApp(initialLoggedIn: false));
  });
}

