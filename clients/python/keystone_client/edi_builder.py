"""
Keystone Client Synthetic EDI & Protocol Payload Builder
Generates syntactically conformant ASC X12, UN/EDIFACT, HL7 v2, and ISO 20022 payloads.
"""

from datetime import datetime
import uuid


class EdiBuilder:
    """Builder utility for creating compliant B2B test documents."""

    @staticmethod
    def build_x12_850(
        sender_id: str = "PARTNERA",
        receiver_id: str = "KEYSTONEGATE",
        po_number: str = "PO-10091",
        item_qty: int = 100,
        unit_price: float = 24.50,
        control_num: str = "000000001",
    ) -> str:
        """Constructs an ANSI ASC X12 850 Purchase Order document string."""
        now = datetime.utcnow()
        date_short = now.strftime("%y%m%d")
        date_long = now.strftime("%Y%m%d")
        time_short = now.strftime("%H%M")

        isa_sender = f"{sender_id:<15}"
        isa_receiver = f"{receiver_id:<15}"

        return (
            f"ISA*00*          *00*          *ZZ*{isa_sender}*ZZ*{isa_receiver}*{date_short}*{time_short}*U*00401*{control_num}*0*P*>~\n"
            f"GS*PO*{sender_id}*{receiver_id}*{date_long}*{time_short}*1*X*004010~\n"
            f"ST*850*0001~\n"
            f"BEG*00*SA*{po_number}**{date_long}~\n"
            f"CUR*BY*USD~\n"
            f"N1*BT*ACME CORP*91*DUNS123456789~\n"
            f"PO1*1*{item_qty}*EA*{unit_price:.2f}**VN*SKU-9921~\n"
            f"CTT*1~\n"
            f"SE*7*0001~\n"
            f"GE*1*1~\n"
            f"IEA*1*{control_num}~"
        )

    @staticmethod
    def build_edifact_orders(
        sender_id: str = "PARTNERB",
        receiver_id: str = "KEYSTONEGATE",
        order_number: str = "ORD-4402",
        item_qty: int = 250,
    ) -> str:
        """Constructs a UN/EDIFACT D.96A ORDERS Purchase Order document string."""
        now = datetime.utcnow()
        date_short = now.strftime("%y%m%d")
        date_long = now.strftime("%Y%m%d")
        time_short = now.strftime("%H%M")

        return (
            f"UNB+UNOA:2+{sender_id}:ZZ+{receiver_id}:ZZ+{date_short}:{time_short}+REF0001'\n"
            f"UNH+MSG001+ORDERS:D:96A:UN'\n"
            f"BGM+220+{order_number}+9'\n"
            f"DTM+137:{date_long}:102'\n"
            f"NAD+BY+BUYER_ID::9'\n"
            f"LIN+1++ITEM-9988:EN'\n"
            f"QTY+21:{item_qty}'\n"
            f"UNS+S'\n"
            f"UNT+7+MSG001'\n"
            f"UNZ+1+REF0001'"
        )

    @staticmethod
    def build_hl7_adt(
        patient_id: str = "PAT-98442",
        last_name: str = "DOE",
        first_name: str = "JANE",
        dob: str = "19850412",
        gender: str = "F",
    ) -> str:
        """Constructs an HL7 v2.x ADT A01 Patient Admission message."""
        now = datetime.utcnow()
        ts = now.strftime("%Y%m%d%H%M%S")
        msg_ctrl = f"MSG{uuid.uuid4().hex[:8].upper()}"

        return (
            f"MSH|^~\\&|HOSPITAL_SYS|METRO_HEALTH|KEYSTONE_GATE|GATEWAY|{ts}||ADT^A01|{msg_ctrl}|P|2.5\r"
            f"EVN|A01|{ts}\r"
            f"PID|1||{patient_id}^^^HOSPITAL^MR||{last_name}^{first_name}||{dob}|{gender}|||123 MAIN ST^^SPRINGFIELD^IL^62701\r"
            f"PV1|1|I|MED^ROOM102^BED1||||1234^ATTENDING^DOC||||||||||ADM|{ts}"
        )

    @staticmethod
    def build_iso20022_pain001(
        msg_id: str = "PAIN-001-992",
        debtor_name: str = "GLOBAL LOGISTICS INC",
        creditor_name: str = "SUPPLIER ALLIANCE",
        amount: float = 15420.50,
        currency: str = "USD",
    ) -> str:
        """Constructs an ISO 20022 CustomerCreditTransferInitiationV09 (pain.001.001.09) XML string."""
        now = datetime.utcnow()
        ts = now.strftime("%Y-%m-%dT%H:%M:%S")

        return f"""<?xml version="1.0" encoding="UTF-8"?>
<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.001.001.09">
    <CstmrCdtTrfInitn>
        <GrpHdr>
            <MsgId>{msg_id}</MsgId>
            <CreDtTm>{ts}</CreDtTm>
            <NbOfTxs>1</NbOfTxs>
            <CtrlSum>{amount:.2f}</CtrlSum>
            <InitgPty>
                <Nm>{debtor_name}</Nm>
            </InitgPty>
        </GrpHdr>
        <PmtInf>
            <PmtInfId>PMT-INFO-001</PmtInfId>
            <PmtMtd>TRF</PmtMtd>
            <ReqdExctnDt>{now.strftime("%Y-%m-%d")}</ReqdExctnDt>
            <Dbtr>
                <Nm>{debtor_name}</Nm>
            </Dbtr>
            <CdtTrfTxInf>
                <PmtId>
                    <EndToEndId>E2E-REF-7741</EndToEndId>
                </PmtId>
                <Amt>
                    <InstdAmt Ccy="{currency}">{amount:.2f}</InstdAmt>
                </Amt>
                <Cdtr>
                    <Nm>{creditor_name}</Nm>
                </Cdtr>
            </CdtTrfTxInf>
        </PmtInf>
    </CstmrCdtTrfInitn>
</Document>"""
