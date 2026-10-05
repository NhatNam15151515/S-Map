/**
 * GraphImporter — Import OSM PBF thành GraphHopper graph-cache dùng Java API.
 *
 * Tool này tạo Profile theo ĐÚNG cách Android native code dùng
 * (Profile API + Jackson.readValue + setCustomModel), đảm bảo hash trong
 * file properties KHỚP với hash mà Android native compute khi load graph.
 *
 * QUAN TRỌNG: Sử dụng TransportationMode.MOTORCYCLE cho CarAccessParser
 * và OSMRoadAccessParser để đường cấm ô tô (motorcar=no) vẫn cho xe máy
 * đi qua. Xem chi tiết tại implementation_plan.md.
 *
 * Usage:
 *   javac -cp graphhopper-web.jar tools/GraphImporter.java -d tools/
 *   java  -cp "graphhopper-web.jar;tools" GraphImporter \
 *         --pbf data/raw/vietnam-latest.osm.pbf \
 *         --graph-dir data/graph-cache/vietnam \
 *         --custom-model custom_model_moped.json
 */

import com.graphhopper.GraphHopper;
import com.graphhopper.GraphHopperConfig;
import com.graphhopper.config.CHProfile;
import com.graphhopper.config.Profile;
import com.graphhopper.jackson.Jackson;
import com.graphhopper.reader.osm.conditional.DateRangeParser;
import com.graphhopper.routing.ev.BooleanEncodedValue;
import com.graphhopper.routing.ev.DecimalEncodedValue;
import com.graphhopper.routing.ev.EnumEncodedValue;
import com.graphhopper.routing.ev.Roundabout;
import com.graphhopper.routing.ev.RoadAccess;
import com.graphhopper.routing.ev.VehicleAccess;
import com.graphhopper.routing.ev.VehicleSpeed;
import com.graphhopper.routing.util.TransportationMode;
import com.graphhopper.routing.util.VehicleTagParsers;
import com.graphhopper.routing.util.parsers.CarAccessParser;
import com.graphhopper.routing.util.parsers.CarAverageSpeedParser;
import com.graphhopper.routing.util.parsers.DefaultTagParserFactory;
import com.graphhopper.routing.util.parsers.OSMRoadAccessParser;
import com.graphhopper.util.CustomModel;
import com.graphhopper.util.PMap;

import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.List;

public class GraphImporter {

