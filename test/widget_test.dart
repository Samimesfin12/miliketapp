import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:esl_learning_flutter/main.dart';

void main() {
  testWidgets('renders splash branding', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: EthSLApp(),
      ),
    );
    expect(find.text('miliketapp'), findsOneWidget);

    // Advance the virtual clock to clear the 10-second timeout Timer from boot()
    await tester.pump(const Duration(seconds: 10));
  });
}
