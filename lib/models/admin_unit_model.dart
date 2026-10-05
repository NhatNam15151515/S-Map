class AdminUnitModel {
  final String code;
  final int level; // 4: tỉnh, 6: quận/huyện
  final String name;
  final String nameCore;
  final String accentCore;
  final String? kind;
  final String? parentCode;
  final String? successorCode;
  final String? successorName;
  final bool isLegacy;

  const AdminUnitModel({
    required this.code,
    required this.level,
    required this.name,
    required this.nameCore,
    required this.accentCore,
    this.kind,
    this.parentCode,
    this.successorCode,
    this.successorName,
    this.isLegacy = false,
  });

  factory AdminUnitModel.fromMap(Map<String, dynamic> map) {
    return AdminUnitModel(
      code: map['code']?.toString() ?? '',
      level: (map['level'] as num?)?.toInt() ?? 4,
      name: map['name']?.toString() ?? '',
      nameCore: map['name_core']?.toString() ?? '',
      accentCore: map['accent_core']?.toString() ?? '',
      kind: map['kind']?.toString(),
      parentCode: map['parent_code']?.toString(),
      successorCode: map['successor_code']?.toString(),
      successorName: map['successor_name']?.toString(),
      isLegacy: (map['is_legacy'] as num?)?.toInt() == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'level': level,
      'name': name,
      'name_core': nameCore,
      'accent_core': accentCore,
      if (kind != null) 'kind': kind,
      if (parentCode != null) 'parent_code': parentCode,
      if (successorCode != null) 'successor_code': successorCode,
      if (successorName != null) 'successor_name': successorName,
      'is_legacy': isLegacy ? 1 : 0,
    };
  }

  @override
  String toString() => 'AdminUnitModel(code: $code, level: $level, name: $name)';
}
