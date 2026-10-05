import 'parsed_address.dart';

class AddressParser {
  AddressParser._();

  static final AddressParser instance = AddressParser._();

  static const List<String> _provincePrefixes = [
    'thanh pho',
    'tinh',
    'tp',
    'tp.',
  ];

  static const List<String> _districtPrefixes = [
    'thanh pho',
    'thi xa',
    'quan',
    'huyen',
    'tp',
    'tx',
    'q.',
    'h.',
    'q',
    'h',
  ];

  static const List<String> _streetPrefixes = [
    'duong',
    'pho',
    'd.',
    'd',
    'hem',
    'ngo',
    'ngach',
    'kiet',
    'ql',
    'quoc lo',
    'tinh lo',
    'dt',
    'dai lo',
    'tl',
  ];

  // Map tên core không dấu -> mã tỉnh cũ (GSO code)
  static final Map<String, String> _provinceCoreToOldCode = {
    'ha noi': '01',
    'ha giang': '02',
    'cao bang': '04',
    'bac kan': '06',
    'tuyen quang': '08',
    'lao cai': '10',
    'dien bien': '11',
    'lai chau': '12',
    'son la': '14',
    'yen bai': '15',
    'hoa binh': '17',
    'thai nguyen': '19',
    'lang son': '20',
    'quang ninh': '22',
    'bac giang': '24',
    'phu tho': '25',
    'vinh phuc': '26',
    'bac ninh': '27',
    'hai duong': '30',
    'hai phong': '31',
    'hung yen': '33',
    'thai binh': '34',
    'ha nam': '35',
    'nam dinh': '36',
    'ninh binh': '37',
    'thanh hoa': '38',
    'nghe an': '40',
    'ha tinh': '42',
    'quang binh': '44',
    'quang tri': '45',
    'thua thien hue': '46',
    'da nang': '48',
    'quang nam': '49',
    'quang ngai': '51',
    'binh dinh': '52',
    'phu yen': '54',
    'khanh hoa': '56',
    'ninh thuan': '58',
    'binh thuan': '60',
    'kon tum': '62',
    'gia lai': '64',
    'dak lak': '66',
    'dak nong': '67',
    'lam dong': '68',
    'binh phuoc': '70',
    'tay ninh': '72',
    'binh duong': '74',
    'dong nai': '75',
    'ba ria - vung tau': '77',
    'ba ria vung tau': '77',
    'vung tau': '77',
    'ho chi minh': '79',
    'long an': '80',
    'tien giang': '82',
    'ben tre': '83',
    'tra vinh': '84',
    'vinh long': '86',
    'dong thap': '87',
    'an giang': '89',
    'kien giang': '91',
    'can tho': '92',
    'hau giang': '93',
    'soc trang': '94',
    'bac lieu': '95',
    'ca mau': '96',
  };

