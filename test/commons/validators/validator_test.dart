import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/validators/validator.dart';

void main() {
  late Validator validator;

  setUp(() {
    validator = Validator.instance;
  });

  group('Validator - isCoordinates', () {
    test('should return true for valid coordinates', () {
      expect(validator.isCoordinates('10.762622, 106.660172'), isTrue);
      expect(validator.isCoordinates('-6.2088, 106.8456'), isTrue);
      expect(validator.isCoordinates('21.0285 105.8542'), isTrue);
      expect(validator.isCoordinates(' -33.8688 , 151.2093 '), isTrue);
      expect(validator.isCoordinates('0, 0'), isTrue);
    });

    test('should return false for invalid coordinates or non-numeric input', () {
      expect(validator.isCoordinates('999, 999'), isFalse);
      expect(validator.isCoordinates('95.0, 100.0'), isFalse); // Lat > 90
      expect(validator.isCoordinates('10.0, 200.0'), isFalse); // Lng > 180
      expect(validator.isCoordinates('abc, def'), isFalse);
      expect(validator.isCoordinates('10.123'), isFalse);
      expect(validator.isCoordinates(''), isFalse);
      expect(validator.isCoordinates(null), isFalse);
    });
  });

  group('Validator - isMapUrl', () {
    test('should return true for Google Maps and share URLs', () {
      expect(validator.isMapUrl('https://maps.app.goo.gl/abCdEf123'), isTrue);
      expect(validator.isMapUrl('https://www.google.com/maps/place/Ben+Thanh'), isTrue);
      expect(validator.isMapUrl('http://goo.gl/maps/xyz987'), isTrue);
      expect(validator.isMapUrl('https://maps.google.com/?q=10.762,106.660'), isTrue);
    });

    test('should return false for non-map URLs or empty inputs', () {
      expect(validator.isMapUrl('https://www.facebook.com'), isFalse);
      expect(validator.isMapUrl('https://www.google.com'), isFalse);
      expect(validator.isMapUrl('not a url'), isFalse);
      expect(validator.isMapUrl(''), isFalse);
      expect(validator.isMapUrl(null), isFalse);
    });
  });

  group('Validator - isValidSearchQuery', () {
    test('should return true for queries with length >= 2', () {
      expect(validator.isValidSearchQuery('Hà Nội'), isTrue);
      expect(validator.isValidSearchQuery('TP.HCM'), isTrue);
      expect(validator.isValidSearchQuery('Q1'), isTrue);
      expect(validator.isValidSearchQuery('  Ben Thanh  '), isTrue);
    });

    test('should return false for empty or single-character queries', () {
      expect(validator.isValidSearchQuery(''), isFalse);
      expect(validator.isValidSearchQuery('a'), isFalse);
      expect(validator.isValidSearchQuery('  b  '), isFalse);
      expect(validator.isValidSearchQuery(null), isFalse);
    });
  });

  group('Validator - Basic Auth & Form Validators', () {
    test('isEmpty should validate empty/whitespace strings', () {
      expect(validator.isEmpty(''), isTrue);
      expect(validator.isEmpty('   '), isTrue);
      expect(validator.isEmpty(null), isTrue);
      expect(validator.isEmpty('valid text'), isFalse);
    });

    test('isValidEmail should validate email correctly', () {
      expect(validator.isValidEmail('test@example.com'), isTrue);
      expect(validator.isValidEmail('user.name+tag@domain.co'), isTrue);
      expect(validator.isValidEmail('invalid-email'), isFalse);
      expect(validator.isValidEmail('@nodomain.com'), isFalse);
      expect(validator.isValidEmail(null), isFalse);
    });

    test('isValidPassword should require at least 6 characters', () {
      expect(validator.isValidPassword('123456'), isTrue);
      expect(validator.isValidPassword('password123'), isTrue);
      expect(validator.isValidPassword('12345'), isFalse);
      expect(validator.isValidPassword(null), isFalse);
    });

    test('isValidPhone should require at least 9 characters', () {
      expect(validator.isValidPhone('0901234567'), isTrue);
      expect(validator.isValidPhone('+84901234567'), isTrue);
      expect(validator.isValidPhone('12345678'), isFalse);
      expect(validator.isValidPhone(null), isFalse);
    });
  });
}
