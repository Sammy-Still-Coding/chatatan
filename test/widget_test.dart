import 'package:flutter_test/flutter_test.dart';
import 'package:chatatan/main.dart';

void main() {
  testWidgets('Aplikasi dapat terbuka tanpa crash', (WidgetTester tester) async {
    // Memastikan AplikasiTes dan LoginPage dapat dimuat dengan aman
    await tester.pumpWidget(const AplikasiTes());
  });
}