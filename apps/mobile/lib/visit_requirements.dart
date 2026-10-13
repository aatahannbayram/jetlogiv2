import 'l10n.dart';

/// `GET courier-tasks/{id}/requirements` yanıtının ziyaret akışında kullanılan
/// kısmı: fotoğraf gereksinimleri (kontrol listesiyle), anket ve koşulları.
class PhotoRequirement {
  const PhotoRequirement({
    required this.code,
    required this.label,
    this.categoryCode = 'OTHER',
    this.minCount = 1,
    this.hint,
    this.checklist = const [],
    this.maxDistanceMeters,
  });

  factory PhotoRequirement.fromJson(Map<String, dynamic> j) => PhotoRequirement(
    code: j['code'] as String? ?? '',
    label: j['label'] as String? ?? '',
    categoryCode: j['categoryCode'] as String? ?? 'OTHER',
    minCount: (j['minCount'] as num?)?.toInt() ?? 1,
    hint: j['hint'] as String?,
    checklist: [
      for (final row in j['checklist'] as List? ?? const [])
        if (row is String && row.trim().isNotEmpty) row.trim(),
    ],
    maxDistanceMeters: (j['maxDistanceMeters'] as num?)?.toInt(),
  );

  final String code;
  final String label;
  final String categoryCode;
  final int minCount;
  final String? hint;
  final List<String> checklist;
  final int? maxDistanceMeters;
}

/// `COMPLETION_FORM_CONDITION_V1`. Karşılaştırma katıdır: metinler kırpılıp
/// eşitlenir, diğer tipler `==` ile.
class FormCondition {
  const FormCondition({
    required this.fieldCode,
    required this.operatorCode,
    this.value,
    this.known = true,
  });

  static FormCondition? fromJson(Object? raw) {
    if (raw is! Map) return null;
    return FormCondition(
      fieldCode: (raw['fieldCode'] as String? ?? '').toUpperCase(),
      operatorCode: raw['operatorCode'] as String? ?? '',
      value: raw['value'],
      known: raw['schemaVersion'] == 'COMPLETION_FORM_CONDITION_V1',
    );
  }

  final String fieldCode;
  final String operatorCode;
  final Object? value;
  final bool known;

  static bool isEmptyValue(Object? v) =>
      v == null ||
      (v is String && v.trim().isEmpty) ||
      (v is List && v.isEmpty);

  static bool _same(Object? a, Object? b) {
    if (a is String && b is String) return a.trim() == b.trim();
    return a == b;
  }

  /// Bilinmeyen şema ya da operatörde null döner; çağıran varsayılanı seçer.
  bool? test(Map<String, Object?> values) {
    if (!known) return null;
    final v = values[fieldCode];
    final empty = isEmptyValue(v);
    final equal =
        !empty && (v is List ? v.any((e) => _same(e, value)) : _same(v, value));
    switch (operatorCode) {
      case 'EQ':
      case 'CONTAINS':
        return equal;
      case 'NEQ':
      case 'NOT_CONTAINS':
        return !equal;
      case 'IS_EMPTY':
        return empty;
      case 'NOT_EMPTY':
        return !empty;
    }
    return null;
  }
}

class VisitFormField {
  const VisitFormField({
    required this.code,
    required this.type,
    required this.label,
    this.description,
    this.isRequired = false,
    this.isMultiValue = false,
    this.options = const [],
    this.visibilityRule,
    this.requiredRule,
    this.sortOrder = 0,
  });

  factory VisitFormField.fromJson(Map<String, dynamic> j) => VisitFormField(
    code: (j['code'] as String? ?? '').toUpperCase(),
    type: j['dataTypeCode'] as String? ?? 'STRING',
    label: j['label'] as String? ?? '',
    description: j['description'] as String?,
    isRequired: j['isRequired'] == true,
    isMultiValue: j['isMultiValue'] == true,
    options: [
      for (final row in j['options'] as List? ?? const [])
        if (row is Map && row['code'] is String)
          (
            code: row['code'] as String,
            label: row['label'] as String? ?? row['code'] as String,
          ),
    ],
    visibilityRule: FormCondition.fromJson(j['visibilityRule']),
    requiredRule: FormCondition.fromJson(j['requiredRule']),
    sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
  );

  final String code;

  /// STRING, NUMBER, BOOLEAN, DATE, TIMESTAMP, CODE.
  final String type;
  final String label;
  final String? description;
  final bool isRequired;
  final bool isMultiValue;
  final List<({String code, String label})> options;
  final FormCondition? visibilityRule;
  final FormCondition? requiredRule;
  final int sortOrder;
}

class VisitForm {
  const VisitForm({
    required this.formVersionId,
    required this.title,
    required this.fields,
    this.instructions,
    this.required = false,
  });

