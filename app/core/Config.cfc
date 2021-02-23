component {

    property name="rootDir" type="string";
    property name="settings" type="struct";

    /**
     * Constructor for Config.
     *
     * @rootDir Base directory of application
     */
    public any function init(required string rootDir) {
        variables.rootDir = arguments.rootDir;
        variables.settings = {};
        return this;
    }

    /**
     * Loads base configuration, environment overrides, and file configuration.
     */
    public void function load() {
        // Step 1: Default configuration baseline
        var defaults = {
            "node": {
                "id": 1,
                "environment": "development",
                "datacenter": "us-east-1"
            },
            "server": {
                "httpPort": 8088,
                "sslPort": 8443,
                "host": "0.0.0.0",
                "workers": 16
            },
            "security": {
                "masterSecret": "keystone-production-vault-secret-key-salt-32b",
                "tokenTtlSeconds": 86400,
                "requireAuth": true,
                "enableAs2Encryption": true,
                "auditLedgerEnabled": true
            },
            "concurrency": {
                "poolSize": 32,
                "queueCapacity": 10000,
                "keepAliveSeconds": 60
            },
            "cache": {
                "maxEntries": 50000,
                "ttlSeconds": 3600
            },
            "storage": {
                "baseDir": variables.rootDir & "storage",
                "journalDir": variables.rootDir & "storage/journal",
                "auditDir": variables.rootDir & "storage/audit",
                "dlqDir": variables.rootDir & "storage/dlq",
                "outboxDir": variables.rootDir & "storage/outbox",
                "partnersDir": variables.rootDir & "storage/partners"
            },
            "logging": {
                "level": "INFO",
                "console": true,
                "file": true,
                "maxFileSizeMb": 50,
                "retentionDays": 14
            },
            "telemetry": {
                "enabled": true,
                "exportPrometheus": true,
                "sampleRate": 1.0
            }
        };

        variables.settings = duplicate(defaults);

        // Step 2: Attempt to load configuration file if present
        var configFile = variables.rootDir & "config/keystone.json";
        if (fileExists(configFile)) {
            try {
                var fileContent = fileRead(configFile, "utf-8");
                var parsedJson = deserializeJson(fileContent);
                mergeStructs(variables.settings, parsedJson);
            } catch (any e) {
                systemOutput("[WARN] Failed to load config/keystone.json: " & e.message, true);
            }
        }

        // Step 3: Overlay environment variables
        overlayEnvironmentVariables();

        // Ensure storage directories exist
        ensureStorageDirectories();
    }

    /**
     * Resolves dot-delimited configuration key.
     *
     * @key Dot-separated key path (e.g. 'security.masterSecret')
     * @defaultValue Fallback value if key is not defined
     */
    public any function get(required string key, any defaultValue = "") {
        var parts = listToArray(arguments.key, ".");
        var current = variables.settings;

        for (var i = 1; i <= arrayLen(parts); i++) {
            var part = parts[i];
            if (isStruct(current) && structKeyExists(current, part)) {
                current = current[part];
            } else {
                return arguments.defaultValue;
            }
        }

        return current;
    }

    public string function getString(required string key, string defaultValue = "") {
        var val = get(arguments.key, arguments.defaultValue);
        return toString(val);
    }

    public numeric function getInt(required string key, numeric defaultValue = 0) {
        var val = get(arguments.key, arguments.defaultValue);
        return isNumeric(val) ? val : arguments.defaultValue;
    }

    public boolean function getBool(required string key, boolean defaultValue = false) {
        var val = get(arguments.key, arguments.defaultValue);
        return isBoolean(val) ? val : arguments.defaultValue;
    }

    public struct function getStruct(required string key) {
        var val = get(arguments.key, {});
        return isStruct(val) ? val : {};
    }

    public array function getArray(required string key) {
        var val = get(arguments.key, []);
        return isArray(val) ? val : [];
    }

    /**
     * Sets a configuration value programmatically at runtime.
     */
    public void function set(required string key, required any value) {
        var parts = listToArray(arguments.key, ".");
        var current = variables.settings;

        for (var i = 1; i < arrayLen(parts); i++) {
            var part = parts[i];
            if (!structKeyExists(current, part) || !isStruct(current[part])) {
                current[part] = {};
            }
            current = current[part];
        }

        current[parts[arrayLen(parts)]] = arguments.value;
    }

    public struct function getAll() {
        return duplicate(variables.settings);
    }

    /**
     * Deep recursive merge of two structs.
     */
    private void function mergeStructs(required struct target, required struct source) {
        for (var key in arguments.source) {
            if (structKeyExists(arguments.target, key) && isStruct(arguments.target[key]) && isStruct(arguments.source[key])) {
                mergeStructs(arguments.target[key], arguments.source[key]);
            } else {
                arguments.target[key] = arguments.source[key];
            }
        }
    }

    /**
     * Inspects system environment variables matching KEYSTONE_* and overlays them.
     */
    private void function overlayEnvironmentVariables() {
        var system = createObject("java", "java.lang.System");
        var envMap = system.getenv();

        for (var envKey in envMap) {
            if (findNoCase("KEYSTONE_", envKey) == 1) {
                var stripped = right(envKey, len(envKey) - 9);
                var configKey = lcase(replace(stripped, "_", ".", "all"));
                var envVal = envMap[envKey];

                if (isBoolean(envVal)) {
                    set(configKey, javaCast("boolean", envVal));
                } else if (isNumeric(envVal)) {
                    set(configKey, javaCast("int", envVal));
                } else {
                    set(configKey, envVal);
                }
            }
        }
    }

    /**
     * Creates required disk directories if missing.
     */
    private void function ensureStorageDirectories() {
        var baseDir = variables.rootDir & "storage";
        var dirs = [
            baseDir,
            baseDir & "/journal",
            baseDir & "/audit",
            baseDir & "/dlq",
            baseDir & "/outbox",
            baseDir & "/partners",
            baseDir & "/certs",
            baseDir & "/locks",
            variables.rootDir & "logs"
        ];

        for (var dir in dirs) {
            if (!directoryExists(dir)) {
                directoryCreate(dir);
            }
        }
    }
}
