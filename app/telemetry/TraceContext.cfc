/**
 * Keystone B2B Transaction Mesh - W3C Trace Context Propagator
 *
 * Implements the W3C Trace Context specification (RFC draft) for distributed tracing propagation
 * across asynchronous B2B pipelines, HTTP endpoints, AS2 exchanges, and saga workflows.
 */
component {

    /**
     * Creates a new root trace context.
     */
    public struct function createRoot(boolean sampled = true) {
        return {
            "version": "00",
            "traceId": generateTraceId(),
            "spanId": generateSpanId(),
            "sampled": arguments.sampled,
            "flags": arguments.sampled ? "01" : "00"
        };
    }

    /**
     * Creates a child span context inheriting the parent trace ID.
     */
    public struct function createChild(required struct parentContext) {
        return {
            "version": "00",
            "traceId": arguments.parentContext.traceId,
            "spanId": generateSpanId(),
            "parentSpanId": arguments.parentContext.spanId,
            "sampled": arguments.parentContext.sampled,
            "flags": arguments.parentContext.flags
        };
    }

    /**
     * Parses an incoming W3C 'traceparent' HTTP header.
     * Format: 00-{trace_id}-{parent_id}-{flags}
     */
    public struct function parseTraceparent(required string headerValue) {
        var clean = trim(arguments.headerValue);
        var parts = listToArray(clean, "-");

        if (arrayLen(parts) != 4 || len(parts[2]) != 32 || len(parts[3]) != 16) {
            return createRoot();
        }

        var flags = parts[4];
        var isSampled = (flags == "01");

        return {
            "version": parts[1],
            "traceId": parts[2],
            "spanId": generateSpanId(),
            "parentSpanId": parts[3],
            "sampled": isSampled,
            "flags": flags
        };
    }

    /**
     * Formats a trace context into a W3C 'traceparent' header string.
     */
    public string function formatTraceparent(required struct context) {
        var ver = structKeyExists(arguments.context, "version") ? arguments.context.version : "00";
        var tId = arguments.context.traceId;
        var sId = arguments.context.spanId;
        var fl = structKeyExists(arguments.context, "flags") ? arguments.context.flags : (arguments.context.sampled ? "01" : "00");

        return ver & "-" & tId & "-" & sId & "-" & fl;
    }

    /**
     * Generates a 16-byte (32-character hexadecimal) trace identifier.
     */
    public string function generateTraceId() {
        var u1 = replace(createUUID(), "-", "", "all");
        var u2 = replace(createUUID(), "-", "", "all");
        return lCase(left(u1 & u2, 32));
    }

    /**
     * Generates an 8-byte (16-character hexadecimal) span identifier.
     */
    public string function generateSpanId() {
        var u = replace(createUUID(), "-", "", "all");
        return lCase(left(u, 16));
    }

}
