/// India PIN (Postal Index Number) helpers. Six digits, no fabricated codes.
class IndiaPin {
  const IndiaPin._();

  static final _digits = RegExp(r'^\d{6}$');

  static bool isValid(String value) => _digits.hasMatch(value.trim());

  static String? normalize(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 6) return digits;
    return null;
  }
}