    public static void main(String[] args) throws Exception {
        String pbfPath = null;
        String graphDir = null;
        String customModelPath = null;

        // Parse arguments
        for (int i = 0; i < args.length; i++) {
            switch (args[i]) {
                case "--pbf":
                    pbfPath = args[++i];
                    break;
                case "--graph-dir":
                    graphDir = args[++i];
                    break;
                case "--custom-model":
                    customModelPath = args[++i];
                    break;
                default:
                    System.err.println("Unknown argument: " + args[i]);
                    System.exit(1);
            }
        }

        if (pbfPath == null || graphDir == null || customModelPath == null) {
            System.err.println("Usage: GraphImporter --pbf <path> --graph-dir <path> --custom-model <path>");
            System.exit(1);
        }

        // Validate input files
        if (!new File(pbfPath).exists()) {
            System.err.println("[ERROR] PBF file not found: " + pbfPath);
            System.exit(1);
        }
        if (!new File(customModelPath).exists()) {
            System.err.println("[ERROR] Custom model file not found: " + customModelPath);
            System.exit(1);
        }

        // Read custom model JSON — dùng Jackson.newObjectMapper() giống
        // DefaultGraphHopperEngineFactory.kt trên Android
        String customModelJson = Files.readString(Path.of(customModelPath));
        CustomModel customModel = Jackson.newObjectMapper()
                .readValue(customModelJson, CustomModel.class);

        // Tạo Profile theo ĐÚNG cách Android native code dùng
        // (xem DefaultGraphHopperEngineFactory.kt lines 148-156)
        Profile profile = new Profile("moped_vn")
                .setVehicle("car")
                .setWeighting("custom")
                .setCustomModel(customModel);

        System.out.println("[GraphImporter] Profile: " + profile.getName());
        System.out.println("[GraphImporter] Profile version (hash): " + profile.getVersion());

        // Tạo GraphHopperConfig — chỉ dùng Java API, không dùng YAML
        GraphHopperConfig config = new GraphHopperConfig();
        config.putObject("datareader.file", pbfPath);
        config.putObject("graph.location", graphDir);
        config.putObject("import.osm.ignored_highways", "");
        config.setProfiles(List.of(profile));
        config.setCHProfiles(List.of(new CHProfile("moped_vn")));

        // Import graph
        System.out.println("[GraphImporter] Importing PBF: " + pbfPath);
        System.out.println("[GraphImporter] Graph dir: " + graphDir);

        GraphHopper hopper = new GraphHopper();

        // ============================================================
        // FIX XE MÁY: Override factories để dùng TransportationMode.MOTORCYCLE
        // ============================================================
        // Vấn đề: Mặc định GraphHopper dùng CarAccessParser(TransportationMode.CAR)
        //   → đường cấm ô tô (motorcar=no) bị car_access=false → CH chặn cứng
        //   → xe máy không đi qua được dù CustomModel không cấm.
        //
        // Fix: Dùng CarAccessParser(TransportationMode.MOTORCYCLE) thay thế.
        //   → restrictions kiểm tra [motorcycle, motor_vehicle, vehicle, access]
        //   → đường motorcar=no nhưng KHÔNG cấm motorcycle → car_access=true
        //   → đường motorcycle=no → car_access=false (đúng ý đồ)
        // ============================================================

        // 1. VehicleTagParserFactory: CarAccessParser dùng MOTORCYCLE mode
        hopper.setVehicleTagParserFactory((lookup, name, pmap) -> {
            BooleanEncodedValue accessEnc = lookup.getBooleanEncodedValue(
                    VehicleAccess.key(name));
            BooleanEncodedValue roundaboutEnc = lookup.getBooleanEncodedValue("roundabout");

            // CarAccessParser với MOTORCYCLE mode — cho phép đường cấm ô tô
            CarAccessParser accessParser = new CarAccessParser(
                    accessEnc, roundaboutEnc, pmap, TransportationMode.MOTORCYCLE);
            DateRangeParser dateRangeParser = (DateRangeParser) pmap.getObject(
                    "date_range_parser", new DateRangeParser());
            accessParser.init(dateRangeParser);

            // Speed parser giữ nguyên logic car (CustomModel sẽ limit tốc độ xe máy)
            CarAverageSpeedParser speedParser = new CarAverageSpeedParser(lookup, pmap);

            System.out.println("[GraphImporter] VehicleTagParser created with MOTORCYCLE mode for: " + name);
            return new VehicleTagParsers(accessParser, speedParser, null);
        });

        // 2. TagParserFactory: Override road_access → MOTORCYCLE mode
        //    Nếu không override, DefaultTagParserFactory HARDCODE TransportationMode.CAR
        //    → đường motorcar=no bị road_access=NO
        //    → CustomModel rule "road_access == NO → multiply_by 0.0" chặn đường
        //    → CH bake cứng weight=0 → đường bị chặn vĩnh viễn dù car_access=true
        hopper.setTagParserFactory((lookup, tagName, properties) -> {
            if ("road_access".equals(tagName)) {
                @SuppressWarnings("unchecked")
                EnumEncodedValue<RoadAccess> roadAccessEnc = lookup.getEnumEncodedValue(
                        "road_access", RoadAccess.class);
                // Dùng MOTORCYCLE restrictions: [motorcycle, motor_vehicle, vehicle, access]
                // thay vì CAR restrictions: [motorcar, motor_vehicle, vehicle, access]
                List<String> restrictions = OSMRoadAccessParser.toOSMRestrictions(
                        TransportationMode.MOTORCYCLE);
                System.out.println("[GraphImporter] road_access parser using MOTORCYCLE restrictions: " + restrictions);
                return new OSMRoadAccessParser(roadAccessEnc, restrictions);
            }
            // Delegate tất cả encoded values khác cho factory mặc định
            return new DefaultTagParserFactory().create(lookup, tagName, properties);
        });

        hopper.init(config);
        hopper.importOrLoad();

        System.out.println("[GraphImporter] Import completed successfully!");
        System.out.println("[GraphImporter] Profile hash in graph: " + profile.getVersion());

        hopper.close();
    }
}

