import 'package:flutter_test/flutter_test.dart';

import 'package:campus_app/main.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const CampusPortalApp());
    expect(find.text('Campus Portal'), findsOneWidget);
  });
}
