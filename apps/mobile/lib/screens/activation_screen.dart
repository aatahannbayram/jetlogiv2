import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key});

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  final _phone = TextEditingController(text: '0532 000 00 26');
  final _otp = TextEditingController();
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aktivasyon'),
        actions: const [Padding(padding: EdgeInsets.only(right: 16), child: DemoPill())],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const Text('Kayıtlı numaraya SMS gider.', style: TextStyle(fontSize: 16, color: Dg.ink2, height: 1.4)),
          const SizedBox(height: 22),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            enabled: !_sent,
            decoration: InputDecoration(
              labelText: 'Kayıtlı cep',
              filled: true,
              fillColor: Dg.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 16),
          if (!_sent)
            FilledButton(
              onPressed: () async {
                await ref.read(sessionProvider).requestActivationCode(_phone.text);
                if (mounted) setState(() => _sent = true);
              },
              child: const Text('Kod gönder'),
            )
          else ...[
            const Text('Kod sizin telefonunuza gider. Teslim kodu değil.', style: TextStyle(fontSize: 15, color: Dg.ink2)),
            const SizedBox(height: 16),
            OtpPin(controller: _otp, error: _error != null),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!, style: const TextStyle(color: Dg.hi, fontSize: 16)),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final ok = await ref.read(sessionProvider).verifyLoginOtp(_otp.text.trim());
                if (!ok) {
                  setState(() => _error = 'Kod eşleşmedi. Yeniden deneyin.');
                  return;
                }
                ref.read(sessionProvider).completeActivation();
              },
              child: const Text('Cihazı bağla'),
            ),
          ],
        ],
      ),
    );
  }
}
