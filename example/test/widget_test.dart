import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wreq_example/main.dart';

void main() {
  testWidgets('wreq example UI renders input, configuration and action controls',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('wreq Example'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
    expect(find.text('Send Request'), findsOneWidget);
    expect(find.byType(DropdownButton<String>), findsWidgets);
  });
}
