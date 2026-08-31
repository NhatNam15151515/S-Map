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

public class DebugGraphLoad {
    public static void main(String[] args) {
        try {
            String graphDir = "data/graph-cache/vietnam";
            System.out.println("Debugging GraphHopper.load() on: " + graphDir);

            String customModelJson = Files.readString(new File("custom_model_moped.json").exists() ? Path.of("custom_model_moped.json") : Path.of("data-pipeline/custom_model_moped.json"));
            CustomModel customModel = Jackson.newObjectMapper()
                    .readValue(customModelJson, CustomModel.class);

            GraphHopperConfig config = new GraphHopperConfig();
            config.putObject("graph.dataaccess", "RAM_STORE");
            config.putObject("graph.location", graphDir);
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
            
            System.out.println("Calling hopper.loadExisting()...");
            boolean loaded = hopper.loadExisting();
            System.out.println("loadExisting result: " + loaded);

            if (!loaded) {
                System.out.println("Calling hopper.load()...");
                loaded = hopper.load();
                System.out.println("load result: " + loaded);
            }

            if (loaded) {
                System.out.println("Loaded successfully! Nodes: " + hopper.getBaseGraph().getNodes());
                hopper.close();
            }
        } catch (Throwable t) {
            System.err.println("Exception:");
            t.printStackTrace();
        }
    }
}
