/**
 * Keystone B2B Transaction Mesh - Workflow Pipeline Registry
 *
 * Resolves end-to-end processing pipelines linking inbound/outbound document formats
 * to parsers, validators, schema mappers, and saga orchestration coordinators.
 */
component {

    property name="workflows" type="struct";

    /**
     * Initializes the WorkflowRegistry with standard enterprise pipelines.
     */
    public any function init() {
        variables.workflows = {};

        registerDefaultPipelines();

        return this;
    }

    /**
     * Registers default out-of-the-box processing pipelines.
     */
    private void function registerDefaultPipelines() {
        // Supply Chain: Inbound X12 850 PO to Order Management
        registerWorkflow("INBOUND_X12_850", {
            "protocol": "X12",
            "documentType": "850",
            "parserClass": "app.parsers.x12.X12Parser",
            "validatorClass": "app.parsers.x12.X12Validator",
            "schemaClass": "app.parsers.x12.schemas.Schema850",
            "mapperClass": "app.transform.templates.X12_850_To_OrdersJson",
            "sagaDefinition": "ORDER_INGESTION_SAGA",
            "ackGenerator": "app.parsers.x12.X12AckGenerator"
        });

        // Supply Chain: Outbound X12 855 PO Acknowledgment
        registerWorkflow("OUTBOUND_X12_855", {
            "protocol": "X12",
            "documentType": "855",
            "parserClass": "",
            "serializerClass": "app.parsers.x12.X12Serializer",
            "schemaClass": "app.parsers.x12.schemas.Schema855",
            "mapperClass": "app.transform.templates.OrdersJson_To_X12_855",
            "sagaDefinition": "ORDER_ACK_DISPATCH_SAGA"
        });

        // Healthcare: Inbound HL7 ADT A01 Admission
        registerWorkflow("INBOUND_HL7_ADT", {
            "protocol": "HL7",
            "documentType": "ADT_A01",
            "parserClass": "app.parsers.hl7.HL7Parser",
            "schemaClass": "app.parsers.hl7.schemas.SchemaADT",
            "converterClass": "app.parsers.hl7.FhirConverter",
            "sagaDefinition": "PATIENT_ADMISSION_SAGA",
            "ackGenerator": "app.parsers.hl7.HL7AckGenerator"
        });

        // Financial: Inbound ISO 20022 Pain.001 Credit Transfer
        registerWorkflow("INBOUND_ISO20022_PAIN001", {
            "protocol": "ISO20022",
            "documentType": "pain.001.001.09",
            "parserClass": "app.parsers.iso20022.Iso20022Parser",
            "validatorClass": "app.parsers.iso20022.Iso20022Validator",
            "schemaClass": "app.parsers.iso20022.schemas.SchemaPain001",
            "sagaDefinition": "PAYMENT_CLEARING_SAGA"
        });
    }

    /**
     * Registers a custom workflow pipeline definition.
     */
    public any function registerWorkflow(required string workflowId, required struct spec) {
        variables.workflows[arguments.workflowId] = arguments.spec;
        return this;
    }

    /**
     * Retrieves a workflow definition by its identifier.
     */
    public struct function getWorkflow(required string workflowId) {
        if (!structKeyExists(variables.workflows, arguments.workflowId)) {
            throw(type="WorkflowNotFoundException", message="Workflow [#arguments.workflowId#] is not registered");
        }
        return variables.workflows[arguments.workflowId];
    }

    /**
     * Resolves the matching workflow pipeline for a given document type and protocol.
     */
    public struct function resolve(required string protocol, required string documentType) {
        var key = uCase(arguments.protocol) & "_" & uCase(arguments.documentType);
        for (var wid in variables.workflows) {
            var wf = variables.workflows[wid];
            if (uCase(wf.protocol) == uCase(arguments.protocol) && uCase(wf.documentType) == uCase(arguments.documentType)) {
                return wf;
            }
        }

        // Check fallback direct key
        if (structKeyExists(variables.workflows, key)) {
            return variables.workflows[key];
        }

        throw(type="WorkflowNotFoundException", message="No workflow resolved for protocol [#arguments.protocol#] and document [#arguments.documentType#]");
    }

    public struct function getAllWorkflows() {
        return variables.workflows;
    }

}
