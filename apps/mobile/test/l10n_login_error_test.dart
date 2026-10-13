import 'package:dijigoo_kurye/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('giriş hatası kalan hakkı ve kilit saatini söyler', () {
    const l = L10n('tr');
    expect(
      l.loginError('INVALID_CREDENTIALS', remainingAttempts: 3, fallback: 'x'),
      contains('3 deneme hakkın kaldı'),
    );
    final until = DateTime(2026, 10, 13, 9, 5);
    expect(
      l.loginError(
        'ACCOUNT_TEMPORARILY_LOCKED',
        lockedUntil: until,
        fallback: 'x',
      ),
      contains('09:05'),
    );
    expect(l.loginError('LOGIN_FAILED', fallback: 'x'), 'x');
    // Kayıtsız e-postada ek alan gelmez.
    expect(l.loginError('INVALID_CREDENTIALS', fallback: 'x'), 'x');
  });
}
