component {

    property name="storageDir" type="string";
    property name="crypto" type="any";
    property name="logger" type="any";
    property name="blocks" type="array";
    property name="ledgerFile" type="string";

    variables.GENESIS_HASH = "0000000000000000000000000000000000000000000000000000000000000000";

    /**
     * Constructor for AuditLedger.
     */
    public any function init(required string storageDir, required any crypto, required any logger) {
        variables.storageDir = arguments.storageDir;
        variables.crypto = arguments.crypto;
        variables.logger = arguments.logger;
        variables.blocks = [];
        variables.ledgerFile = variables.storageDir & "/audit_chain.jsonl";

        if (!directoryExists(variables.storageDir)) {
            directoryCreate(variables.storageDir);
        }

        loadLedgerFromDisk();
        return this;
    }

    /**
     * Appends a new transaction block to the tamper-evident cryptographic ledger.
     */
    public struct function recordTransaction(
        required string txId,
        required string partnerId,
        required string direction,
        required string protocol,
        required string payload,
        string mic = ""
    ) {
        var block = {};
        lock name="keystone_audit_ledger_lock" type="exclusive" timeout="5" {
            var blockIdx = arrayLen(variables.blocks) + 1;
            var prevHash = (blockIdx == 1) ? variables.GENESIS_HASH : variables.blocks[blockIdx - 1].blockHash;
            var payloadHash = variables.crypto.sha256Hex(arguments.payload);
            var timestamp = dateTimeFormat(now(), "yyyy-mm-dd'T'HH:nn:ss.l'Z'");

            var blockContent = blockIdx & "|" & timestamp & "|" & arguments.txId & "|" & arguments.partnerId & "|" & arguments.direction & "|" & arguments.protocol & "|" & payloadHash & "|" & prevHash;
            var blockHash = variables.crypto.sha256Hex(blockContent);

            block = {
                "blockIndex": blockIdx,
                "timestamp": timestamp,
                "txId": arguments.txId,
                "partnerId": arguments.partnerId,
                "direction": arguments.direction,
                "protocol": arguments.protocol,
                "payloadHash": payloadHash,
                "mic": arguments.mic,
                "previousBlockHash": prevHash,
                "blockHash": blockHash
            };

            arrayAppend(variables.blocks, block);

            // Append to disk journal
            try {
                fileAppend(variables.ledgerFile, serializeJson(block) & chr(10), "utf-8");
            } catch (any e) {
                // ignore file append error
            }
        }

        return block;
    }

    /**
     * Cryptographically verifies the entire Merkle ledger chain from genesis to tip.
     *
     * @return Struct containing 'isValid', 'verifiedBlocks', and 'compromisedBlockIndex'
     */
    public struct function verifyChain() {
        lock name="keystone_audit_ledger_lock" type="readOnly" timeout="5" {
            var total = arrayLen(variables.blocks);
            if (total == 0) {
                return {"isValid": true, "verifiedBlocks": 0, "compromisedBlockIndex": 0};
            }

            for (var i = 1; i <= total; i++) {
                var b = variables.blocks[i];

                // 1. Check index
                if (b.blockIndex != i) {
                    return {"isValid": false, "verifiedBlocks": i - 1, "compromisedBlockIndex": i, "reason": "Index mismatch"};
                }

                // 2. Check previous hash pointer
                var expectedPrevHash = (i == 1) ? variables.GENESIS_HASH : variables.blocks[i - 1].blockHash;
                if (b.previousBlockHash != expectedPrevHash) {
                    return {"isValid": false, "verifiedBlocks": i - 1, "compromisedBlockIndex": i, "reason": "Broken previous hash pointer"};
                }

                // 3. Recompute block hash
                var blockContent = b.blockIndex & "|" & b.timestamp & "|" & b.txId & "|" & b.partnerId & "|" & b.direction & "|" & b.protocol & "|" & b.payloadHash & "|" & b.previousBlockHash;
                var recomputedHash = variables.crypto.sha256Hex(blockContent);

                if (b.blockHash != recomputedHash) {
                    return {"isValid": false, "verifiedBlocks": i - 1, "compromisedBlockIndex": i, "reason": "Tampered block payload hash mismatch"};
                }
            }

            return {"isValid": true, "verifiedBlocks": total, "compromisedBlockIndex": 0};
        }
    }

    public struct function verifyIntegrity() {
        var res = verifyChain();
        return { "valid": res.isValid, "details": res };
    }

    public array function getBlocks(numeric limit = 100) {
        var res = [];
        lock name="keystone_audit_ledger_lock" type="readOnly" timeout="2" {
            var total = arrayLen(variables.blocks);
            var start = max(1, total - arguments.limit + 1);
            for (var i = total; i >= start; i--) {
                arrayAppend(res, variables.blocks[i]);
            }
        }
        return res;
    }

    public numeric function getBlockCount() {
        var count = 0;
        lock name="keystone_audit_ledger_lock" type="readOnly" timeout="2" {
            count = arrayLen(variables.blocks);
        }
        return count;
    }

    private void function loadLedgerFromDisk() {
        if (!fileExists(variables.ledgerFile)) return;
        try {
            var lines = listToArray(fileRead(variables.ledgerFile, "utf-8"), chr(10));
            for (var line in lines) {
                if (len(trim(line)) > 0) {
                    var parsed = deserializeJson(line);
                    arrayAppend(variables.blocks, parsed);
                }
            }
        } catch (any e) {
            // disk load fallback
        }
    }
}
