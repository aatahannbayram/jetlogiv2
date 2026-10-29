import 'package:flutter/services.dart';

/// Giriş alanına yazılanın türü: telefon mu, e-posta mı.
enum IdentifierKind { empty, phone, email }

final _phoneChars = RegExp(r'^[\d\s+()\-]+$');

/// Harf ya da `@` varsa e-posta; yalnız rakam (ve + ( ) - boşluk) ise telefon.
IdentifierKind identifierKind(String raw) {
  final v = raw.trim();
  if (v.isEmpty) return IdentifierKind.empty;
  if (_phoneChars.hasMatch(v)) return IdentifierKind.phone;
  return IdentifierKind.email;
}

/// Türk cep numarasını 0 ile başlayan 11 haneye indirger: `+90 500…` →
/// `0500…`, `500…` → `0500…`. Eksik yazımda eldeki rakamlar korunur.
String trPhoneDigits(String raw) {
  var d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('90') && d.length >= 12) d = '0${d.substring(2)}';
  if (d.startsWith('5')) d = '0$d';
  return d.length > 11 ? d.substring(0, 11) : d;
}

/// `0500 000 06 11` biçimi (4-3-2-2).
String formatTrPhone(String raw) {
  final d = trPhoneDigits(raw);
  final parts = <String>[];
  var i = 0;
  for (final len in const [4, 3, 2, 2]) {
    if (i >= d.length) break;
    final end = (i + len).clamp(0, d.length);
    parts.add(d.substring(i, end));
    i = end;
  }
  return parts.join(' ');
}

/// Sunucuya giden biçim: telefon boşluksuz 11 hane, e-posta küçük harf.
String normalizeIdentifier(String raw) => switch (identifierKind(raw)) {
  IdentifierKind.phone => trPhoneDigits(raw),
  IdentifierKind.email => raw.trim().toLowerCase(),
  IdentifierKind.empty => '',
};

/// Yazarken telefonu gruplar; e-postaya dokunmaz. [phoneOnly] ise harfleri
/// kabul etmez (SMS alanı).
class SmartIdentifierFormatter extends TextInputFormatter {
  const SmartIdentifierFormatter({this.phoneOnly = false});

  final bool phoneOnly;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    if (identifierKind(text) != IdentifierKind.phone) {
      return phoneOnly ? oldValue : newValue;
    }
    // Silerken boşluğun hemen arkasındaki rakamı da sil, imleç takılmasın.
    final deleting = text.length < oldValue.text.length;
    final formatted = formatTrPhone(text);
    if (deleting && formatted == oldValue.text) {
      final shorter = formatTrPhone(
        trPhoneDigits(text)
            .substring(0, (trPhoneDigits(text).length - 1).clamp(0, 11)),
      );
      return TextEditingValue(
        text: shorter,
        selection: TextSelection.collapsed(offset: shorter.length),
      );
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
