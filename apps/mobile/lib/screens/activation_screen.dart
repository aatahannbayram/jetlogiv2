import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

/// Canvas'ın "Giriş" ekranı (1a) — ortada büyük logo kartı, alt sabit
/// cam-efekti sheet içinde telefon girişi. Telefon numarasıyla giriş → OTP
/// doğrulama, hepsi tek ekranda (sheet içeriği değişiyor).
class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key});

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  final _phone = TextEditingController(text: '532 •• •• 26');
  final _otp = TextEditingController();
  bool _sent = false;
  bool _remember = true;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration() {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      prefixText: '+90  ',
      prefixStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Dg.purpleActive),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HeroBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Image.asset(
                        'assets/images/jetlogi_logo_color.png',
                        height: 34,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Vardiyana hoş geldin',
                      textAlign: TextAlign.center,
                      style: Dg.serif(
                        size: 28,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'Telefonunla giriş yap, vardiyayı aç ve rotan hazır olsun.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFCBBEEE),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                decoration: BoxDecoration(
                  color: Dg.heroGlass,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(Dg.radiusHero),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_sent) ...[
                      const Text(
                        'Telefon numarası',
                        style: TextStyle(
                          color: Color(0xFFCBBEEE),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white),
                        decoration: _fieldDecoration(),
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: () => setState(() => _remember = !_remember),
                        child: Row(
                          children: [
                            Icon(
                              _remember
                                  ? LucideIcons.checkSquare
                                  : LucideIcons.square,
                              size: 20,
                              color: Dg.purpleActive,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Bu cihazı hatırla',
                              style: TextStyle(
                                color: Color(0xFFCBBEEE),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: Dg.primaryGradient,
                            borderRadius: BorderRadius.circular(Dg.radiusPill),
                          ),
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                            ),
                            onPressed: () async {
                              await ref
                                  .read(sessionProvider)
                                  .requestActivationCode(_phone.text);
                              if (mounted) setState(() => _sent = true);
                            },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Doğrulama kodu gönder'),
                                SizedBox(width: 8),
                                Icon(LucideIcons.arrowRight, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'Alıcıdan 4 haneli kodu isteyin',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Kod sizin telefonunuza gider. Teslim kodu değil.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFFCBBEEE),
                        ),
                      ),
                      const SizedBox(height: 16),
                      OtpPin(controller: _otp, error: _error != null),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Dg.clay,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: Dg.primaryGradient,
                            borderRadius: BorderRadius.circular(Dg.radiusPill),
                          ),
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                            ),
                            onPressed: () async {
                              final ok = await ref
                                  .read(sessionProvider)
                                  .verifyLoginOtp(_otp.text.trim());
                              if (!ok) {
                                setState(
                                  () => _error =
                                      'Kod eşleşmedi. Yeniden deneyin.',
                                );
                                return;
                              }
                              ref.read(sessionProvider).completeActivation();
                            },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Kodu doğrula'),
                                SizedBox(width: 8),
                                Icon(LucideIcons.arrowRight, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Center(
                      child: Text(
                        'Sorun mu var? Şube yöneticine ulaş',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        'v1.0.0 · JetLogi Saha',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
