/**
 * GraphImporter — Import OSM PBF thành GraphHopper graph-cache dùng Java API.
 *
 * Tool này tạo Profile theo ĐÚNG cách Android native code dùng
 * (Profile API + Jackson.readValue + setCustomModel), đảm bảo hash trong
 * file properties KHỚP với hash mà Android native compute khi load graph.
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
import com.graphhopper.util.CustomModel;

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
        hopper.init(config);
        hopper.importOrLoad();

        System.out.println("[GraphImporter] Import completed successfully!");
        System.out.println("[GraphImporter] Profile hash in graph: " + profile.getVersion());

        hopper.close();
    }
}
