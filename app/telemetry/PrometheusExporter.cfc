/**
 * Keystone B2B Transaction Mesh - Prometheus Metrics Exporter
 *
 * Renders Prometheus text exposition format (version 0.0.4) for scraping by
 * Prometheus, Grafana Agent, or OpenTelemetry collectors.
 */
component {

    property name="collector" type="any";

    /**
     * Initializes the PrometheusExporter with a MetricsCollector instance.
     */
    public any function init(any collector = "") {
        variables.collector = arguments.collector;
        return this;
    }

    public void function setCollector(required any collector) {
        variables.collector = arguments.collector;
    }

    /**
     * Renders Prometheus formatted metrics string.
     */
    public string function export() {
        var sb = createObject("java", "java.lang.StringBuilder").init();
        var nl = chr(10);

        if (!isObject(variables.collector)) {
            return "## No metrics collector registered" & nl;
        }

        var snapshot = variables.collector.getMetricsSnapshot();

        // Export counters
        for (var cKey in snapshot.counters) {
            var val = snapshot.counters[cKey];
            var parsed = parseMetricKey(cKey);
            sb.append("## TYPE ").append(parsed.name).append(" counter").append(nl);
            sb.append(parsed.name).append(formatLabels(parsed.labels)).append(" ").append(val).append(nl);
        }

        // Export gauges
        for (var gKey in snapshot.gauges) {
            var gVal = snapshot.gauges[gKey];
            var parsedG = parseMetricKey(gKey);
            sb.append("## TYPE ").append(parsedG.name).append(" gauge").append(nl);
            sb.append(parsedG.name).append(formatLabels(parsedG.labels)).append(" ").append(gVal).append(nl);
        }

        // Export histograms / timers
        for (var tKey in snapshot.timers) {
            var tData = snapshot.timers[tKey];
            var parsedT = parseMetricKey(tKey);
            var baseName = parsedT.name;

            sb.append("## TYPE ").append(baseName).append(" summary").append(nl);
            sb.append(baseName).append(formatLabelsWithQuantile(parsedT.labels, "0.5")).append(" ").append(tData.p50).append(nl);
            sb.append(baseName).append(formatLabelsWithQuantile(parsedT.labels, "0.9")).append(" ").append(tData.p90).append(nl);
            sb.append(baseName).append(formatLabelsWithQuantile(parsedT.labels, "0.99")).append(" ").append(tData.p99).append(nl);
            sb.append(baseName).append("_sum").append(formatLabels(parsedT.labels)).append(" ").append(tData.sum).append(nl);
            sb.append(baseName).append("_count").append(formatLabels(parsedT.labels)).append(" ").append(tData.count).append(nl);
        }

        // JVM Runtime metrics
        var runtime = createObject("java", "java.lang.Runtime").getRuntime();
        var usedMem = runtime.totalMemory() - runtime.freeMemory();
        sb.append("## TYPE jvm_memory_used_bytes gauge").append(nl);
        sb.append("jvm_memory_used_bytes ").append(usedMem).append(nl);
        sb.append("## TYPE jvm_memory_max_bytes gauge").append(nl);
        sb.append("jvm_memory_max_bytes ").append(runtime.maxMemory()).append(nl);

        return sb.toString();
    }

    private struct function parseMetricKey(required string rawKey) {
        var braceIdx = find("{", arguments.rawKey);
        if (braceIdx == 0) {
            return { "name": sanitizeName(arguments.rawKey), "labels": {} };
        }

        var name = sanitizeName(left(arguments.rawKey, braceIdx - 1));
        var labelStr = mid(arguments.rawKey, braceIdx + 1, len(arguments.rawKey) - braceIdx - 1);
        var labelPairs = listToArray(labelStr, ",");
        var labels = {};

        for (var pair in labelPairs) {
            var eqIdx = find("=", pair);
            if (eqIdx > 0) {
                var lk = left(pair, eqIdx - 1);
                var lv = mid(pair, eqIdx + 1, len(pair) - eqIdx);
                labels[lk] = lv;
            }
        }

        return { "name": name, "labels": labels };
    }

    private string function sanitizeName(required string name) {
        return reReplace(arguments.name, "[^a-zA-Z0-9_:]", "_", "all");
    }

    private string function formatLabels(required struct labels) {
        if (structIsEmpty(arguments.labels)) {
            return "";
        }
        var parts = [];
        for (var k in arguments.labels) {
            arrayAppend(parts, k & "=""" & arguments.labels[k] & """");
        }
        return "{" & arrayToList(parts, ",") & "}";
    }

    private string function formatLabelsWithQuantile(required struct labels, required string quantile) {
        var copy = duplicate(arguments.labels);
        copy["quantile"] = arguments.quantile;
        return formatLabels(copy);
    }

}