  // Map mã tỉnh cũ -> mã tỉnh mới (34 tỉnh thành lập 07/2025)
  static final Map<String, String> _oldCodeToNewCode = {
    '01': '01', // Hà Nội
    '02': '08', // Hà Giang -> Tuyên Quang
    '04': '04', // Cao Bằng
    '06': '19', // Bắc Kạn -> Thái Nguyên
    '08': '08', // Tuyên Quang
    '10': '10', // Lào Cai
    '11': '11', // Điện Biên
    '12': '12', // Lai Châu
    '14': '14', // Sơn La
    '15': '10', // Yên Bái -> Lào Cai
    '17': '25', // Hòa Bình -> Phú Thọ
    '19': '19', // Thái Nguyên
    '20': '20', // Lạng Sơn
    '22': '22', // Quảng Ninh
    '24': '27', // Bắc Giang -> Bắc Ninh
    '25': '25', // Phú Thọ
    '26': '25', // Vĩnh Phúc -> Phú Thọ
    '27': '27', // Bắc Ninh
    '30': '31', // Hải Dương -> Hải Phòng
    '31': '31', // Hải Phòng
    '33': '33', // Hưng Yên
    '34': '33', // Thái Bình -> Hưng Yên
    '35': '37', // Hà Nam -> Ninh Bình
    '36': '37', // Nam Định -> Ninh Bình
    '37': '37', // Ninh Bình
    '38': '38', // Thanh Hóa
    '40': '40', // Nghệ An
    '42': '42', // Hà Tĩnh
    '44': '45', // Quảng Bình -> Quảng Trị
    '45': '45', // Quảng Trị
    '46': '46', // Thừa Thiên Huế (TP Huế)
    '48': '48', // Đà Nẵng
    '49': '48', // Quảng Nam -> Đà Nẵng
    '51': '51', // Quảng Ngãi
    '52': '64', // Bình Định -> Gia Lai
    '54': '66', // Phú Yên -> Đắk Lắk
    '56': '56', // Khánh Hòa
    '58': '56', // Ninh Thuận -> Khánh Hòa
    '60': '68', // Bình Thuận -> Lâm Đồng
    '62': '51', // Kon Tum -> Quảng Ngãi
    '64': '64', // Gia Lai
    '66': '66', // Đắk Lắk
    '67': '68', // Đắk Nông -> Lâm Đồng
    '68': '68', // Lâm Đồng
    '70': '75', // Bình Phước -> Đồng Nai
    '72': '72', // Tây Ninh
    '74': '79', // Bình Dương -> TP.HCM
    '75': '75', // Đồng Nai
    '77': '79', // Bà Rịa - Vũng Tàu -> TP.HCM
    '79': '79', // TP.HCM
    '80': '72', // Long An -> Tây Ninh
    '82': '87', // Tiền Giang -> Đồng Tháp
    '83': '86', // Bến Tre -> Vĩnh Long
    '84': '86', // Trà Vinh -> Vĩnh Long
    '86': '86', // Vĩnh Long
    '87': '87', // Đồng Tháp
    '89': '89', // An Giang
    '91': '89', // Kiên Giang -> An Giang
    '92': '92', // Cần Thơ
    '93': '92', // Hậu Giang -> Cần Thơ
    '94': '92', // Sóc Trăng -> Cần Thơ
    '95': '96', // Bạc Liêu -> Cà Mau
    '96': '96', // Cà Mau
  };

  // Tên hiển thị chuẩn của 34 tỉnh mới
  static const Map<String, String> _newProvinceNames = {
    '01': 'Thành phố Hà Nội',
    '04': 'Tỉnh Cao Bằng',
    '08': 'Tỉnh Tuyên Quang',
    '10': 'Tỉnh Lào Cai',
    '11': 'Tỉnh Điện Biên',
    '12': 'Tỉnh Lai Châu',
    '14': 'Tỉnh Sơn La',
    '19': 'Tỉnh Thái Nguyên',
    '20': 'Tỉnh Lạng Sơn',
    '22': 'Tỉnh Quảng Ninh',
    '25': 'Tỉnh Phú Thọ',
    '27': 'Tỉnh Bắc Ninh',
    '31': 'Thành phố Hải Phòng',
    '33': 'Tỉnh Hưng Yên',
    '37': 'Tỉnh Ninh Bình',
    '38': 'Tỉnh Thanh Hóa',
    '40': 'Tỉnh Nghệ An',
    '42': 'Tỉnh Hà Tĩnh',
    '45': 'Tỉnh Quảng Trị',
    '46': 'Thành phố Huế',
    '48': 'Thành phố Đà Nẵng',
    '51': 'Tỉnh Quảng Ngãi',
    '56': 'Tỉnh Khánh Hòa',
    '64': 'Tỉnh Gia Lai',
    '66': 'Tỉnh Đắk Lắk',
    '68': 'Tỉnh Lâm Đồng',
    '72': 'Tỉnh Tây Ninh',
    '75': 'Tỉnh Đồng Nai',
    '79': 'Thành phố Hồ Chí Minh',
    '86': 'Tỉnh Vĩnh Long',
    '87': 'Tỉnh Đồng Tháp',
    '89': 'Tỉnh An Giang',
    '92': 'Thành phố Cần Thơ',
    '96': 'Tỉnh Cà Mau',
  };

  // Alias đặc biệt người dùng hay gõ
  static final Map<String, String> _customAliases = {
    'hcm': '79',
    'tphcm': '79',
    'hcmc': '79',
    'sai gon': '79',
    'saigon': '79',
    'sg': '79',
    'tp hcm': '79',
    'ho chi minh city': '79',
    'hn': '01',
    'ha noi city': '01',
    'brvt': '79', // Vũng Tàu -> HCM mới
    'vung tau': '79',
    'hue': '46',
    'da nang city': '48',
    'can tho city': '92',
    'hai phong city': '31',
  };

