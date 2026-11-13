import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/branch_models.dart';
import '../branch_workspace.dart';
import '../l10n.dart';
import '../launchers.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'sube_widgets.dart';

/// Kurye, araç/plaka ve son cihaz. Null araç veya cihaz satırı çizilmez.
class SubeCourierDetailScreen extends ConsumerStatefulWidget {
  const SubeCourierDetailScreen({
    super.key,
    required this.courierId,
    required this.fallbackName,
  });

  final String courierId;
  final String fallbackName;

  @override
  ConsumerState<SubeCourierDetailScreen> createState() =>
      _SubeCourierDetailScreenState();
}

class _SubeCourierDetailScreenState
    extends ConsumerState<SubeCourierDetailScreen> {
  AgencyCourierDetail? _detail;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final branch = ref.read(sessionProvider).branch;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final AgencyCourierDetail detail;
      if (branch.demo) {
        detail = AgencyCourierDetail(
          courierId: widget.courierId,
          fullName: widget.fallbackName,
          plate: '34 DEMO 01',
          vehicleType: 'MOTORCYCLE',
          vehicle: const CourierVehicle(
            plate: '34 DEMO 01',
            vehicleTypeCode: 'MOTORCYCLE',
            brand: 'Honda',
            model: 'PCX',
          ),
        );
      } else {
        final api = branch.api;
        if (api == null) return;
        detail = await api.fetchCourierDetail(widget.courierId);
      }
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = BranchWorkspace.describeError(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final detail = _detail;
    final vehicle = detail?.vehicle;
    final device = detail?.device;
    final plate = detail?.plate ?? vehicle?.plate;
    final type = detail?.vehicleType ?? vehicle?.vehicleTypeCode;
    return Scaffold(
      appBar: AppBar(title: Text(detail?.fullName ?? widget.fallbackName)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Text(_error!, style: Dg.ui(size: 14, color: Dg.hi))
            else if (detail != null) ...[
              if (detail.phone != null)
                SubeNavTile(
                  icon: LucideIcons.phone,
                  label: l.call,
                  subtitle: detail.phone,
                  onTap: () => dialNumber(context, detail.phone),
                ),
              if (plate != null && plate.isNotEmpty) ...[
                SubeSection(l.courierVehicle),
                DgCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l.courierPlate} · $plate',
                        style: Dg.ui(size: 15, weight: FontWeight.w600),
                      ),
                      if (type != null && type.isNotEmpty)
                        Text(
                          l.vehicleTypeName(type),
                          style: Dg.ui(size: 13, color: Dg.ink2),
                        ),
                      if (vehicle != null)
                        Text(
                          [
                            vehicle.brand,
                            if (vehicle.model != null) vehicle.model!,
                            if (vehicle.modelYear != null)
                              '${vehicle.modelYear}',
                          ].where((s) => s.isNotEmpty).join(' · '),
                          style: Dg.ui(size: 13, color: Dg.ink3),
                        ),
                    ],
                  ),
                ),
              ],
              if (device != null) ...[
                SubeSection(l.courierDevice),
                DgCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (device.model != null)
                        Text(
                          device.model!,
                          style: Dg.ui(size: 15, weight: FontWeight.w600),
                        ),
                      if (device.os != null)
                        Text(
                          '${l.courierOs} · ${device.os}',
                          style: Dg.ui(size: 13, color: Dg.ink2),
                        ),
                      if (device.appVersion != null)
                        Text(
                          '${l.courierAppVersion} · ${device.appVersion}',
                          style: Dg.ui(size: 13, color: Dg.ink2),
                        ),
                      if (device.platform.isNotEmpty)
                        Text(
                          device.platform,
                          style: Dg.ui(size: 12, color: Dg.ink3),
                        ),
                      if (device.lastSeenAt != null)
                        Text(
                          l.lastSeenAt(subeDayTime(device.lastSeenAt!)),
                          style: Dg.ui(size: 12, color: Dg.ink3),
                        ),
                      if (device.permissions != null) ...[
                        const SizedBox(height: 8),
                        _Perm(l.permLocation, device.permissions!.location),
                        _Perm(
                          l.permBackground,
                          device.permissions!.backgroundLocation,
                        ),
                        _Perm(l.permCamera, device.permissions!.camera),
                        _Perm(l.permPush, device.permissions!.notifications),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Perm extends StatelessWidget {
  const _Perm(this.label, this.value);

  final String label;
  final bool? value;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = switch (value) {
      true => l.permOn,
      false => l.permOff,
      null => l.permUnknown,
    };
    return Text('$label · $text', style: Dg.ui(size: 13, color: Dg.ink2));
  }
}
