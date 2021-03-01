component {

    property name="nodeId" type="numeric";
    property name="epoch" type="numeric";
    property name="lastTimestamp" type="numeric";
    property name="sequence" type="numeric";

    // Custom epoch: 2026-01-01 00:00:00 UTC (1767225600000 ms)
    variables.CUSTOM_EPOCH = 1767225600000;
    variables.NODE_BITS = 10;
    variables.SEQUENCE_BITS = 12;
    variables.MAX_NODE_ID = 1023;
    variables.MAX_SEQUENCE = 4095;

    /**
     * Constructor for IdGenerator.
     *
     * @nodeId Unique cluster node ID (0 - 1023)
     */
    public any function init(numeric nodeId = 1) {
        if (arguments.nodeId < 0 || arguments.nodeId > variables.MAX_NODE_ID) {
            arguments.nodeId = 1;
        }
        variables.nodeId = arguments.nodeId;
        variables.epoch = variables.CUSTOM_EPOCH;
        variables.lastTimestamp = -1;
        variables.sequence = 0;
        return this;
    }

    /**
     * Generates a 64-bit Snowflake ID represented as a decimal string.
     */
    public string function nextId() {
        var idStr = "";
        lock name="keystone_id_gen_lock" type="exclusive" timeout="2" {
            var currentTimestamp = currentTimeMillis();

            if (currentTimestamp < variables.lastTimestamp) {
                var offset = variables.lastTimestamp - currentTimestamp;
                if (offset <= 5) {
                    // Small clock drift, wait it out
                    createObject("java", "java.lang.Thread").sleep(offset + 1);
                    currentTimestamp = currentTimeMillis();
                } else {
                    throw(type="ClockMovedBackwardsException", message="Clock moved backwards by " & offset & "ms");
                }
            }

            if (currentTimestamp == variables.lastTimestamp) {
                variables.sequence = (variables.sequence + 1) % (variables.MAX_SEQUENCE + 1);
                if (variables.sequence == 0) {
                    // Sequence exhausted for current millisecond, wait for next millisecond
                    while (currentTimestamp <= variables.lastTimestamp) {
                        currentTimestamp = currentTimeMillis();
                    }
                }
            } else {
                variables.sequence = 0;
            }

            variables.lastTimestamp = currentTimestamp;

            var timeDiff = currentTimestamp - variables.epoch;
            // Use Java BigInteger for 64-bit bitwise shifting without signed 32-bit overflow
            var bigTime = createObject("java", "java.math.BigInteger").valueOf(javaCast("long", timeDiff));
            var bigNode = createObject("java", "java.math.BigInteger").valueOf(javaCast("long", variables.nodeId));
            var bigSeq = createObject("java", "java.math.BigInteger").valueOf(javaCast("long", variables.sequence));

            var shiftedTime = bigTime.shiftLeft(22);
            var shiftedNode = bigNode.shiftLeft(12);

            var combined = shiftedTime.or(shiftedNode).or(bigSeq);
            idStr = combined.toString();
        }

        return idStr;
    }

    /**
     * Generates an RFC 9562 compliant UUIDv7 (time-ordered UUID).
     */
    public string function nextUuidV7() {
        var ms = currentTimeMillis();
        var secureRandom = createObject("java", "java.security.SecureRandom");

        // 48 bits timestamp
        var msHex = right("000000000000" & formatHex(ms), 12);

        // 12 bits random + version 7 (4 bits 0111)
        var randA = secureRandom.nextInt(4096);
        var randAHex = right("000" & formatHex(randA), 3);
        var verAndRandA = "7" & randAHex;

        // 2 bits variant (10) + 62 bits random
        var randB = secureRandom.nextLong();
        var bigRandB = createObject("java", "java.math.BigInteger").valueOf(randB).abs();
        var randBHex = right("0000000000000000" & bigRandB.toString(16), 16);

        // Variant mask: top two bits must be 10 (8, 9, a, or b)
        var variantChar = listGetAt("8,9,a,b", (secureRandom.nextInt(4) + 1));
        var remainingRandB = right(randBHex, 15);
        var variantField = variantChar & remainingRandB;

        // Format 8-4-4-4-12
        var p1 = left(msHex, 8);
        var p2 = right(msHex, 4);
        var p3 = verAndRandA;
        var p4 = left(variantField, 4);
        var p5 = right(variantField, 12);

        return lcase(p1 & "-" & p2 & "-" & p3 & "-" & p4 & "-" & p5);
    }

    /**
     * Generates standard EDI interchange control number (9 digits, padded with leading zeroes).
     */
    public string function nextControlNumber(numeric length = 9) {
        var id = nextId();
        var suffix = right(id, arguments.length);
        while (len(suffix) < arguments.length) {
            suffix = "0" & suffix;
        }
        return suffix;
    }

    private numeric function currentTimeMillis() {
        return createObject("java", "java.lang.System").currentTimeMillis();
    }

    private string function formatHex(required numeric num) {
        var big = createObject("java", "java.math.BigInteger").valueOf(javaCast("long", arguments.num));
        return big.toString(16);
    }
}
