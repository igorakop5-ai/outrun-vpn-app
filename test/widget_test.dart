import 'package:flutter_test/flutter_test.dart';
import 'package:outrun_vpn/main.dart';

void main() {
  testWidgets('OutrunVPN App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const OutrunVpnApp());
    expect(find.text('OUTRUN'), findsOneWidget);
    expect(find.text('VPN'), findsOneWidget);
  });
}
