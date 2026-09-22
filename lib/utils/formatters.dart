import 'package:intl/intl.dart';

/// Formatea un número como moneda sin el símbolo de pesos (ej. 2,420.00 o 2,420)
String formatMoney(num amount, {int decimalDigits = 2}) {
  final format = NumberFormat.simpleCurrency(
    locale: 'en_US',
    decimalDigits: decimalDigits,
    name: '', // Evita que agregue el símbolo de moneda para controlarlo manualmente
  );
  return format.format(amount).trim();
}
