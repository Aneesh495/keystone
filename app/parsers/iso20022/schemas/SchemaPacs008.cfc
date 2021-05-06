component {

    public any function init() {
        return this;
    }

    public struct function getDefinition() {
        return {
            "messageType": "pacs.008.001.08",
            "name": "Financial Institutional Customer Credit Transfer",
            "businessDomain": "Payments Clearing & Settlement",
            "rootElement": "FIToFICstmrCdtTrf",
            "namespace": "urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08"
        };
    }
}
