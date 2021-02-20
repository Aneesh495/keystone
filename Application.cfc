component {

    // Application identity and lifecycle settings
    this.name = "KeystoneEnterpriseGateway";
    this.applicationTimeout = createTimeSpan(1, 0, 0, 0); // 1 day
    this.sessionManagement = true;
    this.sessionTimeout = createTimeSpan(0, 2, 0, 0);    // 2 hours
    this.setClientCookies = true;
    this.scriptProtect = "all";

    // Custom tag and component path mappings
    this.rootDir = getDirectoryFromPath(getCurrentTemplatePath());
    this.mappings["/app"] = this.rootDir & "app";
    this.mappings["/tests"] = this.rootDir & "tests";
    this.mappings["/sample_data"] = this.rootDir & "sample_data";

    // Java class loading integration if required
    this.javaSettings = {
        loadPaths: [this.rootDir & "lib"],
        reloadOnChange: false,
        watchInterval: 60
    };

    /**
     * Triggered on application boot.
     * Initializes the Keystone runtime kernel and subsystem registry.
     */
    public boolean function onApplicationStart() {
        try {
            // Instantiate the central Keystone kernel
            application.kernel = new app.core.Kernel(rootDir = this.rootDir);
            application.kernel.bootstrap();
            application.bootstrappedAt = now();
            return true;
        } catch (any e) {
            systemOutput("[FATAL] Failed to bootstrap Keystone application kernel: " & e.message, true);
            if (structKeyExists(e, "stackTrace")) {
                systemOutput(e.stackTrace, true);
            }
            return false;
        }
    }

    /**
     * Triggered before each HTTP request execution.
     */
    public boolean function onRequestStart(required string targetPage) {
        // Support manual kernel reload via authorization token or debug flag
        if (structKeyExists(url, "reload") && url.reload == "true") {
            onApplicationStart();
        }

        // Ensure kernel is active
        if (!structKeyExists(application, "kernel")) {
            onApplicationStart();
        }

        // Set global security and tracing headers
        cfheader(name = "X-Content-Type-Options", value = "nosniff");
        cfheader(name = "X-Frame-Options", value = "DENY");
        cfheader(name = "X-XSS-Protection", value = "1; mode=block");
        cfheader(name = "X-Engine-Identity", value = "Keystone-CFML/1.0");

        return true;
    }

    /**
     * Triggered on unhandled application exceptions.
     */
    public void function onError(required any exception, required string eventName) {
        var errorPayload = {
            "status": "error",
            "event": arguments.eventName,
            "message": arguments.exception.message,
            "detail": structKeyExists(arguments.exception, "detail") ? arguments.exception.detail : "",
            "timestamp": dateTimeFormat(now(), "yyyy-mm-dd'T'HH:nn:ss.l'Z'")
        };

        if (structKeyExists(application, "kernel")) {
            try {
                application.kernel.getLogger().error("Unhandled request exception in " & arguments.eventName, errorPayload);
            } catch (any logError) {
                systemOutput("[ERROR] Failed to log unhandled exception: " & logError.message, true);
            }
        }

        // If client accepts JSON or request is under /api, return structured JSON error
        var acceptHeader = cgi.http_accept ?: "";
        var requestUri = cgi.request_uri ?: "";
        if (findNoCase("application/json", acceptHeader) || findNoCase("/api/", requestUri)) {
            cfheader(statusCode = 500, statusText = "Internal Server Error");
            cfcontent(type = "application/json", reset = true);
            writeOutput(serializeJson(errorPayload));
            return;
        }

        // Default human-readable error template
        cfheader(statusCode = 500, statusText = "Internal Server Error");
        cfcontent(type = "text/html", reset = true);
        writeOutput("<html><head><title>500 Internal Server Error</title></head>");
        writeOutput("<body style='font-family: monospace; background: #0f172a; color: #f8fafc; padding: 40px;'>");
        writeOutput("<h1 style='color: #ef4444;'>Keystone Gateway Error</h1>");
        writeOutput("<p><strong>Event:</strong> " & htmlEditFormat(arguments.eventName) & "</p>");
        writeOutput("<p><strong>Message:</strong> " & htmlEditFormat(arguments.exception.message) & "</p>");
        writeOutput("<pre style='background: #1e293b; padding: 20px; border-radius: 6px; overflow-x: auto;'>");
        writeOutput(htmlEditFormat(arguments.exception.stackTrace ?: ""));
        writeOutput("</pre></body></html>");
    }

    /**
     * Triggered on application shutdown.
     */
    public void function onApplicationStop() {
        if (structKeyExists(application, "kernel")) {
            application.kernel.shutdown();
        }
    }
}
