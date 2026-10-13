#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Offline unit tests cho address_normalizer."""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import address_normalizer as AN  # noqa: E402

GAZ = AN.load_gazetteer(AN.DEFAULT_GAZETTEER, AN.DEFAULT_ALIASES)


def province_name(parsed):
    unit = GAZ.provinces.get(parsed.province_code)
    return unit.core if unit else None


def new_province(parsed):
    return GAZ.new_province_of.get(parsed.province_code)


class AddressParserTests(unittest.TestCase):
    def test_all_old_provinces_map_to_new_system(self):
        unmapped = [c for c in GAZ.provinces if c not in GAZ.new_province_of]
        self.assertEqual(unmapped, [])
        self.assertEqual(len(set(GAZ.new_province_of.values())), 34)

    def test_full_hcm_address(self):
        p = AN.parse_address("123 Lê Lợi, P. Bến Thành, Q.1, TP.HCM", "", GAZ)
        self.assertEqual(p.house_no, "123")
        self.assertEqual(p.house_no_main, 123)
        self.assertEqual(p.street, "le loi")
        self.assertEqual(province_name(p), "ho chi minh")
        self.assertEqual(GAZ.provinces[p.province_code].code, "79")
        self.assertIsNotNone(p.district_code)

    def test_city_field_used_as_province(self):
        p = AN.parse_address("176 Đường Ngô Quyền", "Cà Mau", GAZ)
        self.assertEqual(p.house_no, "176")
        self.assertEqual(p.street, "ngo quyen")
        self.assertEqual(province_name(p), "ca mau")

    def test_old_province_maps_to_new(self):
        p = AN.parse_address("Thị xã Giá Rai - Bạc Liêu", "Bac Lieu", GAZ)
        self.assertEqual(province_name(p), "bac lieu")
        self.assertEqual(new_province(p), "Tỉnh Cà Mau")
        self.assertIsNotNone(p.district_code)

    def test_district_only_infers_province(self):
        p = AN.parse_address("Đường 2/9", "Huyện Cái Nước", GAZ)
        self.assertEqual(province_name(p), "ca mau")
        self.assertEqual(p.street, "2/9")

    def test_unaccented_district_city(self):
        p = AN.parse_address("", "Rach Gia", GAZ)
        self.assertEqual(province_name(p), "kien giang")

    def test_province_suffix_without_comma(self):
        p = AN.parse_address("12 Trần Phú Thủ Dầu Một Bình Dương", "", GAZ)
        self.assertEqual(province_name(p), "binh duong")
        self.assertEqual(new_province(p), "Thành phố Hồ Chí Minh")

    def test_ambiguous_district_needs_knn(self):
        p = AN.parse_address("Ấp 3", "Huyện Châu Thành", GAZ)
        self.assertIsNone(p.province_code)
        self.assertGreater(len(p.province_candidates), 1)

        voter = AN.ProvinceGridVoter()
        tien_giang = GAZ.province_by_core["tien giang"]
        for _ in range(20):
            voter.add(10.40, 106.30, tien_giang)
        AN.resolve_with_knn(p, 10.401, 106.301, voter)
        self.assertEqual(p.province_code, tien_giang)
        self.assertEqual(p.source, "text+knn")

    def test_knn_fills_missing_admin(self):
        p = AN.parse_address("Vàm Đầm", "", GAZ)
        voter = AN.ProvinceGridVoter()
        ca_mau = GAZ.province_by_core["ca mau"]
        for _ in range(20):
            voter.add(8.95, 105.10, ca_mau)
        AN.resolve_with_knn(p, 8.951, 105.101, voter)
        self.assertEqual(p.province_code, ca_mau)
        self.assertEqual(p.source, "knn")

    def test_merged_legacy_district(self):
        p = AN.parse_address("10 Nguyễn Duy Trinh, Quận 9, TP HCM", "", GAZ)
        self.assertIsNotNone(p.district_code)
        self.assertEqual(province_name(p), "ho chi minh")

    def test_house_number_with_slash(self):
        p = AN.parse_address("45/2A Nguyễn Trãi, Quận 5", "Hồ Chí Minh", GAZ)
        self.assertEqual(p.house_no, "45/2a")
        self.assertEqual(p.house_no_main, 45)
        self.assertEqual(p.street, "nguyen trai")

    def test_ward_number_is_not_district(self):
        p = AN.parse_address("Phường 9 - Tp Cà Mau", "Cà Mau", GAZ)
        self.assertEqual(province_name(p), "ca mau")

    # --- Hồi quy từ báo cáo dry-run lần 1 ---

    def test_street_named_after_province_is_not_province(self):
        p = AN.parse_address("154 Đường Tuyên Quang", "Phan Thiết", GAZ)
        self.assertEqual(province_name(p), "binh thuan")
        self.assertEqual(p.street, "tuyen quang")

        p = AN.parse_address("3 Hòa Bình", "Quận Tân Phú", GAZ)
        self.assertEqual(province_name(p), "ho chi minh")

    def test_street_suffix_hue_is_not_province(self):
        p = AN.parse_address("8 Đường Nhân Huệ", "Quận Hà Đông", GAZ)
        self.assertEqual(province_name(p), "ha noi")

    def test_district_kind_disambiguates(self):
        for city in ("Quận Tân Phú", "Quận Bình Tân"):
            p = AN.parse_address("", city, GAZ)
            self.assertEqual(province_name(p), "ho chi minh", city)
        p = AN.parse_address("", "Quận Hoàng Mai", GAZ)
        self.assertEqual(province_name(p), "ha noi")
        p = AN.parse_address("", "Huyện Tân Phú", GAZ)
        self.assertEqual(province_name(p), "dong nai")

    def test_accents_disambiguate(self):
        p = AN.parse_address("", "Huyện Thanh Trì", GAZ)
        self.assertEqual(province_name(p), "ha noi")
        p = AN.parse_address("Xã Thạnh Hóa", "Xã Thạnh Hóa", GAZ)
        self.assertNotEqual(province_name(p), "thanh hoa")

    def test_hyphenated_city(self):
        p = AN.parse_address("", "Phan Rang-Tháp Chàm", GAZ)
        self.assertEqual(province_name(p), "ninh thuan")

    def test_admin_prefix_without_comma(self):
        p = AN.parse_address(
            "53 phan văn năm phường phú thạnh quận tân phú", "", GAZ
        )
        self.assertEqual(province_name(p), "ho chi minh")
        self.assertEqual(p.house_no, "53")
        self.assertEqual(p.street, "phan van nam")

    def test_street_name_containing_quan_is_not_split(self):
        p = AN.parse_address("10 Phố Quán Thánh", "Quận Ba Đình", GAZ)
        self.assertEqual(p.street, "quan thanh")

    def test_house_number_in_separate_segment(self):
        p = AN.parse_address("9, Đường Điện Biên Phủ", "Buôn Ma Thuột", GAZ)
        self.assertEqual(p.house_no, "9")
        self.assertEqual(p.street, "dien bien phu")
        self.assertEqual(province_name(p), "dak lak")

    def test_address_province_beats_wrong_city(self):
        p = AN.parse_address("06 Mỹ Khê 6, phường An Hải, TP Đà Nẵng", "Quận 10", GAZ)
        self.assertEqual(province_name(p), "da nang")

    def test_city_district_beats_unprefixed_address_name(self):
        p = AN.parse_address("vĩnh lộc", "Huyện Bình Chánh", GAZ)
        self.assertEqual(province_name(p), "ho chi minh")

    def test_parenthetical_note_removed(self):
        p = AN.parse_address(
            "Đường Trần Hưng Đạo (đối diện Trường Cấp 2 - Tràm Chim)", "Huyện Tam Nông", GAZ
        )
        self.assertEqual(p.street, "tran hung dao")


if __name__ == "__main__":
    unittest.main()