  // Một số quận/huyện phổ biến để nhận diện khi query không có tỉnh
  static final Map<String, ({String code, String provCode})> _knownDistricts = {
    // TP.HCM
    'quan 1': (code: '760', provCode: '79'),
    'q 1': (code: '760', provCode: '79'),
    'q1': (code: '760', provCode: '79'),
    'quan 3': (code: '770', provCode: '79'),
    'q 3': (code: '770', provCode: '79'),
    'q3': (code: '770', provCode: '79'),
    'quan 4': (code: '773', provCode: '79'),
    'q 4': (code: '773', provCode: '79'),
    'quan 5': (code: '774', provCode: '79'),
    'quan 7': (code: '778', provCode: '79'),
    'quan 10': (code: '771', provCode: '79'),
    'quan 11': (code: '772', provCode: '79'),
    'quan 12': (code: '761', provCode: '79'),
    'binh thanh': (code: '765', provCode: '79'),
    'quan binh thanh': (code: '765', provCode: '79'),
    'phu nhuan': (code: '768', provCode: '79'),
    'quan phu nhuan': (code: '768', provCode: '79'),
    'go vap': (code: '764', provCode: '79'),
    'quan go vap': (code: '764', provCode: '79'),
    'tan binh': (code: '766', provCode: '79'),
    'quan tan binh': (code: '766', provCode: '79'),
    'tan phu': (code: '767', provCode: '79'),
    'quan tan phu': (code: '767', provCode: '79'),
    'thu duc': (code: '769', provCode: '79'),
    'thanh pho thu duc': (code: '769', provCode: '79'),
    // Hà Nội
    'ba dinh': (code: '001', provCode: '01'),
    'quan ba dinh': (code: '001', provCode: '01'),
    'hoan kiem': (code: '002', provCode: '01'),
    'quan hoan kiem': (code: '002', provCode: '01'),
    'tay ho': (code: '003', provCode: '01'),
    'cau giay': (code: '005', provCode: '01'),
    'dong da': (code: '006', provCode: '01'),
    'hai ba trung': (code: '007', provCode: '01'),
    'hoang mai': (code: '008', provCode: '01'),
    'thanh xuan': (code: '009', provCode: '01'),
    'ha dong': (code: '268', provCode: '01'),
    // Đà Nẵng
    'hai chau': (code: '490', provCode: '48'),
    'thanh khe': (code: '491', provCode: '48'),
    'son tra': (code: '492', provCode: '48'),
    'ngu hanh son': (code: '493', provCode: '48'),
    'lien chieu': (code: '494', provCode: '48'),
  };

  static final RegExp _stripPunctuation = RegExp(r'[^\p{L}\p{N}/\- ]+', unicode: true);
  static final RegExp _multipleSpaces = RegExp(r'\s+');
  static final RegExp _houseNumberRegExp = RegExp(
    r'^(?:so\s+)?(\d+[a-z]?(?:\s*[/-]\s*\d+[a-z]?)*)\s+(.+)$',
    caseSensitive: false,
  );
  static final RegExp _houseOnlyRegExp = RegExp(
    r'^(?:so\s+)?(\d+[a-z]?(?:\s*[/-]\s*\d+[a-z]?)*)$',
    caseSensitive: false,
  );

  /// Bỏ dấu tiếng Việt, chuyển sang lowercase ASCII
  static String toAscii(String text) {
    var s = text.toLowerCase();
    const vietnamese = [
      'aàảãáạăằẳẵắặâầẩẫấậ',
      'dđ',
      'eèẻẽéẹêềểễếệ',
      'iìỉĩíị',
      'oòỏõóọôồổỗốộơờởỡớợ',
      'uùủũúụưừửữứự',
      'yỳỷỹýỵ',
    ];
    const ascii = ['a', 'd', 'e', 'i', 'o', 'u', 'y'];
    for (var i = 0; i < vietnamese.length; i++) {
      for (final char in vietnamese[i].split('')) {
        s = s.replaceAll(char, ascii[i]);
      }
    }
    return s;
  }

