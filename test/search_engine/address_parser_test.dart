import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/search_engine/address/address.dart';

void main() {
  final parser = AddressParser.instance;

  group('AddressParser Tests', () {
    test('parses full structured address with commas', () {
      final res = parser.parse('123 Lê Lợi, Quận 1, TP Hồ Chí Minh');
      expect(res.provinceCode, '79');
      expect(res.provinceName, 'Thành phố Hồ Chí Minh');
      expect(res.districtCode, '760');
      expect(res.houseNo, '123');
      expect(res.houseNoMain, 123);
      expect(res.street, 'le loi');
      expect(res.isDestinationIntent, isTrue);
    });

    test('parses address with popular abbreviation HCM', () {
      final res = parser.parse('Chợ Bến Thành, HCM');
      expect(res.provinceCode, '79');
      expect(res.freeText, 'Chợ Bến Thành');
      expect(res.isDestinationIntent, isTrue);
    });

    test('parses address with pre-merger province name (Bình Dương -> TP.HCM)', () {
      final res = parser.parse('Khu công nghiệp VSIP, Bình Dương');
      expect(res.provinceLegacyCode, '74');
      expect(res.provinceCode, '79'); // mapped to canonical post-merger
      expect(res.isDestinationIntent, isTrue);
    });

    test('parses address with Ba Ria Vung Tau -> TP.HCM', () {
      final res = parser.parse('Ngọn Hải Đăng, Vũng Tàu');
      expect(res.provinceCode, '79');
      expect(res.freeText, 'Ngọn Hải Đăng');
      expect(res.isDestinationIntent, isTrue);
    });

    test('parses Hanoi landmark and district', () {
      final res = parser.parse('Hồ Hoàn Kiếm, Quận Hoàn Kiếm, Hà Nội');
      expect(res.provinceCode, '01');
      expect(res.provinceName, 'Thành phố Hà Nội');
      expect(res.districtCode, '002');
      expect(res.isDestinationIntent, isTrue);
    });

    test('parses house number with slash (45/2A)', () {
      final res = parser.parse('45/2A Nguyễn Trãi, Quận 5');
      expect(res.provinceCode, '79');
      expect(res.districtCode, '774');
      expect(res.houseNo, '45/2a');
      expect(res.houseNoMain, 45);
      expect(res.street, 'nguyen trai');
      expect(res.isDestinationIntent, isTrue);
    });

    test('handles unaccented search query with destination intent', () {
      final res = parser.parse('cau rong da nang');
      expect(res.provinceCode, '48');
      expect(res.isDestinationIntent, isTrue);
    });

    test('query without destination returns isDestinationIntent false', () {
      final res = parser.parse('quan ca phe');
      expect(res.provinceCode, isNull);
      expect(res.districtCode, isNull);
      expect(res.isDestinationIntent, isFalse);
    });
  });
}
