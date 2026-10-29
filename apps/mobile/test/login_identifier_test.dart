import 'package:dijigoo_kurye/login_identifier.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tür: rakam telefon, harf ya da @ e-posta', () {
    expect(identifierKind(''), IdentifierKind.empty);
    expect(identifierKind('0500 000 06 11'), IdentifierKind.phone);
    expect(identifierKind('+90 500'), IdentifierKind.phone);
    expect(identifierKind('demo.ankara@jetdiji.com'), IdentifierKind.email);
    expect(identifierKind('ali'), IdentifierKind.email);
  });

  test('telefon 4-3-2-2 biçimlenir ve sunucuya boşluksuz gider', () {
    expect(formatTrPhone('05000000611'), '0500 000 06 11');
    expect(formatTrPhone('+90 500 000 06 11'), '0500 000 06 11');
    expect(formatTrPhone('5000000611'), '0500 000 06 11');
    expect(formatTrPhone('0500'), '0500');
    expect(normalizeIdentifier('0500 000 06 11'), '05000000611');
    expect(normalizeIdentifier(' Demo@JetDiji.com '), 'demo@jetdiji.com');
  });

  test('yazarken biçimler, e-postaya dokunmaz, SMS alanı harf almaz', () {
    const f = SmartIdentifierFormatter();
    TextEditingValue v(String t) => TextEditingValue(text: t);
    expect(f.formatEditUpdate(v(''), v('0500000')).text, '0500 000');
    expect(f.formatEditUpdate(v(''), v('a@b.co')).text, 'a@b.co');
    const p = SmartIdentifierFormatter(phoneOnly: true);
    expect(p.formatEditUpdate(v('0500'), v('0500a')).text, '0500');
    // Boşluk silinince arkasındaki rakam da gider.
    expect(f.formatEditUpdate(v('0500 000'), v('0500000')).text, '0500 00');
  });
}
