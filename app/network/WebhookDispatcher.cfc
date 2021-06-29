/**
 * Keystone B2B Transaction Mesh - Webhook Dispatcher
 *
 * Dispatches cryptographically signed outbound HTTP webhooks to trading partners and downstream systems
 * with HMAC-SHA256 signature headers, configurable timeouts, and delivery telemetry.
 */
component {

    property name="cryptoEngine" type="any";
    property name="logger" type="any";
    property name="eventBus" type="any";
    property name="defaultTimeoutSeconds" type="numeric";

    /**
     * Initializes the WebhookDispatcher.
     */
    public any function init(
        any cryptoEngine = "",
        any logger = "",
        any eventBus = "",
        numeric defaultTimeoutSeconds = 10
    ) {
        variables.cryptoEngine = isObject(arguments.cryptoEngine) ? arguments.cryptoEngine : new app.security.CryptoEngine();
        variables.logger = arguments.logger;
        variables.eventBus = arguments.eventBus;
        variables.defaultTimeoutSeconds = arguments.defaultTimeoutSeconds;

        return this;
    }

    /**
     * Dispatches an outbound webhook payload to an external endpoint.
     *
     * @url Destination HTTP/HTTPS endpoint URL
     * @payload Struct or string body to transmit
     * @signingSecret Shared secret key used for HMAC-SHA256 signing
     * @customHeaders Optional custom HTTP headers to pass
     * @timeoutSeconds Request timeout in seconds
     * @return Struct { "success": boolean, "statusCode": numeric, "body": string, "error": string }
     */
    public struct function dispatch(
        required string url,
        required any payload,
        string signingSecret = "",
        struct customHeaders = {},
        numeric timeoutSeconds = 0
    ) {
        var timeout = arguments.timeoutSeconds > 0 ? arguments.timeoutSeconds : variables.defaultTimeoutSeconds;
        var bodyStr = isSimpleValue(arguments.payload) ? arguments.payload : serializeJson(arguments.payload);
        var timestamp = createObject("java", "java.lang.System").currentTimeMillis();

        var httpHeaders = duplicate(arguments.customHeaders);
        httpHeaders["Content-Type"] = "application/json";
        httpHeaders["User-Agent"] = "Keystone-B2B-Gateway/1.0";
        httpHeaders["X-Keystone-Timestamp"] = timestamp;

        if (len(trim(arguments.signingSecret))) {
            var signPayload = timestamp & "." & bodyStr;
            var signature = variables.cryptoEngine.hmacSha256(signPayload, arguments.signingSecret);
            httpHeaders["X-Keystone-Signature"] = "t=" & timestamp & ",v1=" & signature;
        }

        var httpService = new http();
        httpService.setMethod("POST");
        httpService.setUrl(arguments.url);
        httpService.setTimeout(timeout);

        for (var h in httpHeaders) {
            httpService.addParam(type="header", name=h, value=httpHeaders[h]);
        }
        httpService.addParam(type="body", value=bodyStr);

        try {
            var httpResult = httpService.send().getPrefix();
            var statusCode = structKeyExists(httpResult, "responseHeader") && structKeyExists(httpResult.responseHeader, "status_code") ? httpResult.responseHeader.status_code : val(httpResult.statusCode);
            var isSuccess = (statusCode >= 200 && statusCode < 300);

            if (isObject(variables.eventBus)) {
                variables.eventBus.publish("webhook.dispatched", {
                    "url": arguments.url,
                    "statusCode": statusCode,
                    "success": isSuccess
                });
            }

            return {
                "success": isSuccess,
                "statusCode": statusCode,
                "body": structKeyExists(httpResult, "fileContent") ? httpResult.fileContent : "",
                "error": isSuccess ? "" : "HTTP returned non-success code: " & statusCode
            };
        } catch (any e) {
            if (isObject(variables.logger)) {
                variables.logger.error("Webhook dispatch failed to [#arguments.url#]: #e.message#");
            }
            if (isObject(variables.eventBus)) {
                variables.eventBus.publish("webhook.failed", { "url": arguments.url, "error": e.message });
            }
            return {
                "success": false,
                "statusCode": 0,
                "body": "",
                "error": e.message & " " & e.detail
            };
        }
    }

}
