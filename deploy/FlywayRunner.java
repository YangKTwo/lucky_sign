import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.MigrationInfo;
import org.flywaydb.core.api.MigrationInfoService;
import org.flywaydb.core.api.output.MigrateResult;

/**
 * Standalone Flyway migration runner.
 * 
 * Aligns with Spring Boot Flyway configuration:
 * - baselineOnMigrate: true
 * - baselineVersion: '0'
 * 
 * Usage:
 *   java -cp "flyway-core.jar:flyway-mysql.jar:mysql-connector-j.jar:." \
 *        FlywayRunner <command> <url> <user> <password> <locations>
 * 
 * Commands:
 *   migrate  - Run pending migrations
 *   info     - Show migration status
 *   validate - Validate applied migrations
 *   repair   - Repair schema history (use with caution)
 * 
 * Exit codes:
 *   0 - Success
 *   1 - Invalid arguments
 *   2 - Migration/validation failed
 */
public class FlywayRunner {
    
    private static final String BASELINE_VERSION = "0";
    
    public static void main(String[] args) {
        if (args.length < 4) {
            printUsage();
            System.exit(1);
        }
        
        String command = args[0];
        String url = args[1];
        String user = args[2];
        String password = args[3];
        String locations = args.length > 4 ? args[4] : "filesystem:./";
        
        try {
            Flyway flyway = Flyway.configure()
                .dataSource(url, user, password)
                .locations(locations)
                .baselineOnMigrate(true)
                .baselineVersion(BASELINE_VERSION)
                .load();
            
            switch (command.toLowerCase()) {
                case "migrate":
                    runMigrate(flyway);
                    break;
                case "info":
                    runInfo(flyway);
                    break;
                case "validate":
                    runValidate(flyway);
                    break;
                case "repair":
                    runRepair(flyway);
                    break;
                default:
                    System.err.println("Unknown command: " + command);
                    printUsage();
                    System.exit(1);
            }
            
            System.exit(0);
            
        } catch (Exception e) {
            System.err.println("Flyway " + command + " failed: " + e.getMessage());
            e.printStackTrace();
            System.exit(2);
        }
    }
    
    private static void runMigrate(Flyway flyway) {
        System.out.println("Running Flyway migrate...");
        MigrateResult result = flyway.migrate();
        
        System.out.println("Migrations applied: " + result.migrationsExecuted);
        if (result.migrationsExecuted > 0) {
            System.out.println("Target version: " + result.targetSchemaVersion);
        }
        
        if (!result.success) {
            throw new RuntimeException("Migration failed");
        }
        
        System.out.println("Migration completed successfully");
    }
    
    private static void runInfo(Flyway flyway) {
        System.out.println("Flyway migration info:");
        MigrationInfoService info = flyway.info();
        
        System.out.printf("%-10s %-40s %-10s %-20s%n", 
            "Version", "Description", "State", "Installed On");
        System.out.println("-".repeat(82));
        
        for (MigrationInfo mi : info.all()) {
            String installedOn = mi.getInstalledOn() != null 
                ? mi.getInstalledOn().toString() 
                : "";
            System.out.printf("%-10s %-40s %-10s %-20s%n",
                mi.getVersion() != null ? mi.getVersion().toString() : "",
                truncate(mi.getDescription(), 40),
                mi.getState().toString(),
                installedOn);
        }
        
        MigrationInfo current = info.current();
        if (current != null) {
            System.out.println("\nCurrent version: " + current.getVersion());
        }
        
        MigrationInfo[] pending = info.pending();
        if (pending.length > 0) {
            System.out.println("Pending migrations: " + pending.length);
        }
    }
    
    private static void runValidate(Flyway flyway) {
        System.out.println("Running Flyway validate...");
        flyway.validate();
        System.out.println("Validation successful");
    }
    
    private static void runRepair(Flyway flyway) {
        System.out.println("Running Flyway repair...");
        System.out.println("WARNING: This will update checksums and remove failed entries.");
        flyway.repair();
        System.out.println("Repair completed");
    }
    
    private static void printUsage() {
        System.err.println("Usage: FlywayRunner <command> <url> <user> <password> [locations]");
        System.err.println();
        System.err.println("Commands:");
        System.err.println("  migrate   Run pending migrations");
        System.err.println("  info      Show migration status");
        System.err.println("  validate  Validate applied migrations");
        System.err.println("  repair    Repair schema history");
        System.err.println();
        System.err.println("Example:");
        System.err.println("  FlywayRunner migrate jdbc:mysql://localhost:3306/mydb root secret filesystem:./migrations");
    }
    
    private static String truncate(String s, int maxLen) {
        if (s == null) return "";
        return s.length() <= maxLen ? s : s.substring(0, maxLen - 3) + "...";
    }
}
