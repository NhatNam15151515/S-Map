import com.graphhopper.GraphHopper;
import com.graphhopper.GraphHopperConfig;
import com.graphhopper.config.CHProfile;
import com.graphhopper.config.Profile;
import com.graphhopper.jackson.Jackson;
import com.graphhopper.util.CustomModel;

import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

public class TestLoadGraph {
    public static void main(String[] args) {
        try {
            String graphDir = args.length > 0 ? args[0] : "data-pipeline/data/graph-cache/vietnam";
            System.out.println("Testing GraphHopper.load() on: " + graphDir);

            String customModelJson = Files.readString(new File("custom_model_moped.json").exists() ? Path.of("custom_model_moped.json") : Path.of("data-pipeline/custom_model_moped.json"));
            CustomModel customModel = Jackson.newObjectMapper()
                    .readValue(customModelJson, CustomModel.class);

            File dir = new File(graphDir);
            System.out.println("Dir exists: " + dir.exists() + ", absolute: " + dir.getAbsolutePath());
            System.out.println("Files in dir: " + java.util.Arrays.toString(dir.list()));

            GraphHopperConfig config = new GraphHopperConfig();
            config.putObject("graph.dataaccess", "RAM_STORE");
            config.putObject("graph.location", dir.getAbsolutePath());
            config.putObject("datareader.file", "");
            config.putObject("import.osm.ignored_highways", "");
            config.putObject("graph.encoded_values", "road_class,road_environment,road_access,max_speed");
            config.setProfiles(List.of(
                new Profile("moped_vn")
                    .setVehicle("car")
                    .setWeighting("custom")
                    .setCustomModel(customModel)
            ));
            config.setCHProfiles(List.of(new CHProfile("moped_vn")));

            GraphHopper hopper = new GraphHopper();
            hopper.init(config);
            boolean loaded = hopper.load();
            System.out.println("Loaded successfully? " + loaded);
            if (loaded) {
                System.out.println("Nodes count: " + hopper.getBaseGraph().getNodes());
                hopper.close();
            }
        } catch (Throwable t) {
            System.err.println("Exception during load:");
            t.printStackTrace();
        }
    }
}
