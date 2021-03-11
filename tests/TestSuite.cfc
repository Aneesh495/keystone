component {

    property name="currentSuite" type="string";
    property name="results" type="struct";

    public any function init() {
        variables.currentSuite = "";
        variables.results = {
            "totalSuites": 0,
            "totalTests": 0,
            "passed": 0,
            "failed": 0,
            "errors": [],
            "durationMs": 0
        };
        return this;
    }

    public void function describe(required string suiteName, required any specClosure) {
        variables.currentSuite = arguments.suiteName;
        variables.results.totalSuites++;
        var startSuite = createObject("java", "java.lang.System").currentTimeMillis();

        arguments.specClosure(this);

        var endSuite = createObject("java", "java.lang.System").currentTimeMillis();
        variables.results.durationMs += (endSuite - startSuite);
    }

    public void function it(required string testName, required any testClosure) {
        variables.results.totalTests++;
        try {
            arguments.testClosure();
            variables.results.passed++;
        } catch (any e) {
            variables.results.failed++;
            arrayAppend(variables.results.errors, {
                "suite": variables.currentSuite,
                "test": arguments.testName,
                "message": e.message,
                "detail": structKeyExists(e, "detail") ? e.detail : "",
                "type": structKeyExists(e, "type") ? e.type : "TestFailure"
            });
        }
    }

    public void function assertEquals(required any expected, required any actual, string message = "") {
        if (arguments.expected != arguments.actual) {
            var msg = len(arguments.message) ? arguments.message : "Expected [" & serializeJson(arguments.expected) & "] but got [" & serializeJson(arguments.actual) & "]";
            throw(type="AssertionFailure", message=msg);
        }
    }

    public void function assertTrue(required boolean condition, string message = "") {
        if (!arguments.condition) {
            var msg = len(arguments.message) ? arguments.message : "Expected condition to be true, got false";
            throw(type="AssertionFailure", message=msg);
        }
    }

    public void function assertFalse(required boolean condition, string message = "") {
        if (arguments.condition) {
            var msg = len(arguments.message) ? arguments.message : "Expected condition to be false, got true";
            throw(type="AssertionFailure", message=msg);
        }
    }

    public void function assertNotNull(any value, string message = "") {
        if (isNull(arguments.value)) {
            var msg = len(arguments.message) ? arguments.message : "Expected value to be non-null";
            throw(type="AssertionFailure", message=msg);
        }
    }

    public void function assertThrows(required string expectedType, required any closure, string message = "") {
        var threw = false;
        try {
            arguments.closure();
        } catch (any e) {
            threw = true;
            if (len(arguments.expectedType) && e.type != arguments.expectedType && !findNoCase(arguments.expectedType, e.type)) {
                throw(type="AssertionFailure", message="Expected exception of type [" & arguments.expectedType & "] but caught [" & e.type & "]");
            }
        }
        if (!threw) {
            var msg = len(arguments.message) ? arguments.message : "Expected exception of type [" & arguments.expectedType & "] but no exception was thrown";
            throw(type="AssertionFailure", message=msg);
        }
    }

    public struct function getResults() {
        return variables.results;
    }
}
