import 'package:flutter_test/flutter_test.dart';

import 'package:sub_track/main.dart';

void main() {
  testWidgets('SubTrack scaffold renders', (WidgetTester tester) async {
    await tester.pumpWidget(const SubTrackApp());

    expect(find.text('SubTrack'), findsOneWidget);
  });
}
