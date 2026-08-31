/**
 * Tính profile hash theo cách Android native code dùng (Profile Java API),
 * để so sánh với hash mà GraphHopper CLI/YAML tạo ra.
 *
 * Compile & Run:
 *   cd data-pipeline
 *   javac -cp graphhopper-web.jar tools/ComputeProfileHash.java -d tools/
 *   java  -cp "graphhopper-web.jar;tools" ComputeProfileHash
 */

import com.graphhopper.config.Profile;
import com.graphhopper.jackson.Jackson;
import com.graphhopper.util.CustomModel;

public class ComputeProfileHash {
    public static void main(String[] args) throws Exception {
        // ---- Cách 1: Profile với custom model (giống Android native) ----
        String customModelJson = """
        {
          "priority": [
            {"if": "road_class == MOTORWAY || road_class == STEPS || road_class == FOOTWAY || road_class == PEDESTRIAN || road_class == CYCLEWAY", "multiply_by": 0.0},
            {"else_if": "road_class == TRUNK && max_speed > 60", "multiply_by": 0.0},
            {"else_if": "road_class == TRUNK", "multiply_by": 0.4},
            {"else_if": "road_class == PRIMARY", "multiply_by": 0.7},
            {"else_if": "road_class == SECONDARY", "multiply_by": 0.9},
            {"else_if": "road_class == TERTIARY || road_class == RESIDENTIAL", "multiply_by": 1.0},
            {"else_if": "road_class == LIVING_STREET", "multiply_by": 0.9},
            {"else_if": "road_class == SERVICE", "multiply_by": 0.9},
            {"else_if": "road_class == UNCLASSIFIED", "multiply_by": 0.7},
            {"else_if": "road_class == TRACK", "multiply_by": 0.3},
            {"if": "road_access == PRIVATE || road_access == NO", "multiply_by": 0.0},
            {"if": "road_access == DESTINATION || road_access == DELIVERY", "multiply_by": 0.1},
            {"if": "road_environment == FERRY", "multiply_by": 0.0},
            {"if": "road_environment == TUNNEL", "multiply_by": 0.3}
          ],
          "speed": [
            {"if": "road_class == TRUNK", "limit_to": 50},
            {"else_if": "road_class == PRIMARY", "limit_to": 40},
            {"else_if": "road_class == SECONDARY", "limit_to": 40},
            {"else_if": "road_class == TERTIARY", "limit_to": 35},
            {"else_if": "road_class == RESIDENTIAL", "limit_to": 30},
            {"else_if": "road_class == LIVING_STREET || road_class == SERVICE", "limit_to": 20},
            {"else_if": "road_class == UNCLASSIFIED", "limit_to": 25},
            {"else_if": "road_class == TRACK", "limit_to": 15}
          ],
          "distance_influence": 50
        }
        """;

        CustomModel customModel = Jackson.newObjectMapper()
                .readValue(customModelJson, CustomModel.class);

        Profile profileApi = new Profile("moped_vn")
                .setVehicle("car")
                .setWeighting("custom")
                .setCustomModel(customModel);

        System.out.println("=== Profile via Java API (same as Android) ===");
        System.out.println("toString: " + profileApi.toString());
        System.out.println("getVersion (hash): " + profileApi.getVersion());

        // ---- Cách 2: Profile rỗng (bare custom weighting, no model) ----
        Profile profileBare = new Profile("moped_vn")
                .setVehicle("car")
                .setWeighting("custom");

        System.out.println("\n=== Profile bare (custom weighting, no explicit model) ===");
        System.out.println("toString: " + profileBare.toString());
        System.out.println("getVersion (hash): " + profileBare.getVersion());
    }
}
