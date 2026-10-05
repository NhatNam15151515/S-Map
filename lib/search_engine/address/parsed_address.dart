class ParsedAddress {
  final String rawQuery;
  final String freeText;
  final String? provinceCode;
  final String? provinceLegacyCode;
  final String? provinceName;
  final String? districtCode;
  final String? districtName;
  final String? street;
  final String? houseNo;
  final int? houseNoMain;
  final bool isDestinationIntent;

  const ParsedAddress({
    required this.rawQuery,
    this.freeText = '',
    this.provinceCode,
    this.provinceLegacyCode,
    this.provinceName,
    this.districtCode,
    this.districtName,
    this.street,
    this.houseNo,
    this.houseNoMain,
    this.isDestinationIntent = false,
  });

  bool get hasProvince => provinceCode != null && provinceCode!.isNotEmpty;
  bool get hasDistrict => districtCode != null && districtCode!.isNotEmpty;
  bool get hasStreet => street != null && street!.isNotEmpty;
  bool get hasHouseNo => houseNo != null && houseNo!.isNotEmpty;

  @override
  String toString() {
    return 'ParsedAddress('
        'freeText: "$freeText", '
        'prov: $provinceCode, '
        'dist: $districtCode, '
        'street: "$street", '
        'house: "$houseNo", '
        'destIntent: $isDestinationIntent)';
  }
}
