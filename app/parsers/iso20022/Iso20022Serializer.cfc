component extends="app.parsers.base.ISerializer" {

    /**
     * Constructor for Iso20022Serializer.
     */
    public any function init() {
        super.init();
        return this;
    }

    /**
     * Serializes ISO 20022 AST into canonical XML wire representation.
     */
    public string function serialize(required struct ast, struct options = {}) {
        var msgType = arguments.ast.messageType ?: "pain.001.001.09";
        var isPacs008 = (findNoCase("pacs.008", msgType) > 0);
        var ns = isPacs008 ? "urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08" : "urn:iso:std:iso:20022:tech:xsd:pain.001.001.09";
        var rootElem = isPacs008 ? "FIToFICstmrCdtTrf" : "CstmrCdtTrfInitn";

        var sb = createObject("java", "java.lang.StringBuilder").init();
        sb.append('<?xml version="1.0" encoding="UTF-8"?>').append(chr(10));
        sb.append('<Document xmlns="').append(ns).append('">').append(chr(10));
        sb.append('  <').append(rootElem).append('>').append(chr(10));

        // Group Header
        var gh = arguments.ast.groupHeader ?: {};
        sb.append('    <GrpHdr>').append(chr(10));
        sb.append('      <MsgId>').append(xmlFormat(gh.messageId ?: createUUID())).append('</MsgId>').append(chr(10));
        sb.append('      <CreDtTm>').append(xmlFormat(gh.creationDateTime ?: dateTimeFormat(now(), "yyyy-mm-dd'T'HH:nn:ss"))).append('</CreDtTm>').append(chr(10));
        sb.append('      <NbOfTxs>').append(arrayLen(arguments.ast.transactions ?: [])).append('</NbOfTxs>').append(chr(10));
        if (len(trim(gh.initiatingParty ?: ""))) {
            sb.append('      <InitgPty><Nm>').append(xmlFormat(gh.initiatingParty)).append('</Nm></InitgPty>').append(chr(10));
        }
        sb.append('    </GrpHdr>').append(chr(10));

        // Payment Information / Transactions
        var txs = arguments.ast.transactions ?: [];
        if (!isPacs008) {
            sb.append('    <PmtInf>').append(chr(10));
            sb.append('      <PmtInfId>PMT-').append(createUUID()).append('</PmtInfId>').append(chr(10));
            sb.append('      <PmtMtd>TRF</PmtMtd>').append(chr(10));
        }

        for (var tx in txs) {
            sb.append('      <CdtTrfTxInf>').append(chr(10));
            sb.append('        <PmtId>').append(chr(10));
            sb.append('          <EndToEndId>').append(xmlFormat(tx.paymentId ?: createUUID())).append('</EndToEndId>').append(chr(10));
            sb.append('        </PmtId>').append(chr(10));

            var ccy = tx.currency ?: "USD";
            var amt = tx.amount ?: "0.00";
            sb.append('        <Amt>').append(chr(10));
            sb.append('          <InstdAmt Ccy="').append(ccy).append('">').append(amt).append('</InstdAmt>').append(chr(10));
            sb.append('        </Amt>').append(chr(10));

            // Debtor
            sb.append('        <Dbtr><Nm>').append(xmlFormat(tx.debtor ?: "Debtor")).append('</Nm></Dbtr>').append(chr(10));
            if (len(trim(tx.debtorIban ?: ""))) {
                sb.append('        <DbtrAcct><Id><IBAN>').append(xmlFormat(tx.debtorIban)).append('</IBAN></Id></DbtrAcct>').append(chr(10));
            }
            if (len(trim(tx.debtorBic ?: ""))) {
                sb.append('        <DbtrAgt><FinInstnId><BICFI>').append(xmlFormat(tx.debtorBic)).append('</BICFI></FinInstnId></DbtrAgt>').append(chr(10));
            }

            // Creditor
            sb.append('        <Cdtr><Nm>').append(xmlFormat(tx.creditor ?: "Creditor")).append('</Nm></Cdtr>').append(chr(10));
            if (len(trim(tx.creditorIban ?: ""))) {
                sb.append('        <CdtrAcct><Id><IBAN>').append(xmlFormat(tx.creditorIban)).append('</IBAN></Id></CdtrAcct>').append(chr(10));
            }
            if (len(trim(tx.creditorBic ?: ""))) {
                sb.append('        <CdtrAgt><FinInstnId><BICFI>').append(xmlFormat(tx.creditorBic)).append('</BICFI></FinInstnId></CdtrAgt>').append(chr(10));
            }

            // Remittance Info
            if (len(trim(tx.remittanceInfo ?: ""))) {
                sb.append('        <RmtInf><Ustrd>').append(xmlFormat(tx.remittanceInfo)).append('</Ustrd></RmtInf>').append(chr(10));
            }

            sb.append('      </CdtTrfTxInf>').append(chr(10));
        }

        if (!isPacs008) {
            sb.append('    </PmtInf>').append(chr(10));
        }

        sb.append('  </').append(rootElem).append('>').append(chr(10));
        sb.append('</Document>').append(chr(10));

        return sb.toString();
    }
}
