/**
 * Keystone B2B Transaction Mesh - Partner Registry
 *
 * Manages trading partner identities, AS2 and EDI routing identifiers, public certificates,
 * and communication profiles.
 */
component {

    property name="storageDir" type="string";
    property name="partners" type="struct";
    property name="lockName" type="string";

    /**
     * Initializes the PartnerRegistry.
     */
    public any function init(string storageDir = "storage/partners") {
        variables.storageDir = arguments.storageDir;
        variables.partners = {};
        variables.lockName = "keystone_partner_registry_lock";

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
                var partner = deserializeJson(content);
                variables.partners[partner.id] = partner;
            } catch (any e) {
                // Ignore transient file parse error
            }
        }
    }

    /**
     * Registers or updates a trading partner profile.
     */
    public struct function registerPartner(required struct profile) {
        if (!structKeyExists(arguments.profile, "id") || len(trim(arguments.profile.id)) == 0) {
            arguments.profile.id = "PARTNER_" & createUUID();
        }

        var p = duplicate(arguments.profile);
        if (!structKeyExists(p, "name")) p.name = p.id;
        if (!structKeyExists(p, "as2Id")) p.as2Id = "";
        if (!structKeyExists(p, "ediId")) p.ediId = "";
        if (!structKeyExists(p, "ediQualifier")) p.ediQualifier = "ZZ";
        if (!structKeyExists(p, "active")) p.active = true;
        if (!structKeyExists(p, "certificateAlias")) p.certificateAlias = "";
        if (!structKeyExists(p, "endpoints")) p.endpoints = {};
        p.updatedAt = now();

        var filePath = variables.storageDir & "/" & p.id & ".json";
        lock name="#variables.lockName#_#p.id#" type="exclusive" timeout="10" {
            variables.partners[p.id] = p;
            fileWrite(filePath, serializeJson(p), "utf-8");
        }

        return p;
    }

    /**
     * Retrieves a partner by internal identifier.
     */
    public struct function getPartner(required string partnerId) {
        if (!structKeyExists(variables.partners, arguments.partnerId)) {
            throw(type="PartnerNotFoundException", message="Trading partner [#arguments.partnerId#] not found");
        }
        return variables.partners[arguments.partnerId];
    }

    /**
     * Finds a partner by AS2 station identifier.
     */
    public struct function findByAs2Id(required string as2Id) {
        for (var id in variables.partners) {
            var p = variables.partners[id];
            if (p.as2Id == arguments.as2Id && p.active) {
                return p;
            }
        }
        throw(type="PartnerNotFoundException", message="Partner with AS2 ID [#arguments.as2Id#] not found");
    }

    /**
     * Finds a partner by EDI interchange identifier.
     */
    public struct function findByEdiId(required string ediId) {
        for (var id in variables.partners) {
            var p = variables.partners[id];
            if (p.ediId == arguments.ediId && p.active) {
                return p;
            }
        }
        throw(type="PartnerNotFoundException", message="Partner with EDI ID [#arguments.ediId#] not found");
    }

    /**
     * Lists trading partners.
     */
    public array function listPartners(boolean activeOnly = true) {
        var list = [];
        for (var id in variables.partners) {
            var p = variables.partners[id];
            if (!arguments.activeOnly || p.active) {
                arrayAppend(list, p);
            }
        }
        return list;
    }

}
