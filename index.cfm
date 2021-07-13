<cfscript>
// Main request dispatcher for Keystone Gateway

// Parameterize view if query string provided
param name="url.view" default="";

// If accessing web views directly via index.cfm or root URL
if (len(trim(url.view)) > 0 || (cgi.request_method == "GET" && (cgi.path_info == "/" || cgi.path_info == "" || cgi.path_info == "/index.cfm"))) {
    targetView = len(trim(url.view)) > 0 ? trim(url.view) : "dashboard";
    
    // Whitelist valid views
    validViews = ["dashboard", "transactions", "detail", "sagas", "dlq", "pipelines", "partners"];
    if (arrayFindNoCase(validViews, targetView)) {
        try {
            include "app/web/views/#targetView#.cfm";
        } catch (any e) {
            writeOutput("Error in view: " & e.message & " " & e.detail & " " & (structKeyExists(e, "stackTrace") ? e.stackTrace : ""));
        }
        abort;
    }
}

// API and Protocol routing
requestUri = cgi.path_info ?: "";
if (len(trim(requestUri)) == 0) {
    requestUri = cgi.script_name ?: "/";
}

// Clean and normalize uri
normalizedUri = reReplace(requestUri, "^/index\.cfm", "");
if (len(trim(normalizedUri)) == 0) {
    normalizedUri = "/";
}

// Route API endpoints
apiController = new app.web.controllers.ApiController(application.kernel);

if (normalizedUri == "/api/v1/health") {
    res = apiController.getHealth();
    cfheader(statusCode = res.statusCode);
    for (h in res.headers) { cfheader(name = h, value = res.headers[h]); }
    writeOutput(res.body);
    abort;
} else if (normalizedUri == "/api/v1/parse" && cgi.request_method == "POST") {
    reqData = getHttpRequestData();
    res = apiController.parseDocument({ "body": toString(reqData.content) });
    cfheader(statusCode = res.statusCode);
    for (h in res.headers) { cfheader(name = h, value = res.headers[h]); }
    writeOutput(res.body);
    abort;
} else if (normalizedUri == "/api/v1/metrics") {
    res = apiController.getMetrics();
    cfheader(statusCode = res.statusCode);
    for (h in res.headers) { cfheader(name = h, value = res.headers[h]); }
    writeOutput(res.body);
    abort;
}

// Default fallback to dashboard view
include "app/web/views/dashboard.cfm";
</cfscript>
