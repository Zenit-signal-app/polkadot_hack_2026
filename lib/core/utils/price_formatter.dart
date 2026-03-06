import 'package:intl/intl.dart';

/// Formats a crypto price following "significant digits" rules:
///
/// | Range                   | Display                              | Example            |
/// |-------------------------|--------------------------------------|--------------------|
/// | price ≥ 1               | 2 decimal places                     | 69,285.42          |
/// | 0.0001 ≤ price < 1      | 4 significant decimal digits         | 0.003412           |
/// | price < 0.0001          | 4 sig-digits, compact if zeros > 4   | 0.0{7}1234         |
///
/// Pass [decimals] to pin a fixed digit count (overrides auto logic).
/// Handles scientific-notation inputs such as 1.2e-7 automatically.
String numberFormatter(double price, {int? decimals}) {
  final isNegative = price < 0;
  final abs = price.abs();

  String sign(String s) => isNegative ? '-$s' : s;

  // ── Fixed override ────────────────────────────────────────────────────────
  if (decimals != null) {
    final d = decimals.clamp(0, 18);
    return sign(d == 0
        ? NumberFormat('#,##0').format(abs)
        : NumberFormat('#,##0.${'0' * d}').format(abs).trim());
  }

  // ── price ≥ 1  →  2 decimals, trim trailing ".00" to integer ─────────────
  if (abs >= 1) {
    final formatted = NumberFormat('#,##0.##').format(abs).trim();
    return sign(formatted);
  }

  // ── 0.0001 ≤ price < 1  →  4 significant fractional digits ───────────────
  if (abs >= 0.0001) {
    // toStringAsFixed avoids scientific notation; 10 digits is enough here.
    final raw = abs.toStringAsFixed(10);
    final frac = raw.split('.').last;

    // Find first non-zero position so we keep 4 meaningful digits.
    int firstNonZero = 0;
    for (var i = 0; i < frac.length; i++) {
      if (frac[i] != '0') {
        firstNonZero = i;
        break;
      }
    }
    final keepDigits = (firstNonZero + 4).clamp(4, 10);
    final formatted = NumberFormat('0.${'0' * keepDigits}').format(abs).trim();
    // Trim trailing zeros but keep at least 2 decimal places.
    final trimmed = _trimTrailingZeros(formatted, minDecimals: 2);
    return sign(trimmed);
  }

  // ── Micro-price (price < 0.0001) ─────────────────────────────────────────
  // toStringAsFixed(20) prevents scientific notation for tiny values.
  final raw = abs.toStringAsFixed(20);
  final fracFull = raw.contains('.') ? raw.split('.').last : '';

  // Count leading zeros after the decimal point.
  int leadingZeros = 0;
  for (final ch in fracFull.split('')) {
    if (ch == '0') {
      leadingZeros++;
    } else {
      break;
    }
  }

  // Grab the significant (non-zero) portion and take up to 4 sig-digits.
  final sigStart = leadingZeros;
  final sigRaw = fracFull.length > sigStart
      ? fracFull.substring(sigStart).replaceFirst(RegExp(r'0+$'), '')
      : '';
  final sigPart = sigRaw.length > 4 ? sigRaw.substring(0, 4) : sigRaw;

  if (sigPart.isEmpty) return sign('0');

  // Compact notation for very small values — 0.0{n}xxxx
  if (leadingZeros > 4) {
    return sign('0.0{$leadingZeros}$sigPart');
  }

  // Write out the leading zeros explicitly.
  return sign('0.${'0' * leadingZeros}$sigPart');
}

/// Removes trailing decimal zeros, preserving a minimum of [minDecimals].
String _trimTrailingZeros(String value, {int minDecimals = 0}) {
  if (!value.contains('.')) return value;
  final parts = value.split('.');
  String frac = parts[1].replaceFirst(RegExp(r'0+$'), '');
  if (frac.length < minDecimals) {
    frac = frac.padRight(minDecimals, '0');
  }
  return frac.isEmpty ? parts[0] : '${parts[0]}.$frac';
}

