/**
 * Keystone B2B Transaction Mesh - REST API Controller
 *
 * Exposes management, health check, dynamic parser, and telemetry endpoints.
 */
component {

    property name="kernel" type="any";

    public any function init(any kernel = "") {
        variables.kernel = arguments.kernel;
        return this;
    }

    /**
     * System health check endpoint.
     */
    public struct function getHealth(struct context = {}) {
        var status = "UP";
        var components = {
            "kernel": isObject(variables.kernel) ? "READY" : "STANDALONE",
            "jvm": "ONLINE",
            "timestamp": now()
        };

        return {
            "statusCode": 200,
            "headers": { "Content-Type": "application/json" },
            "body": serializeJson({
                "status": status,
                "version": "1.0.0",
                "subsystems": components
            })
        };
    }

    /**
     * Dynamic document parser endpoint.
     */
    public struct function parseDocument(struct context = {}) {
        var body = arguments.context.body;
        var req = isStruct(body) ? body : (isJSON(body) ? deserializeJson(body) : {});

        var protocol = structKeyExists(req, "protocol") ? req.protocol : "X12";
        var content = structKeyExists(req, "content") ? req.content : "";

        if (len(trim(content)) == 0) {
            return {
                "statusCode": 400,
                "headers": { "Content-Type": "application/json" },
                "body": serializeJson({ "error": "Missing 'content' field in parse payload" })
            };
        }

        var result = {};
        try {
            switch (uCase(protocol)) {
                case "X12":
                    var x12 = new app.parsers.x12.X12Parser();
                    result = x12.parse(content);
                    break;
                case "EDIFACT":
                    var edifact = new app.parsers.edifact.EdifactParser();
                    result = edifact.parse(content);
                    break;
                case "HL7":
                    var hl7 = new app.parsers.hl7.HL7Parser();
                    result = hl7.parse(content);
                    break;
                case "ISO20022":
                    var iso = new app.parsers.iso20022.Iso20022Parser();
                    result = iso.parse(content);
                    break;
                case "CSV":
                    var csv = new app.parsers.flatfile.CsvParser();
                    result = csv.parse(content);
                    break;
                default:
                    return {
                        "statusCode": 400,
                        "headers": { "Content-Type": "application/json" },
                        "body": serializeJson({ "error": "Unsupported protocol: " & protocol })
                    };
            }

            return {
                "statusCode": 200,
                "headers": { "Content-Type": "application/json" },
                "body": serializeJson({
                    "success": result.isSuccess(),
                    "errors": result.getErrors(),
                    "warnings": result.getWarnings(),
                    "ast": result.getData()
                })
            };
        } catch (any e) {
            return {
                "statusCode": 500,
                "headers": { "Content-Type": "application/json" },
                "body": serializeJson({
                    "error": "Parser failed",
                    "message": e.message,
                    "detail": e.detail
                })
            };
        }
    }

    /**
     * Prompts Prometheus exporter metrics.
     */
    public struct function getMetrics(struct context = {}) {
        var exporter = new app.telemetry.PrometheusExporter();
        if (isObject(variables.kernel) && variables.kernel.hasService("metrics")) {
            exporter.setCollector(variables.kernel.getService("metrics"));
        }

        return {
            "statusCode": 200,
            "headers": { "Content-Type": "text/plain; version=0.0.4; charset=utf-8" },
            "body": exporter.export()
        };
    }

}
