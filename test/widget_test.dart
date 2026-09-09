// Smoke test: aplikasi boot ke splash screen dengan brand PADAN.
//
// Catatan: GoogleFonts dimatikan fetching runtime-nya agar tes tidak
// butuh jaringan (pakai fallback font, teks tetap ter-render).

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:padan_app/main.dart';

void main() {
  testWidgets('Splash menampilkan brand PADAN', (WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;

    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('PADAN'), findsOneWidget);
    expect(find.text('Selaraskan Pangan, Cegah Sisa'), findsOneWidget);
  });
}
