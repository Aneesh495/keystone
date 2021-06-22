<cfscript>
// Keystone Automated Test Suite Runner
startMs = createObject("java", "java.lang.System").currentTimeMillis();

writeOutput("================================================================" & chr(10));
writeOutput("       KEYSTONE TRANSACTION GATEWAY TEST ORCHESTRATOR           " & chr(10));
writeOutput("================================================================" & chr(10));

suite = new tests.TestSuite();

// List of all registered test runners
testSuites = [
    new tests.unit.core.KernelSubsystemsTest(),
    new tests.unit.parsers.X12ParserTest(),
    new tests.unit.parsers.EdifactParserTest(),
    new tests.unit.parsers.HL7ParserTest(),
    new tests.unit.parsers.Iso20022ParserTest(),
    new tests.unit.parsers.FlatFileTest(),
    new tests.unit.transform.TransformTest(),
    new tests.unit.security.SecurityTest(),
    new tests.unit.transactions.SagaTest()
];

// Execute each suite
for (testCase in testSuites) {
    testCase.run(suite);
}

results = suite.getResults();
totalElapsed = createObject("java", "java.lang.System").currentTimeMillis() - startMs;

writeOutput(chr(10));
writeOutput("----------------------------------------------------------------" & chr(10));
writeOutput("RESULTS: " & results.totalTests & " tests executed across " & results.totalSuites & " suites in " & totalElapsed & "ms." & chr(10));
writeOutput("PASSED:  " & results.passed & chr(10));
writeOutput("FAILED:  " & results.failed & chr(10));
writeOutput("----------------------------------------------------------------" & chr(10));

if (results.failed > 0) {
    writeOutput(chr(10) & "[FAILURES & ERRORS]:" & chr(10));
    for (err in results.errors) {
        writeOutput("  - [" & err.suite & "] " & err.test & ": " & err.message & chr(10));
        if (len(err.detail)) {
            writeOutput("    Detail: " & err.detail & chr(10));
        }
    }
    writeOutput(chr(10));
    throw(type="TestSuiteFailedException", message=results.failed & " tests failed.");
} else {
    writeOutput("[SUCCESS] All test suites passed cleanly with 100% assertion success." & chr(10));
}
</cfscript>
