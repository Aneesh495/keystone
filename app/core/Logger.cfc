component {

    property name="config" type="any";
    property name="logDir" type="string";
    property name="logFile" type="string";
    property name="currentLevelInt" type="numeric";
    property name="enableConsole" type="boolean";
    property name="enableFile" type="boolean";

    // Numerical level mapping
    variables.LEVELS = {
        "TRACE": 10,
        "DEBUG": 20,
        "INFO": 30,
        "WARN": 40,
        "ERROR": 50,
        "FATAL": 60
    };

    /**
     * Constructor for structured JSON logger.
     */
    public any function init(required any config, required string logDir) {
        variables.config = arguments.config;
        variables.logDir = arguments.logDir;
        variables.logFile = variables.logDir & "/keystone.log";

        if (!directoryExists(variables.logDir)) {
            directoryCreate(variables.logDir);
        }

        var configuredLevel = ucase(variables.config.getString("logging.level", "INFO"));
        variables.currentLevelInt = structKeyExists(variables.LEVELS, configuredLevel) ? variables.LEVELS[configuredLevel] : 30;
        variables.enableConsole = variables.config.getBool("logging.console", true);
        variables.enableFile = variables.config.getBool("logging.file", true);

        return this;
    }

    public void function trace(required string message, struct context = {}) {
        logMessage("TRACE", arguments.message, arguments.context);
    }

    public void function debug(required string message, struct context = {}) {
        logMessage("DEBUG", arguments.message, arguments.context);
    }

    public void function info(required string message, struct context = {}) {
        logMessage("INFO", arguments.message, arguments.context);
    }

    public void function warn(required string message, struct context = {}) {
        logMessage("WARN", arguments.message, arguments.context);
    }

    public void function error(required string message, struct context = {}) {
        logMessage("ERROR", arguments.message, arguments.context);
    }

    public void function fatal(required string message, struct context = {}) {
        logMessage("FATAL", arguments.message, arguments.context);
    }

    /**
     * Internal method to format and emit structured log entries.
     */
    private void function logMessage(required string level, required string message, required struct context) {
        var levelInt = variables.LEVELS[arguments.level];
        if (levelInt < variables.currentLevelInt) {
            return;
        }

        var threadName = createObject("java", "java.lang.Thread").currentThread().getName();
        var record = {
            "timestamp": dateTimeFormat(now(), "yyyy-mm-dd'T'HH:nn:ss.l'Z'"),
            "level": arguments.level,
            "thread": threadName,
            "message": arguments.message,
            "context": arguments.context
        };

        // Extract traceparent or correlation if present in request scope
        if (structKeyExists(request, "correlationId")) {
            record["correlationId"] = request.correlationId;
        }
        if (structKeyExists(request, "traceId")) {
            record["traceId"] = request.traceId;
        }

        var jsonRecord = serializeJson(record);

        // File output
        if (variables.enableFile) {
            lock name="keystone_log_lock" type="exclusive" timeout="5" {
                try {
                    fileAppend(variables.logFile, jsonRecord & chr(10), "utf-8");
                } catch (any e) {
                    systemOutput("[LOG_ERROR] Could not write to log file: " & e.message, true);
                }
            }
        }

        // Console output
        if (variables.enableConsole) {
            var colorPrefix = "";
            var colorReset = chr(27) & "[0m";
            switch (arguments.level) {
                case "TRACE": colorPrefix = chr(27) & "[90m"; break;
                case "DEBUG": colorPrefix = chr(27) & "[36m"; break;
                case "INFO":  colorPrefix = chr(27) & "[32m"; break;
                case "WARN":  colorPrefix = chr(27) & "[33m"; break;
                case "ERROR": colorPrefix = chr(27) & "[31m"; break;
                case "FATAL": colorPrefix = chr(27) & "[41;97m"; break;
            }

            var line = colorPrefix & "[" & record.timestamp & "] [" & ucase(arguments.level) & "] [" & threadName & "] " & arguments.message & colorReset;
            if (structCount(arguments.context) > 0) {
                line &= " " & serializeJson(arguments.context);
            }
            systemOutput(line, true);
        }
    }
}
