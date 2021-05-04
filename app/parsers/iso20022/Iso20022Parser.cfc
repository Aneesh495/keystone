component extends="app.parsers.base.IParser" {

    /**
     * Constructor for Iso20022Parser.
     */
    public any function init() {
        super.init();
        return this;
    }

    public boolean function canParse(required string rawInput) {
        var trimmed = trim(arguments.rawInput);
        return findNoCase("<Document", trimmed) > 0 && (findNoCase("pain.001", trimmed) > 0 || findNoCase("pacs.008", trimmed) > 0 || findNoCase("camt.053", trimmed) > 0);
    }

    /**
     * Parses ISO 20022 XML document into standardized AST.
     */
    public any function parse(required string rawInput, struct options = {}) {
        var result = new app.parsers.base.ParseResult();
        var xmlDoc = nullValue();

        try {
            xmlDoc = xmlParse(arguments.rawInput);
        } catch (any e) {
            result.addError("Malformed ISO 20022 XML document: " & e.message, "XML_SYNTAX_ERROR");
            return result;
        }

        var rootNode = xmlDoc.xmlRoot;
        var rootName = rootNode.xmlName;
        var namespaceUri = structKeyExists(rootNode.xmlAttributes, "xmlns") ? rootNode.xmlAttributes["xmlns"] : "";

        // Detect message type from namespace or root children
        var msgType = detectMessageType(rootNode, namespaceUri);

        var ast = {
            "format": "ISO20022",
            "messageType": msgType,
            "namespace": namespaceUri,
            "rootName": rootName,
            "groupHeader": {},
            "transactions": [],
            "rawXml": arguments.rawInput
        };

        // Extract Group Header if present
        var grpHdrNodes = xmlSearch(xmlDoc, "//*[local-name()='GrpHdr']");
        if (arrayLen(grpHdrNodes) > 0) {
            var g = grpHdrNodes[1];
            ast.groupHeader = {
                "messageId": extractNodeText(g, "MsgId"),
                "creationDateTime": extractNodeText(g, "CreDtTm"),
                "numberOfTransactions": extractNodeText(g, "NbOfTxs"),
                "controlSum": extractNodeText(g, "CtrlSum"),
                "initiatingParty": extractNodeText(g, "InitgPty/Nm")
            };
        }

        // Extract Credit Transfer transactions (pain.001 / pacs.008)
        var txNodes = xmlSearch(xmlDoc, "//*[local-name()='CdtTrfTxInf']");
        for (var txNode in txNodes) {
            var txStruct = {
                "paymentId": extractNodeText(txNode, "PmtId/EndToEndId"),
                "instructionId": extractNodeText(txNode, "PmtId/InstrId"),
                "amount": extractNodeText(txNode, "Amt/InstdAmt"),
                "currency": extractNodeAttr(txNode, "Amt/InstdAmt", "Ccy"),
                "debtor": extractNodeText(txNode, "Dbtr/Nm"),
                "debtorIban": extractNodeText(txNode, "DbtrAcct/Id/IBAN"),
                "debtorBic": extractNodeText(txNode, "DbtrAgt/FinInstnId/BICFI"),
                "creditor": extractNodeText(txNode, "Cdtr/Nm"),
                "creditorIban": extractNodeText(txNode, "CdtrAcct/Id/IBAN"),
                "creditorBic": extractNodeText(txNode, "CdtrAgt/FinInstnId/BICFI"),
                "remittanceInfo": extractNodeText(txNode, "RmtInf/Ustrd")
            };
            arrayAppend(ast.transactions, txStruct);
        }

        result.setAst(ast);
        result.setMetadata({
            "messageType": msgType,
            "messageId": ast.groupHeader.messageId ?: "",
            "transactionCount": arrayLen(ast.transactions)
        });

        return result;
    }

    private string function detectMessageType(required any rootNode, required string namespaceUri) {
        if (findNoCase("pain.001", arguments.namespaceUri) || structKeyExists(arguments.rootNode, "CstmrCdtTrfInitn")) {
            return "pain.001.001.09";
        }
        if (findNoCase("pacs.008", arguments.namespaceUri) || structKeyExists(arguments.rootNode, "FIToFICstmrCdtTrf")) {
            return "pacs.008.001.08";
        }
        if (findNoCase("camt.053", arguments.namespaceUri) || structKeyExists(arguments.rootNode, "BkToCstmrStmt")) {
            return "camt.053.001.08";
        }
        return "ISO20022.GENERIC";
    }

    private string function extractNodeText(required any parentNode, required string path) {
        var parts = listToArray(arguments.path, "/");
        var curr = arguments.parentNode;

        for (var p in parts) {
            var found = false;
            for (var child in curr.xmlChildren) {
                if (child.xmlName == p || (find(":", child.xmlName) > 0 && listLast(child.xmlName, ":") == p)) {
                    curr = child;
                    found = true;
                    break;
                }
            }
            if (!found) {
                return "";
            }
        }

        return trim(curr.xmlText);
    }

    private string function extractNodeAttr(required any parentNode, required string path, required string attrName) {
        var parts = listToArray(arguments.path, "/");
        var curr = arguments.parentNode;

        for (var p in parts) {
            var found = false;
            for (var child in curr.xmlChildren) {
                if (child.xmlName == p || (find(":", child.xmlName) > 0 && listLast(child.xmlName, ":") == p)) {
                    curr = child;
                    found = true;
                    break;
                }
            }
            if (!found) {
                return "";
            }
        }

        return structKeyExists(curr.xmlAttributes, arguments.attrName) ? curr.xmlAttributes[arguments.attrName] : "";
    }
}
