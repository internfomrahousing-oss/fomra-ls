import 'package:flutter_test/flutter_test.dart';
import 'package:fomra_ls/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FomraLSApp());
    expect(find.text('FomraLS'), findsOneWidget);
  });
}
