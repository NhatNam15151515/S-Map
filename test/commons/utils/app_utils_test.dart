import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/utils/app_utils.dart';
import 'package:s_map/commons/validators/validator.dart';

void main() {
  group('AppUtils - Vietnamese Normalization Tests', () {
    test('removeVietnameseAccents should normalize diacritics correctly', () {
      expect(AppUtils.instance.removeVietnameseAccents('Phở Bát Đàn'), 'pho bat dan');
      expect(AppUtils.instance.removeVietnameseAccents('Đà Nẵng'), 'da nang');
      expect(AppUtils.instance.removeVietnameseAccents('Bệnh viện Chợ Rẫy'), 'benh vien cho ray');
      expect(AppUtils.instance.removeVietnameseAccents('Cà phê Trung Nguyên'), 'ca phe trung nguyen');
      expect(AppUtils.instance.removeVietnameseAccents('Cây xăng Petrolimex'), 'cay xang petrolimex');
    });

    test('toAscii should handle empty and null strings safely', () {
      expect(AppUtils.instance.toAscii(''), '');
      expect(AppUtils.instance.toAscii(null), '');
    });

    test('toAscii should preserve standard alphanumeric characters', () {
      expect(AppUtils.instance.toAscii('Highlands Coffee 123'), 'highlands coffee 123');
    });
  });

  group('Validator - hasDiacritics Tests', () {
    test('hasDiacritics should return true for Vietnamese text with accents', () {
      expect(Validator.instance.hasDiacritics('phở'), isTrue);
      expect(Validator.instance.hasDiacritics('Đà Lạt'), isTrue);
      expect(Validator.instance.hasDiacritics('bệnh viện'), isTrue);
      expect(Validator.instance.hasDiacritics('cà phê'), isTrue);
    });

    test('hasDiacritics should return false for ascii-only text', () {
      expect(Validator.instance.hasDiacritics('pho'), isFalse);
      expect(Validator.instance.hasDiacritics('Da Lat'), isFalse);
      expect(Validator.instance.hasDiacritics('benh vien'), isFalse);
      expect(Validator.instance.hasDiacritics('cafe'), isFalse);
      expect(Validator.instance.hasDiacritics('123'), isFalse);
      expect(Validator.instance.hasDiacritics(''), isFalse);
      expect(Validator.instance.hasDiacritics(null), isFalse);
    });
  });
}
