/**
 * TestMotorcycleRouting — Kiểm tra toàn bộ pipeline xử lý quyền truy cập
 * xe máy trong GraphHopper sau khi override factory.
 *
 * Test mô phỏng cách GraphImporter đăng ký custom factories, sau đó
 * kiểm tra kết quả trên các đoạn đường OSM giả lập:
 * - motorcar=no (cấm ô tô, xe máy được đi)
 * - motorcycle=no (cấm xe máy)
 * - motor_vehicle=no (cấm toàn bộ xe cơ giới)
 * - oneway=yes (đường 1 chiều)
 * - highway=footway (đường đi bộ)
 * - road_access encoded value đúng theo MOTORCYCLE mode
 *
 * Usage:
 *   javac -cp graphhopper-web.jar tools/TestMotorcycleRouting.java -d tools/
 *   java  -cp "graphhopper-web.jar;tools" TestMotorcycleRouting
 */

import com.graphhopper.reader.ReaderWay;
import com.graphhopper.reader.osm.conditional.DateRangeParser;
import com.graphhopper.routing.ev.*;
import com.graphhopper.routing.util.EncodingManager;
import com.graphhopper.routing.util.TransportationMode;
import com.graphhopper.routing.util.parsers.CarAccessParser;
import com.graphhopper.routing.util.parsers.OSMRoadAccessParser;

import java.util.List;

public class TestMotorcycleRouting {

    private static int passed = 0;
    private static int failed = 0;