  /// Chuẩn hóa chuỗi tìm kiếm thành dạng core không dấu
  static String normalizeCore(String text) {
    return toAscii(text)
        .replaceAll(_stripPunctuation, ' ')
        .replaceAll(_multipleSpaces, ' ')
        .trim();
  }

  /// Bóc tách một chuỗi tìm kiếm đầu vào thành cấu trúc `ParsedAddress`
  ParsedAddress parse(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return ParsedAddress(rawQuery: query);
    }

    String? foundProvinceCode;
    String? foundProvinceLegacyCode;
    String? foundProvinceName;
    String? foundDistrictCode;
    String? foundDistrictName;
    String? foundStreet;
    String? foundHouseNo;
    int? foundHouseNoMain;

    // 1. Phân tách theo dấu phẩy hoặc dấu gạch ngang (nếu người dùng nhập có cấu trúc)
    final commaSegments = trimmed.split(RegExp(r'[,|;]|\s+-\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    var workingText = trimmed;

    // Quét tìm tỉnh/thành phố từ segments (quét phải -> trái)
    for (var i = commaSegments.length - 1; i >= 0; i--) {
      final segNorm = normalizeCore(commaSegments[i]);
      final provMatch = _matchProvince(segNorm);
      if (provMatch != null) {
        foundProvinceCode = provMatch.newCode;
        foundProvinceLegacyCode = provMatch.oldCode;
        foundProvinceName = _newProvinceNames[foundProvinceCode];
        // Bỏ segment này khỏi workingText
        commaSegments.removeAt(i);
        workingText = commaSegments.join(', ');
        break;
      }
    }

    // Nếu phân tách bằng dấu phẩy không tìm thấy tỉnh, quét theo regex cuối chuỗi
    if (foundProvinceCode == null) {
      final normAll = normalizeCore(trimmed);
      for (final entry in _customAliases.entries) {
        if (normAll == entry.key ||
            normAll.endsWith(' ${entry.key}') ||
            normAll.startsWith('${entry.key} ')) {
          foundProvinceCode = entry.value;
          foundProvinceName = _newProvinceNames[foundProvinceCode];
          // Bỏ alias khỏi workingText
          workingText = _removeSubstring(trimmed, entry.key);
          break;
        }
      }
      if (foundProvinceCode == null) {
        for (final entry in _provinceCoreToOldCode.entries) {
          final core = entry.key;
          if (normAll == core ||
              normAll.endsWith(' $core') ||
              normAll.startsWith('$core ')) {
            foundProvinceLegacyCode = entry.value;
            foundProvinceCode = _oldCodeToNewCode[entry.value] ?? entry.value;
            foundProvinceName = _newProvinceNames[foundProvinceCode];
            workingText = _removeSubstring(trimmed, core);
            break;
          }
        }
      }
    }

    // 2. Tìm Quận/Huyện trong workingText
    final normWorking = normalizeCore(workingText);
    for (final entry in _knownDistricts.entries) {
      final distCore = entry.key;
      final hasPrefix = _districtPrefixes
          .any((p) => distCore.startsWith('$p ') || distCore.startsWith(p));
      final isExactMatch = normWorking == distCore;
      final isSegmentMatch = commaSegments.any((s) => normalizeCore(s) == distCore);
      final isPrefixedSub = hasPrefix &&
          (normWorking.contains(' $distCore') ||
              normWorking.startsWith('$distCore ') ||
              normWorking.contains(' $distCore '));

      if (isExactMatch || isSegmentMatch || isPrefixedSub) {
        foundDistrictCode = entry.value.code;
        foundDistrictName = distCore;
        if (foundProvinceCode == null) {
          foundProvinceCode = entry.value.provCode;
          foundProvinceName = _newProvinceNames[foundProvinceCode];
        }
        workingText = _removeSubstring(workingText, distCore);
        break;
      }
    }

    // 3. Tách Số nhà & Tên đường từ phần còn lại
    var cleanRemaining = workingText
        .replaceAll(RegExp(r'^[\s,.\-]+|[\s,.\-]+$'), '')
        .trim();

    // Thử bắt số nhà ở đầu chuỗi: "123 Lê Lợi" -> 123 + Lê Lợi
    final houseMatch = _houseNumberRegExp.firstMatch(cleanRemaining);
    if (houseMatch != null) {
      final rawHouse = houseMatch.group(1)!.replaceAll(' ', '').toLowerCase();
      foundHouseNo = rawHouse;
      final digitsMatch = RegExp(r'^\d+').firstMatch(rawHouse);
      if (digitsMatch != null) {
        foundHouseNoMain = int.tryParse(digitsMatch.group(0)!);
      }
      cleanRemaining = houseMatch.group(2)!.trim();
    } else {
      // Trường hợp chỉ có số nhà: "123"
      final houseOnlyMatch = _houseOnlyRegExp.firstMatch(cleanRemaining);
      if (houseOnlyMatch != null) {
        final rawHouse = houseOnlyMatch.group(1)!.replaceAll(' ', '').toLowerCase();
        foundHouseNo = rawHouse;
        final digitsMatch = RegExp(r'^\d+').firstMatch(rawHouse);
        if (digitsMatch != null) {
          foundHouseNoMain = int.tryParse(digitsMatch.group(0)!);
        }
        cleanRemaining = '';
      }
    }

    // Bỏ tiền tố tên đường nếu có (đường, phố, đại lộ...)
    final remainingNorm = normalizeCore(cleanRemaining);
    for (final prefix in _streetPrefixes) {
      if (remainingNorm == prefix) {
        cleanRemaining = '';
        break;
      }
      if (remainingNorm.startsWith('$prefix ')) {
        final prefixWords = prefix.split(' ').length;
        final words = cleanRemaining.split(RegExp(r'\s+'));
        if (words.length > prefixWords) {
          cleanRemaining = words.sublist(prefixWords).join(' ');
        }
        break;
      }
    }

    if (foundHouseNo != null && cleanRemaining.isNotEmpty) {
      foundStreet = normalizeCore(cleanRemaining);
    }

    final hasExplicitAdmin = foundProvinceCode != null ||
        foundDistrictCode != null ||
        (foundHouseNo != null && foundStreet != null);

    return ParsedAddress(
      rawQuery: query,
      freeText: cleanRemaining.isEmpty ? trimmed : cleanRemaining,
      provinceCode: foundProvinceCode,
      provinceLegacyCode: foundProvinceLegacyCode,
      provinceName: foundProvinceName,
      districtCode: foundDistrictCode,
      districtName: foundDistrictName,
      street: foundStreet,
      houseNo: foundHouseNo,
      houseNoMain: foundHouseNoMain,
      isDestinationIntent: hasExplicitAdmin,
    );
  }

  static ({String oldCode, String newCode})? _matchProvince(String norm) {
    var cleaned = norm;
    for (final prefix in _provincePrefixes) {
      if (cleaned == prefix) return null;
      if (cleaned.startsWith('$prefix ')) {
        cleaned = cleaned.substring(prefix.length + 1).trim();
        break;
      }
    }

    final aliasCode = _customAliases[cleaned];
    if (aliasCode != null) {
      return (oldCode: aliasCode, newCode: aliasCode);
    }

    final oldCode = _provinceCoreToOldCode[cleaned];
    if (oldCode != null) {
      final newCode = _oldCodeToNewCode[oldCode] ?? oldCode;
      return (oldCode: oldCode, newCode: newCode);
    }

    return null;
  }

  static String _removeSubstring(String source, String toRemove) {
    final normSource = normalizeCore(source);
    final normRemove = normalizeCore(toRemove);
    final idx = normSource.indexOf(normRemove);
    if (idx < 0) return source;

    // Cắt bỏ an toàn tương ứng độ dài token
    final words = source.split(RegExp(r'\s+'));
    final removeWordCount = normRemove.split(RegExp(r'\s+')).length;
    final normWords = words.map(normalizeCore).toList();

    for (var i = 0; i <= normWords.length - removeWordCount; i++) {
      final slice = normWords.sublist(i, i + removeWordCount).join(' ');
      if (slice == normRemove) {
        words.removeRange(i, i + removeWordCount);
        return words.join(' ').replaceAll(RegExp(r'[,.\-]+$'), '').trim();
      }
    }
    return source.replaceAll(toRemove, '').trim();
  }
}
