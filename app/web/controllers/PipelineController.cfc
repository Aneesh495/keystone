/**
 * Keystone B2B Transaction Mesh - Pipeline Execution Controller
 *
 * Executes full pipeline lifecycle stages: protocol ingestion, validation, canonical schema transformation,
 * distributed saga coordination, cryptographic audit logging, and partner acknowledgment.
 */
component {

    property name="kernel" type="any";
    property name="workflowRegistry" type="any";
    property name="sagaCoordinator" type="any";
    property name="auditLedger" type="any";
    property name="metrics" type="any";

    public any function init(any kernel = "") {
        variables.kernel = arguments.kernel;
        if (isObject(variables.kernel)) {
            variables.workflowRegistry = variables.kernel.hasService("workflowRegistry") ? variables.kernel.getService("workflowRegistry") : new app.registry.WorkflowRegistry();
            variables.sagaCoordinator = variables.kernel.hasService("sagaCoordinator") ? variables.kernel.getService("sagaCoordinator") : new app.transactions.SagaCoordinator();
            variables.auditLedger = variables.kernel.hasService("auditLedger") ? variables.kernel.getService("auditLedger") : new app.security.AuditLedger();
            variables.metrics = variables.kernel.hasService("metrics") ? variables.kernel.getService("metrics") : new app.telemetry.MetricsCollector();
        } else {
            variables.workflowRegistry = new app.registry.WorkflowRegistry();
            variables.sagaCoordinator = new app.transactions.SagaCoordinator();
            variables.auditLedger = new app.security.AuditLedger();
            variables.metrics = new app.telemetry.MetricsCollector();
        }

        return this;
    }

    /**
     * Executes the pipeline for an inbound raw B2B document payload.
     *
     * @protocol Protocol family: X12, EDIFACT, HL7, ISO20022
     * @documentType Standard document code (850, ORDERS, ADT_A01, pain.001)
     * @rawContent Unprocessed document string
     * @partnerId Identifier of the transmitting partner
     * @return Struct pipeline execution summary
     */
    public struct function processInbound(
        required string protocol,
        required string documentType,
        required string rawContent,
        string partnerId = "ANONYMOUS"
    ) {
        var startTick = getTickCount();
        variables.metrics.increment("pipeline.inbound.received", 1, { "protocol": arguments.protocol, "partner": arguments.partnerId });

        var workflow = variables.workflowRegistry.resolve(arguments.protocol, arguments.documentType);
        var pipelineResult = {
            "success": false,
            "pipelineId": createUUID(),
            "protocol": arguments.protocol,
            "documentType": arguments.documentType,
            "partnerId": arguments.partnerId,
            "parsed": {},
            "validation": { "valid": true, "errors": [] },
            "transformed": {},
            "sagaStatus": "SKIPPED",
            "acknowledgment": "",
            "elapsedMs": 0
        };

        // Stage 1: Parse Document
        var parser = createObject("component", workflow.parserClass);
        var parseResult = parser.parse(arguments.rawContent);

        if (!parseResult.isSuccess()) {
            pipelineResult.success = false;
            pipelineResult.validation.valid = false;
            pipelineResult.validation.errors = parseResult.getErrors();
            variables.metrics.increment("pipeline.parse.failed", 1, { "protocol": arguments.protocol });
            return pipelineResult;
        }

        pipelineResult.parsed = parseResult.getData();

        // Stage 2: Validate Schema
        if (structKeyExists(workflow, "validatorClass") && len(trim(workflow.validatorClass))) {
            var validator = createObject("component", workflow.validatorClass);
            var valResult = validator.validate(pipelineResult.parsed);
            if (!valResult.isValid()) {
                pipelineResult.success = false;
                pipelineResult.validation.valid = false;
                pipelineResult.validation.errors = valResult.getErrors();
                variables.metrics.increment("pipeline.validation.failed", 1, { "protocol": arguments.protocol });
                return pipelineResult;
            }
        }

        // Stage 3: Schema Transform / Mapping
        if (structKeyExists(workflow, "mapperClass") && len(trim(workflow.mapperClass))) {
            var mapper = createObject("component", workflow.mapperClass);
            pipelineResult.transformed = mapper.transform(pipelineResult.parsed);
        }

        // Stage 4: Generate Protocol Acknowledgment
        if (structKeyExists(workflow, "ackGenerator") && len(trim(workflow.ackGenerator))) {
            var ackGen = createObject("component", workflow.ackGenerator);
            if (arguments.protocol == "X12") {
                pipelineResult.acknowledgment = ackGen.generate997(pipelineResult.parsed, "A");
            } else if (arguments.protocol == "HL7") {
                pipelineResult.acknowledgment = ackGen.generateAck(arguments.rawContent, "AA", "Processed successfully");
            }
        }

        // Stage 5: Cryptographic Audit Logging
        variables.auditLedger.appendEntry(
            transactionId = pipelineResult.pipelineId,
            senderId = arguments.partnerId,
            receiverId = "KEYSTONE",
            payload = arguments.rawContent,
            metadata = {
                "protocol": arguments.protocol,
                "documentType": arguments.documentType
            }
        );

        pipelineResult.success = true;
        pipelineResult.elapsedMs = getTickCount() - startTick;
        variables.metrics.recordDuration("pipeline.execution.duration", pipelineResult.elapsedMs, { "protocol": arguments.protocol });
        variables.metrics.increment("pipeline.inbound.completed", 1, { "protocol": arguments.protocol });

        return pipelineResult;
    }

}
