/**
 * Keystone B2B Transaction Mesh - Trading Partner Agreement Manager
 *
 * Manages contractual B2B transaction parameters, including document types, schemas,
 * translation mappings, acknowledgment policies, and encryption requirements.
 */
component {

    property name="storageDir" type="string";
    property name="agreements" type="struct";
    property name="lockName" type="string";

    /**
     * Initializes the AgreementManager.
     */
    public any function init(string storageDir = "storage/agreements") {
        variables.storageDir = arguments.storageDir;
        variables.agreements = {};
        variables.lockName = "keystone_agreement_manager_lock";

        ensureDirectory();
        loadAll();

        return this;
    }

    private void function ensureDirectory() {
        if (!directoryExists(variables.storageDir)) {
            directoryCreate(variables.storageDir);
        }
    }

    private void function loadAll() {
        var files = directoryList(variables.storageDir, false, "query", "*.json");
        for (var f in files) {
            try {
                var content = fileRead(f.directory & "/" & f.name, "utf-8");
                var agr = deserializeJson(content);
                variables.agreements[agr.id] = agr;
            } catch (any e) {
                // Ignore transient read error
            }
        }
    }

    /**
     * Registers a new trading partner agreement.
     */
    public struct function registerAgreement(required struct agreement) {
        if (!structKeyExists(arguments.agreement, "id") || len(trim(arguments.agreement.id)) == 0) {
            arguments.agreement.id = "AGR_" & createUUID();
        }

        var a = duplicate(arguments.agreement);
        if (!structKeyExists(a, "partnerId")) throw(type="InvalidAgreementException", message="Partner ID is required");
        if (!structKeyExists(a, "documentType")) throw(type="InvalidAgreementException", message="Document type is required");
        if (!structKeyExists(a, "direction")) a.direction = "INBOUND"; // INBOUND or OUTBOUND
        if (!structKeyExists(a, "version")) a.version = "004010";
        if (!structKeyExists(a, "mappingTemplate")) a.mappingTemplate = "";
        if (!structKeyExists(a, "ackExpected")) a.ackExpected = true;
        if (!structKeyExists(a, "signRequired")) a.signRequired = false;
        if (!structKeyExists(a, "encryptRequired")) a.encryptRequired = false;
        if (!structKeyExists(a, "active")) a.active = true;
        a.updatedAt = now();

        var filePath = variables.storageDir & "/" & a.id & ".json";
        lock name="#variables.lockName#_#a.id#" type="exclusive" timeout="10" {
            variables.agreements[a.id] = a;
            fileWrite(filePath, serializeJson(a), "utf-8");
        }

        return a;
    }

    /**
     * Retrieves an agreement by identifier.
     */
    public struct function getAgreement(required string agreementId) {
        if (!structKeyExists(variables.agreements, arguments.agreementId)) {
            throw(type="AgreementNotFoundException", message="Agreement [#arguments.agreementId#] not found");
        }
        return variables.agreements[arguments.agreementId];
    }

    /**
     * Finds matching agreement for partner, document type, and direction.
     */
    public struct function findAgreement(
        required string partnerId,
        required string documentType,
        string direction = "INBOUND"
    ) {
        for (var id in variables.agreements) {
            var a = variables.agreements[id];
            if (a.partnerId == arguments.partnerId &&
                a.documentType == arguments.documentType &&
                uCase(a.direction) == uCase(arguments.direction) &&
                a.active) {
                return a;
            }
        }
        throw(type="AgreementNotFoundException", message="No active agreement found for partner [#arguments.partnerId#], document [#arguments.documentType#], direction [#arguments.direction#]");
    }

    /**
     * Lists all agreements for a partner or all partners.
     */
    public array function listAgreements(string partnerId = "", boolean activeOnly = true) {
        var list = [];
        for (var id in variables.agreements) {
            var a = variables.agreements[id];
            if ((len(trim(arguments.partnerId)) == 0 || a.partnerId == arguments.partnerId) &&
                (!arguments.activeOnly || a.active)) {
                arrayAppend(list, a);
            }
        }
        return list;
    }

}
