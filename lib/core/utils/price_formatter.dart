import 'package:intl/intl.dart';

String numberFormatter(double price, {int? decimals}) {
  final isNegative = price < 0;
  final absolutePrice = price.abs();

  String formatWithDigits(int fractionDigits) {
    final safeDigits = fractionDigits.clamp(0, 18);
    final formatter = NumberFormat.currency(
      symbol: '',
      decimalDigits: safeDigits,
      customPattern: safeDigits == 0 ? '#,##0' : '#,##0.${'0' * safeDigits}',
    );
    return formatter.format(absolutePrice).trim();
  }

  if (decimals != null) {
    final result = formatWithDigits(decimals);
    return isNegative ? '-$result' : result;
  }

  final raw = absolutePrice.toStringAsFixed(18);
  final parts = raw.split('.');
  final integerPart = parts.first;
  final fractionalRaw = parts.length > 1 ? parts[1] : '';
  final fractionalTrimmed = fractionalRaw.replaceFirst(RegExp(r'0+$'), '');

  int leadingZeroCount = 0;
  for (final ch in fractionalTrimmed.split('')) {
    if (ch == '0') {
      leadingZeroCount++;
      continue;
    }
    break;
  }

  if (leadingZeroCount > 8) {
    final integerOnly = NumberFormat('#,##0').format(int.parse(integerPart));
    return isNegative ? '-$integerOnly' : integerOnly;
  }

  if (leadingZeroCount >= 2) {
    if (fractionalTrimmed.isEmpty || leadingZeroCount >= fractionalTrimmed.length) {
      final integerOnly = NumberFormat('#,##0').format(int.parse(integerPart));
      return isNegative ? '-$integerOnly' : integerOnly;
    }

    var nonZeroCount = 0;
    var endIndex = leadingZeroCount;
    for (var i = leadingZeroCount; i < fractionalTrimmed.length; i++) {
      endIndex = i + 1;
      if (fractionalTrimmed[i] != '0') {
        nonZeroCount++;
      }
      if (nonZeroCount == 4) {
        break;
      }
    }

    final groupedInteger = NumberFormat('#,##0').format(int.parse(integerPart));
    final fractional = fractionalTrimmed.substring(0, endIndex);
    final result = '$groupedInteger.$fractional';
    return isNegative ? '-$result' : result;
  }

  final result = formatWithDigits(4);
  return isNegative ? '-$result' : result;
}
