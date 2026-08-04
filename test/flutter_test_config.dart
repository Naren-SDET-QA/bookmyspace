import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Disables google_fonts network fetches in `flutter test` (offline / CI).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
