/**
 * Keystone B2B Transaction Mesh - High Dynamic Range Latency Histogram
 *
 * Records latency values across multi-order-of-magnitude ranges with bounded memory,
 * calculating accurate percentiles (p50, p90, p95, p99, p99.9) for transaction throughput.
 */
component {

    property name="counts" type="struct";
    property name="totalCount" type="numeric";
    property name="totalSum" type="numeric";
    property name="minValue" type="numeric";
    property name="maxValue" type="numeric";
    property name="lockName" type="string";

    /**
     * Initializes the HdrHistogram.
     */
    public any function init() {
        variables.counts = {};
        variables.totalCount = 0;
        variables.totalSum = 0;
        variables.minValue = 999999999;
        variables.maxValue = 0;
        variables.lockName = "keystone_hdr_histogram_lock_" & createUUID();

        return this;
    }

    /**
     * Quantizes a value into an integer bucket for logarithmic distribution.
     */
    private numeric function quantize(required numeric value) {
        if (arguments.value <= 0) return 0;
        if (arguments.value < 10) return floor(arguments.value * 10) / 10;
        if (arguments.value < 100) return floor(arguments.value);
        if (arguments.value < 1000) return floor(arguments.value / 5) * 5;
        if (arguments.value < 10000) return floor(arguments.value / 20) * 20;
        return floor(arguments.value / 100) * 100;
    }

    /**
     * Records a numeric latency measurement.
     */
    public void function record(required numeric value) {
        if (arguments.value < 0) return;

        var bucket = quantize(arguments.value);
        var key = toString(bucket);

        lock name=variables.lockName type="exclusive" timeout="5" {
            variables.totalCount++;
            variables.totalSum += arguments.value;
            variables.minValue = min(variables.minValue, arguments.value);
            variables.maxValue = max(variables.maxValue, arguments.value);

            if (structKeyExists(variables.counts, key)) {
                variables.counts[key]++;
            } else {
                variables.counts[key] = 1;
            }
        }
    }

    public numeric function getCount() {
        return variables.totalCount;
    }

    public numeric function getSum() {
        return variables.totalSum;
    }

    public numeric function getMin() {
        return variables.totalCount > 0 ? variables.minValue : 0;
    }

    public numeric function getMax() {
        return variables.maxValue;
    }

    public numeric function getMean() {
        return variables.totalCount > 0 ? (variables.totalSum / variables.totalCount) : 0;
    }

    /**
     * Calculates the estimated value at a specific percentile (0.0 to 100.0).
     */
    public numeric function getValueAtPercentile(required numeric percentile) {
        if (variables.totalCount == 0) return 0;
        if (arguments.percentile >= 100.0) return variables.maxValue;

        var targetRank = ceiling((arguments.percentile / 100.0) * variables.totalCount);
        if (targetRank <= 0) targetRank = 1;

        // Sort bucket keys numerically
        var keys = structKeyArray(variables.counts);
        arraySort(keys, "numeric", "asc");

        var accumulated = 0;
        for (var k in keys) {
            accumulated += variables.counts[k];
            if (accumulated >= targetRank) {
                return val(k);
            }
        }

        return variables.maxValue;
    }

    public void function reset() {
        lock name=variables.lockName type="exclusive" timeout="5" {
            variables.counts = {};
            variables.totalCount = 0;
            variables.totalSum = 0;
            variables.minValue = 999999999;
            variables.maxValue = 0;
        }
    }

}