    public static void main(String[] args) {
        System.out.println("=================================================================");
        System.out.println("  TestMotorcycleRouting — Kiểm tra True Motorcycle Routing Logic  ");
        System.out.println("=================================================================\n");

        // Tạo encoded values
        BooleanEncodedValue accessEnc = VehicleAccess.create("car");
        BooleanEncodedValue roundaboutEnc = Roundabout.create();
        DecimalEncodedValue speedEnc = VehicleSpeed.create("car", 7, 2.0, true);
        EnumEncodedValue<RoadAccess> roadAccessEnc = RoadAccess.create();

        EncodingManager em = new EncodingManager.Builder()
                .add(accessEnc)
                .add(roundaboutEnc)
                .add(speedEnc)
                .add(roadAccessEnc)
                .build();

        // ===== Parser cũ (CAR mode — bug hiện tại) =====
        CarAccessParser oldAccessParser = new CarAccessParser(
                accessEnc, roundaboutEnc, new com.graphhopper.util.PMap(), TransportationMode.CAR);
        oldAccessParser.init(new DateRangeParser());

        List<String> oldRoadAccessRestrictions = OSMRoadAccessParser.toOSMRestrictions(TransportationMode.CAR);
        OSMRoadAccessParser oldRoadAccessParser = new OSMRoadAccessParser(roadAccessEnc, oldRoadAccessRestrictions);

        // ===== Parser mới (MOTORCYCLE mode — fix) =====
        CarAccessParser newAccessParser = new CarAccessParser(
                accessEnc, roundaboutEnc, new com.graphhopper.util.PMap(), TransportationMode.MOTORCYCLE);
        newAccessParser.init(new DateRangeParser());

        List<String> newRoadAccessRestrictions = OSMRoadAccessParser.toOSMRestrictions(TransportationMode.MOTORCYCLE);
        OSMRoadAccessParser newRoadAccessParser = new OSMRoadAccessParser(roadAccessEnc, newRoadAccessRestrictions);

        // ============================================
        //  TEST CASES
        // ============================================

        System.out.println("--- Test 1: motorcar=no (biển P.103a cấm ô tô, xe máy được đi) ---");
        {
            ReaderWay way = new ReaderWay(1);
            way.setTag("highway", "residential");
            way.setTag("motorcar", "no");

            // Old (CAR mode)
            ArrayEdgeIntAccess eaOld = new ArrayEdgeIntAccess(em.getIntsForFlags());
            oldAccessParser.handleWayTags(0, eaOld, way, null);
            boolean oldAccess = accessEnc.getBool(false, 0, eaOld);

            ArrayEdgeIntAccess raOld = new ArrayEdgeIntAccess(em.getIntsForFlags());
            oldRoadAccessParser.handleWayTags(0, raOld, way, null);
            RoadAccess oldRA = roadAccessEnc.getEnum(false, 0, raOld);

            // New (MOTORCYCLE mode)
            ArrayEdgeIntAccess eaNew = new ArrayEdgeIntAccess(em.getIntsForFlags());
            newAccessParser.handleWayTags(0, eaNew, way, null);
            boolean newAccess = accessEnc.getBool(false, 0, eaNew);

            ArrayEdgeIntAccess raNew = new ArrayEdgeIntAccess(em.getIntsForFlags());
            newRoadAccessParser.handleWayTags(0, raNew, way, null);
            RoadAccess newRA = roadAccessEnc.getEnum(false, 0, raNew);

            System.out.println("  OLD (CAR):        car_access=" + oldAccess + ", road_access=" + oldRA);
            System.out.println("  NEW (MOTORCYCLE):  car_access=" + newAccess + ", road_access=" + newRA);

            assertEq("OLD car_access should be FALSE", oldAccess, false);
            assertEq("OLD road_access should be NO", oldRA, RoadAccess.NO);
            assertEq("NEW car_access should be TRUE", newAccess, true);
            assertEq("NEW road_access should be YES", newRA, RoadAccess.YES);
        }

        System.out.println("\n--- Test 2: motorcycle=no (cấm xe máy) ---");
        {
            ReaderWay way = new ReaderWay(2);
            way.setTag("highway", "residential");
            way.setTag("motorcycle", "no");

            ArrayEdgeIntAccess ea = new ArrayEdgeIntAccess(em.getIntsForFlags());
            newAccessParser.handleWayTags(0, ea, way, null);
            boolean access = accessEnc.getBool(false, 0, ea);

            ArrayEdgeIntAccess ra = new ArrayEdgeIntAccess(em.getIntsForFlags());
            newRoadAccessParser.handleWayTags(0, ra, way, null);
            RoadAccess roadAcc = roadAccessEnc.getEnum(false, 0, ra);

            System.out.println("  NEW (MOTORCYCLE): car_access=" + access + ", road_access=" + roadAcc);
            assertEq("motorcycle=no: access should be FALSE", access, false);
            assertEq("motorcycle=no: road_access should be NO", roadAcc, RoadAccess.NO);
        }

        System.out.println("\n--- Test 3: motor_vehicle=no (cấm toàn bộ xe cơ giới) ---");
        {
            ReaderWay way = new ReaderWay(3);
            way.setTag("highway", "residential");
            way.setTag("motor_vehicle", "no");

            ArrayEdgeIntAccess ea = new ArrayEdgeIntAccess(em.getIntsForFlags());
            newAccessParser.handleWayTags(0, ea, way, null);
            boolean access = accessEnc.getBool(false, 0, ea);

            ArrayEdgeIntAccess ra = new ArrayEdgeIntAccess(em.getIntsForFlags());
            newRoadAccessParser.handleWayTags(0, ra, way, null);
            RoadAccess roadAcc = roadAccessEnc.getEnum(false, 0, ra);

            System.out.println("  NEW (MOTORCYCLE): car_access=" + access + ", road_access=" + roadAcc);
            assertEq("motor_vehicle=no: access should be FALSE", access, false);
            assertEq("motor_vehicle=no: road_access should be NO", roadAcc, RoadAccess.NO);
        }

        System.out.println("\n--- Test 4: oneway=yes ---");
        {
            ReaderWay way = new ReaderWay(4);
            way.setTag("highway", "residential");
            way.setTag("oneway", "yes");

            ArrayEdgeIntAccess ea = new ArrayEdgeIntAccess(em.getIntsForFlags());
            newAccessParser.handleWayTags(0, ea, way, null);
            boolean fwd = accessEnc.getBool(false, 0, ea);
            boolean bwd = accessEnc.getBool(true, 0, ea);

            System.out.println("  NEW (MOTORCYCLE): fwd=" + fwd + ", bwd=" + bwd);
            assertEq("oneway fwd should be TRUE", fwd, true);
            assertEq("oneway bwd should be FALSE", bwd, false);
        }

        System.out.println("\n--- Test 5: highway=footway (đường đi bộ) ---");
        {
            ReaderWay way = new ReaderWay(5);
            way.setTag("highway", "footway");

            ArrayEdgeIntAccess ea = new ArrayEdgeIntAccess(em.getIntsForFlags());
            newAccessParser.handleWayTags(0, ea, way, null);
            boolean access = accessEnc.getBool(false, 0, ea);

            System.out.println("  NEW (MOTORCYCLE): car_access=" + access);
            assertEq("footway: access should be FALSE", access, false);
        }

        System.out.println("\n--- Test 6: highway=motorway (cao tốc) ---");
        {
            ReaderWay way = new ReaderWay(6);
            way.setTag("highway", "motorway");

            ArrayEdgeIntAccess ea = new ArrayEdgeIntAccess(em.getIntsForFlags());
            newAccessParser.handleWayTags(0, ea, way, null);
            boolean access = accessEnc.getBool(false, 0, ea);

            System.out.println("  NEW (MOTORCYCLE): car_access=" + access);
            System.out.println("  (Note: Access TRUE, nhưng CustomModel road_class==MOTORWAY → multiply_by 0.0 sẽ block)");
            assertEq("motorway: access should be TRUE (CustomModel handles blocking)", access, true);
        }

        System.out.println("\n--- Test 7: access=no (cấm toàn bộ) ---");
        {
            ReaderWay way = new ReaderWay(7);
            way.setTag("highway", "residential");
            way.setTag("access", "no");

            ArrayEdgeIntAccess ea = new ArrayEdgeIntAccess(em.getIntsForFlags());
            newAccessParser.handleWayTags(0, ea, way, null);
            boolean access = accessEnc.getBool(false, 0, ea);

            ArrayEdgeIntAccess ra = new ArrayEdgeIntAccess(em.getIntsForFlags());
            newRoadAccessParser.handleWayTags(0, ra, way, null);
            RoadAccess roadAcc = roadAccessEnc.getEnum(false, 0, ra);

            System.out.println("  NEW (MOTORCYCLE): car_access=" + access + ", road_access=" + roadAcc);
            assertEq("access=no: access should be FALSE", access, false);
            assertEq("access=no: road_access should be NO", roadAcc, RoadAccess.NO);
        }

        System.out.println("\n--- Test 8: road_access=private ---");
        {
            ReaderWay way = new ReaderWay(8);
            way.setTag("highway", "residential");
            way.setTag("access", "private");

            ArrayEdgeIntAccess ra = new ArrayEdgeIntAccess(em.getIntsForFlags());
            newRoadAccessParser.handleWayTags(0, ra, way, null);
            RoadAccess roadAcc = roadAccessEnc.getEnum(false, 0, ra);

            System.out.println("  NEW (MOTORCYCLE): road_access=" + roadAcc);
            assertEq("access=private: road_access should be PRIVATE", roadAcc, RoadAccess.PRIVATE);
        }

        System.out.println("\n--- Test 9: motorcar=no + motorcycle=designated ---");
        {
            ReaderWay way = new ReaderWay(9);
            way.setTag("highway", "residential");
            way.setTag("motorcar", "no");
            way.setTag("motorcycle", "designated");

            ArrayEdgeIntAccess ea = new ArrayEdgeIntAccess(em.getIntsForFlags());
            newAccessParser.handleWayTags(0, ea, way, null);
            boolean access = accessEnc.getBool(false, 0, ea);

            System.out.println("  NEW (MOTORCYCLE): car_access=" + access);
            assertEq("motorcar=no + motorcycle=designated: access should be TRUE", access, true);
        }

        // ===== TỔNG KẾT =====
        System.out.println("\n=================================================================");
        System.out.println("  KẾT QUẢ: " + passed + " PASSED, " + failed + " FAILED");
        System.out.println("=================================================================");

        if (failed > 0) {
            System.exit(1);
        }
    }

    private static <T> void assertEq(String label, T actual, T expected) {
        if (actual.equals(expected)) {
            System.out.println("  ✅ " + label);
            passed++;
        } else {
            System.out.println("  ❌ " + label + " — expected " + expected + " but got " + actual);
            failed++;
        }
    }
}
