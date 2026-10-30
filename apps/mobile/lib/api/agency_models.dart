/// DTOs for dijigoo-ops's `portal/v1/agency-auth` + `portal/v1/agency`
/// surface — see docs/08-sube-acente-entegrasyonu.md. Field names mirror the
/// actual JSON shapes read from `src/infrastructure/auth/agency-portal-auth.ts`
/// and `src/app/api/portal/v1/agency-auth/*`/`agency/overview` in the
/// dijigoo-ops repo, not our own `apps/api` shapes.
library;

import 'branch_models.dart';

class AgencyDto {
  const AgencyDto({
    required this.id,
    required this.name,
    this.tenantId,
    this.code,
    this.statusCode,
    this.supportPhone,
  });

  final String id;
  final String name;
  final String? tenantId;
  final String? code;
  final String? statusCode;

  /// Önerilen alan (docs/15 §12); Swagger 1.2.0'da yok.
  final String? supportPhone;

  factory AgencyDto.fromJson(Map<String, dynamic> json) => AgencyDto(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    tenantId: json['tenantId'] as String?,
    code: json['code'] as String?,
    statusCode: json['statusCode'] as String?,
    supportPhone: json['supportPhone'] as String?,
  );
}

class AgencyRoleDto {
  const AgencyRoleDto({required this.code, this.nameTr, this.nameEn});

  final String code;
  final String? nameTr;
  final String? nameEn;

  factory AgencyRoleDto.fromJson(Map<String, dynamic> json) =>
      AgencyRoleDto(
        code: json['code'] as String? ?? '',
        nameTr: json['nameTr'] as String?,
        nameEn: json['nameEn'] as String?,
      );
}

/// One shape for both `login`'s (smaller) and `session`'s (fuller) user
/// object — `login` omits `fullName`/`roles`, so both are derived/defaulted.
class AgencyPortalUserDto {
  const AgencyPortalUserDto({
    required this.id,
    required this.email,
    required this.fullName,
    required this.agency,
    this.mustChangePassword = false,
    this.roles = const [],
    this.capabilities = const BranchCapabilities(),
  });

  final String id;
  final String email;
  final String fullName;
  final AgencyDto agency;
  final bool mustChangePassword;
  final List<AgencyRoleDto> roles;

  /// Yalnız `agency-auth/session` yanıtında gelir; `login` yanıtında yoktur.
  final BranchCapabilities capabilities;

  factory AgencyPortalUserDto.fromJson(
    Map<String, dynamic> json,
    AgencyDto agency,
  ) {
    final first = json['firstName'] as String? ?? '';
    final last = json['lastName'] as String? ?? '';
    final composed = [first, last].where((s) => s.isNotEmpty).join(' ');
    final rolesRaw = json['roles'] as List? ?? const [];
    return AgencyPortalUserDto(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: (json['fullName'] as String?)?.isNotEmpty == true
          ? json['fullName'] as String
          : composed,
      agency: agency,
      mustChangePassword: json['mustChangePassword'] as bool? ?? false,
      roles: [
        for (final row in rolesRaw)
          if (row is Map) AgencyRoleDto.fromJson(Map<String, dynamic>.from(row)),
      ],
      capabilities: BranchCapabilities.fromJson(json['capabilities']),
    );
  }
}

/// Thrown for a non-2xx agency-portal response, mirroring [PanelApiException]
/// (see `panel_models.dart`) — callers branch on `code` (e.g.
/// `INVALID_CREDENTIALS`, `ACCOUNT_TEMPORARILY_LOCKED`,
/// `AGENCY_SELECTION_REQUIRED`). `agencies` is only populated for the
/// selection-required case (`login` returns 409 with a candidate list when
/// a user belongs to more than one agency). [serverMessage] is the API's
/// own Turkish `error.message` (present on most 409s) and is safe to show.
class AgencyApiException implements Exception {
  AgencyApiException(
    this.code, {
    this.statusCode,
    this.message,
    this.serverMessage,
    this.reason,
    this.shipmentNumber,
    this.remainingAttempts,
    this.lockedUntil,
    this.agencies = const [],
  });

  final String code;
  final int? statusCode;
  final String? message;
  final String? serverMessage;

  /// 403 `FORBIDDEN` için: BRANCH_OPERATE_REQUIRED | BRANCH_MANAGE_REQUIRED.
  final String? reason;
  final String? shipmentNumber;

  /// Girişte yanlış şifre: kalan deneme hakkı.
  final int? remainingAttempts;

  /// 423 `ACCOUNT_TEMPORARILY_LOCKED`: kilidin açılacağı an.
  final DateTime? lockedUntil;
  final List<AgencyDto> agencies;

  bool get unauthenticated => statusCode == 401;

  bool get isRetryable {
    final s = statusCode;
    if (s == null) return true;
    if (s == 408 || s == 429) return true;
    return s >= 500;
  }

  @override
  String toString() => 'AgencyApiException($code, status: $statusCode)';
}

class AgencyOverviewDto {
  const AgencyOverviewDto({
    required this.agency,
    required this.courierLinks,
    required this.regionLinks,
    required this.nodeLinks,
    required this.currentShipments,
  });

  final AgencyDto agency;
  final int courierLinks;
  final int regionLinks;
  final int nodeLinks;
  final int currentShipments;

  factory AgencyOverviewDto.fromJson(Map<String, dynamic> json) {
    final agency = Map<String, dynamic>.from(json['agency'] as Map? ?? const {});
    final summary = Map<String, dynamic>.from(json['summary'] as Map? ?? const {});
    return AgencyOverviewDto(
      agency: AgencyDto.fromJson(agency),
      courierLinks: (summary['courierLinks'] as num?)?.toInt() ?? 0,
      regionLinks: (summary['regionLinks'] as num?)?.toInt() ?? 0,
      nodeLinks: (summary['nodeLinks'] as num?)?.toInt() ?? 0,
      currentShipments: (summary['currentShipments'] as num?)?.toInt() ?? 0,
    );
  }
}
