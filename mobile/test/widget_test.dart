import 'package:flutter_test/flutter_test.dart';
import 'package:lucky_sign/main.dart';

void main() {
  testWidgets('app loads', (tester) async {
    await tester.pumpWidget(const LuckySignApp());
    expect(find.textContaining('幸运签'), findsWidgets);
  });
}