  factory VisitForm.fromJson(Map<String, dynamic> j) => VisitForm(
    formVersionId: j['formVersionId'] as String? ?? '',
    title: j['title'] as String? ?? '',
    instructions: j['instructions'] as String?,
    required: j['required'] == true,
    fields: [
      for (final row in j['fields'] as List? ?? const [])
        if (row is Map) VisitFormField.fromJson(Map<String, dynamic>.from(row)),
    ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
  );

  final String formVersionId;
  final String title;
  final String? instructions;
  final bool required;
  final List<VisitFormField> fields;

  /// Koşulu bilinmeyen alan görünür sayılır.
  bool isVisible(VisitFormField f, Map<String, Object?> values) =>
      f.visibilityRule?.test(values) ?? true;

  /// Koşulu bilinmeyen alan zorunlu sayılmaz.
  bool isRequired(VisitFormField f, Map<String, Object?> values) =>
      f.isRequired || (f.requiredRule?.test(values) ?? false);

  List<VisitFormField> visibleFields(Map<String, Object?> values) => [
    for (final f in fields)
      if (isVisible(f, values)) f,
  ];

  /// Görünür olup zorunlu olan ama boş bırakılmış alanlar.
  List<VisitFormField> missing(Map<String, Object?> values) => [
    for (final f in visibleFields(values))
      if (isRequired(f, values) && FormCondition.isEmptyValue(values[f.code]))
        f,
  ];

  /// Sunucuya gidecek değerler: gizli ve boş alanlar atılır.
  Map<String, Object?> cleanValues(Map<String, Object?> values) => {
    for (final f in visibleFields(values))
      if (!FormCondition.isEmptyValue(values[f.code]))
        f.code: values[f.code] is String
            ? (values[f.code] as String).trim()
            : values[f.code],
  };

  /// "Yapılamadı" yolunda seçilen nedeni ankete taşır: seçenek adı nedenle
  /// aynı olan alan doldurulur, o alanı görünür kılan soru da buna göre
  /// yanıtlanır. Böylece kurye aynı nedeni iki kez seçmez.
  Map<String, Object?> prefillForReason(String reasonName) {
    final wanted = _fold(reasonName);
    final out = <String, Object?>{};
    for (final f in fields) {
      if (f.type != 'CODE' || f.isMultiValue) continue;
      for (final o in f.options) {
        if (_fold(o.label) != wanted) continue;
        out[f.code] = o.code;
        final rule = f.visibilityRule;
        if (rule != null && rule.known && rule.operatorCode == 'EQ') {
          out[rule.fieldCode] = rule.value;
        }
        break;
      }
    }
    return out;
  }

  static String _fold(String s) =>
      localeUpper(s.trim(), 'tr').replaceAll(RegExp(r'\s+'), ' ');
}

class VisitRequirements {
  const VisitRequirements({
    this.photos = const [],
    this.failurePhotos = const [],
    this.appliesTo = 'DELIVERED',
    this.failureFormRequired = false,
    this.locationRequired = false,
    this.form,
    this.uploaded = const {},
    this.formSubmitted = false,
  });

  /// Yanıt gövdesi (`data`) ya da doğrudan `deliveryRequirements` nesnesi.
  factory VisitRequirements.fromJson(Map<String, dynamic> data) {
    final raw = data['deliveryRequirements'];
    final j = raw is Map ? Map<String, dynamic>.from(raw) : data;
    List<PhotoRequirement> list(String key) => [
      for (final row in j[key] as List? ?? const [])
        if (row is Map)
          PhotoRequirement.fromJson(Map<String, dynamic>.from(row)),
    ].where((p) => p.code.isNotEmpty).toList();
    final progress = j['progress'] is Map ? j['progress'] as Map : const {};
    final form = j['form'];
    return VisitRequirements(
      photos: list('photos'),
      failurePhotos: list('failurePhotos'),
      appliesTo: j['appliesTo'] as String? ?? 'DELIVERED',
      failureFormRequired: j['failureFormRequired'] == true,
      locationRequired: j['locationRequired'] == true,
      form: form is Map
          ? VisitForm.fromJson(Map<String, dynamic>.from(form))
          : null,
      uploaded: {
        if (progress['photos'] is Map)
          for (final e in (progress['photos'] as Map).entries)
            if (e.value is num) '${e.key}': (e.value as num).toInt(),
      },
      formSubmitted: progress['formSubmitted'] == true,
    );
  }

  final List<PhotoRequirement> photos;
  final List<PhotoRequirement> failurePhotos;
  final String appliesTo;
  final bool failureFormRequired;
  final bool locationRequired;
  final VisitForm? form;

  /// Sunucuda sayılan fotoğraf adedi, gereksinim koduna göre.
  final Map<String, int> uploaded;
  final bool formSubmitted;

  /// Kontrol listesi, anket ya da ayrı "yapılamadı" fotoğrafı isteyen işler
  /// adım adım ziyaret akışıyla kapatılır; diğerleri klasik teslim akışıyla.
  bool get guided =>
      form != null ||
      failurePhotos.isNotEmpty ||
      photos.any((p) => p.checklist.isNotEmpty);

  List<PhotoRequirement> photosFor({required bool delivered}) {
    if (delivered) return photos;
    if (appliesTo != 'BOTH') return const [];
    return failurePhotos.isNotEmpty ? failurePhotos : photos;
  }

  bool formNeeded({required bool delivered}) {
    final f = form;
    if (f == null || f.fields.isEmpty) return false;
    return delivered ? f.required : failureFormRequired;
  }
}
