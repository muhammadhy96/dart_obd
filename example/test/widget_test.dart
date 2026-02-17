import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('renders obd test home', (WidgetTester tester) async {
    await tester.pumpWidget(const ObdTestApp());
    expect(find.text('dart_obd classic BT test'), findsOneWidget);
  });
}
