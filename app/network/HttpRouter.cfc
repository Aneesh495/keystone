/**
 * Keystone B2B Transaction Mesh - High-Throughput HTTP Router
 *
 * Dispatches inbound HTTP requests with parameterized URI parsing, wildcard matching,
 * method filtering, and chained middleware interceptors.
 */
component {

    property name="routes" type="array";
    property name="globalMiddlewares" type="array";
    property name="notFoundHandler" type="any";
    property name="methodNotAllowedHandler" type="any";
    property name="kernel" type="any";
    property name="logger" type="any";

    /**
     * Initializes the HttpRouter instance.
     */
    public any function init(any kernel = "", any logger = "") {
        variables.routes = [];
        variables.globalMiddlewares = [];
        variables.notFoundHandler = "";
        variables.methodNotAllowedHandler = "";
        variables.kernel = arguments.kernel;
        variables.logger = arguments.logger;

        return this;
    }

    /**
     * Registers default API gateway routes.
     */
    public any function registerRoutes() {
        var api = new app.web.controllers.ApiController(variables.kernel);
        get("/api/v1/health", function(ctx) { return api.getHealth(ctx); });
        post("/api/v1/parse", function(ctx) { return api.parseDocument(ctx); });
        get("/api/v1/metrics", function(ctx) { return api.getMetrics(ctx); });
        return this;
    }

    /**
     * Adds a global middleware interceptor.
     */
    public any function use(required any middleware) {
        arrayAppend(variables.globalMiddlewares, arguments.middleware);
        return this;
    }

    /**
     * Registers a route for any HTTP method.
     */
    public any function any(required string pattern, required any handler, array middlewares = []) {
        return addRoute("*", arguments.pattern, arguments.handler, arguments.middlewares);
    }

    /**
     * Registers a GET route.
     */
    public any function get(required string pattern, required any handler, array middlewares = []) {
        return addRoute("GET", arguments.pattern, arguments.handler, arguments.middlewares);
    }

    /**
     * Registers a POST route.
     */
    public any function post(required string pattern, required any handler, array middlewares = []) {
        return addRoute("POST", arguments.pattern, arguments.handler, arguments.middlewares);
    }

    /**
     * Registers a PUT route.
     */
    public any function put(required string pattern, required any handler, array middlewares = []) {
        return addRoute("PUT", arguments.pattern, arguments.handler, arguments.middlewares);
    }

    /**
     * Registers a DELETE route.
     */
    public any function delete(required string pattern, required any handler, array middlewares = []) {
        return addRoute("DELETE", arguments.pattern, arguments.handler, arguments.middlewares);
    }

    /**
     * Registers a route mapping.
     */
    public any function addRoute(
        required string method,
        required string pattern,
        required any handler,
        array middlewares = []
    ) {
        var paramNames = [];
        var regexPattern = compilePattern(arguments.pattern, paramNames);

        arrayAppend(variables.routes, {
            "method": uCase(trim(arguments.method)),
            "pattern": arguments.pattern,
            "regex": regexPattern,
            "paramNames": paramNames,
            "handler": arguments.handler,
            "middlewares": arguments.middlewares
        });

        return this;
    }

    /**
     * Compiles URI pattern into regular expression, extracting parameter names.
     */
    private string function compilePattern(required string pattern, required array paramNames) {
        var clean = trim(arguments.pattern);
        if (!len(clean)) {
            return "^/?$";
        }

        // Split pattern by slash
        var segments = listToArray(clean, "/");
        var regexSegments = [];

        for (var seg in segments) {
            if (left(seg, 1) == ":") {
                // Named parameter
                var pName = mid(seg, 2, len(seg) - 1);
                arrayAppend(arguments.paramNames, pName);
                arrayAppend(regexSegments, "([^/]+)");
            } else if (seg == "*") {
                // Wildcard match
                arrayAppend(arguments.paramNames, "_wildcard");
                arrayAppend(regexSegments, "(.*)");
            } else {
                // Literal match (escaped)
                arrayAppend(regexSegments, rereplace(seg, "([\.\?\+\*\^\$\(\)\[\]\{\}\\\/])", "\\\1", "all"));
            }
        }

        return "^/" & arrayToList(regexSegments, "/") & "/?$";
    }

    /**
     * Matches an incoming HTTP request against registered routes.
     */
    public struct function match(required string method, required string uri) {
        var reqMethod = uCase(trim(arguments.method));
        var cleanUri = "/" & listChangeDelims(trim(arguments.uri), "/", "/");
        if (cleanUri == "//") {
            cleanUri = "/";
        }

        var methodMismatchFound = false;

        for (var r in variables.routes) {
            var matches = reMatchGroups(cleanUri, r.regex);
            if (matches.matched) {
                if (r.method == "*" || r.method == reqMethod) {
                    var params = {};
                    var pCount = arrayLen(r.paramNames);
                    for (var i = 1; i <= pCount; i++) {
                        if (i <= arrayLen(matches.groups)) {
                            params[r.paramNames[i]] = matches.groups[i];
                        }
                    }

                    var allMiddlewares = duplicate(variables.globalMiddlewares);
                    for (var m in r.middlewares) {
                        arrayAppend(allMiddlewares, m);
                    }

                    return {
                        "matched": true,
                        "status": 200,
                        "route": r,
                        "params": params,
                        "handler": r.handler,
                        "middlewares": allMiddlewares
                    };
                } else {
                    methodMismatchFound = true;
                }
            }
        }

        if (methodMismatchFound) {
            return {
                "matched": false,
                "status": 405,
                "error": "Method Not Allowed",
                "params": {},
                "handler": "",
                "middlewares": []
            };
        }

        return {
            "matched": false,
            "status": 404,
            "error": "Not Found",
            "params": {},
            "handler": "",
            "middlewares": []
        };
    }

    /**
     * Executes regular expression match with group extraction.
     */
    private struct function reMatchGroups(required string text, required string regex) {
        var pattern = createObject("java", "java.util.regex.Pattern").compile(arguments.regex);
        var matcher = pattern.matcher(arguments.text);

        if (!matcher.matches()) {
            return { "matched": false, "groups": [] };
        }

        var groups = [];
        var count = matcher.groupCount();
        for (var i = 1; i <= count; i++) {
            arrayAppend(groups, matcher.group(javaCast("int", i)));
        }

        return { "matched": true, "groups": groups };
    }

    /**
     * Dispatches an incoming HTTP request through middleware pipeline to handler.
     */
    public struct function dispatch(
        required string method,
        required string uri,
        struct headers = {},
        struct queryParams = {},
        any body = ""
    ) {
        var matchResult = match(arguments.method, arguments.uri);

        var context = {
            "method": uCase(arguments.method),
            "uri": arguments.uri,
            "headers": arguments.headers,
            "queryParams": arguments.queryParams,
            "params": matchResult.params,
            "body": arguments.body,
            "response": {
                "statusCode": matchResult.status,
                "headers": { "Content-Type": "application/json" },
                "body": ""
            }
        };

        if (!matchResult.matched) {
            if (matchResult.status == 405) {
                if (isCustomFunction(variables.methodNotAllowedHandler) || isClosure(variables.methodNotAllowedHandler)) {
                    var fn405 = variables.methodNotAllowedHandler;
                    return fn405(context);
                }
                context.response.statusCode = 405;
                context.response.body = serializeJson({ "error": "Method Not Allowed", "method": arguments.method, "uri": arguments.uri });
                return context.response;
            } else {
                if (isCustomFunction(variables.notFoundHandler) || isClosure(variables.notFoundHandler)) {
                    var fn404 = variables.notFoundHandler;
                    return fn404(context);
                }
                context.response.statusCode = 404;
                context.response.body = serializeJson({ "error": "Not Found", "uri": arguments.uri });
                return context.response;
            }
        }

        // Execute middleware pipeline
        var mwIdx = 1;
        var mws = matchResult.middlewares;
        var mwCount = arrayLen(mws);

        for (var mw in mws) {
            var proceed = true;
            if (isCustomFunction(mw) || isClosure(mw)) {
                var mwRes = mw(context);
                if (isBoolean(mwRes) && !mwRes) {
                    proceed = false;
                }
            } else if (isObject(mw) && structKeyExists(mw, "handle")) {
                var mwObjRes = mw.handle(context);
                if (isBoolean(mwObjRes) && !mwObjRes) {
                    proceed = false;
                }
            }

            if (!proceed) {
                return context.response;
            }
        }

        // Execute handler
        var handler = matchResult.handler;
        try {
            if (isCustomFunction(handler) || isClosure(handler)) {
                var hResult = handler(context);
                if (isStruct(hResult) && structKeyExists(hResult, "statusCode")) {
                    return hResult;
                } else if (!isNull(hResult)) {
                    context.response.body = isSimpleValue(hResult) ? hResult : serializeJson(hResult);
                }
            } else if (isObject(handler)) {
                if (structKeyExists(handler, "execute")) {
                    var oResult = handler.execute(context);
                    if (isStruct(oResult) && structKeyExists(oResult, "statusCode")) {
                        return oResult;
                    } else if (!isNull(oResult)) {
                        context.response.body = isSimpleValue(oResult) ? oResult : serializeJson(oResult);
                    }
                }
            }
        } catch (any e) {
            context.response.statusCode = 500;
            context.response.body = serializeJson({
                "error": "Internal Server Error",
                "message": e.message,
                "detail": e.detail
            });
        }

        return context.response;
    }

}
