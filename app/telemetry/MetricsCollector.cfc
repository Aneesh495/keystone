/**
 * Keystone B2B Transaction Mesh - Metrics Collector
 *
 * Provides thread-safe telemetry aggregation for counters, gauges, and high-dynamic-range timers
 * with multi-dimensional tag labels.
 */
component {

    property name="counters" type="struct";
    property name="gauges" type="struct";
    property name="timers" type="struct";
    property name="lockName" type="string";

    /**
     * Initializes the MetricsCollector.
     */
    public any function init() {
        variables.counters = {};
        variables.gauges = {};
        variables.timers = {};
        variables.lockName = "keystone_metrics_collector_lock";

        return this;
    }

    private string function makeKey(required string name, struct tags = {}) {
        if (structIsEmpty(arguments.tags)) {
            return arguments.name;
        }
        var keys = structKeyArray(arguments.tags);
        arraySort(keys, "textnocase", "asc");
        var parts = [];
        for (var k in keys) {
            arrayAppend(parts, k & "=" & arguments.tags[k]);
        }
        return arguments.name & "{" & arrayToList(parts, ",") & "}";
    }

    /**
     * Increments a monotonic counter.
     */
    public void function increment(required string name, numeric delta = 1, struct tags = {}) {
        var key = makeKey(arguments.name, arguments.tags);
        lock name=variables.lockName type="exclusive" timeout="5" {
            if (structKeyExists(variables.counters, key)) {
                variables.counters[key] += arguments.delta;
            } else {
                variables.counters[key] = arguments.delta;
            }
        }
    }

    /**
     * Sets an instantaneous gauge value.
     */
    public void function setGauge(required string name, required numeric value, struct tags = {}) {
        var key = makeKey(arguments.name, arguments.tags);
        lock name=variables.lockName type="exclusive" timeout="5" {
            variables.gauges[key] = arguments.value;
        }
    }

    /**
     * Records a latency or duration measurement in a timer histogram.
     */
    public void function recordDuration(required string name, required numeric durationMs, struct tags = {}) {
        var key = makeKey(arguments.name, arguments.tags);
        var hist = "";

        lock name=variables.lockName type="exclusive" timeout="5" {
            if (!structKeyExists(variables.timers, key)) {
                variables.timers[key] = new app.telemetry.HdrHistogram();
            }
            hist = variables.timers[key];
        }

        hist.record(arguments.durationMs);
    }

    /**
     * Returns a snapshot of all recorded metrics.
     */
    public struct function getMetricsSnapshot() {
        var snapshot = {
            "counters": {},
            "gauges": {},
            "timers": {}
        };

        lock name=variables.lockName type="readOnly" timeout="5" {
            snapshot.counters = duplicate(variables.counters);
            snapshot.gauges = duplicate(variables.gauges);

            for (var tKey in variables.timers) {
                var h = variables.timers[tKey];
                snapshot.timers[tKey] = {
                    "count": h.getCount(),
                    "sum": h.getSum(),
                    "mean": h.getMean(),
                    "min": h.getMin(),
                    "max": h.getMax(),
                    "p50": h.getValueAtPercentile(50.0),
                    "p90": h.getValueAtPercentile(90.0),
                    "p95": h.getValueAtPercentile(95.0),
                    "p99": h.getValueAtPercentile(99.0)
                };
            }
        }

        return snapshot;
    }

    public void function reset() {
        lock name=variables.lockName type="exclusive" timeout="5" {
            variables.counters = {};
            variables.gauges = {};
            variables.timers = {};
        }
    }

}
