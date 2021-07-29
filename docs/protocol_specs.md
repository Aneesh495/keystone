# Keystone Protocol Specifications and Interchange Standards

This document specifies the technical grammar, delimiter state machines, validation rules, and structural parsing mechanics implemented across all supported B2B interchange protocols within Keystone.

---

## 1. ANSI ASC X12 Specification

### 1.1 Envelope Structure and Control Hierarchy

X12 interchanges maintain a strict three-tier envelope hierarchy:
1. **Interchange Control Envelope**: Delimited by `ISA` (Header) and `IEA` (Trailer). Control number must match between ISA13 and IEA02.
2. **Functional Group Envelope**: Delimited by `GS` (Header) and `GE` (Trailer). Control number must match between GS06 and GE02. Functional group count in GE01 must match the number of transaction sets.
3. **Transaction Set Envelope**: Delimited by `ST` (Header) and `SE` (Trailer). Control number must match between ST02 and SE02. Segment count in SE01 must equal the total number of segments including ST and SE.

```
+------------------------------------------------------------------------+
| ISA: Interchange Control Header (Fixed 106 Characters)                 |
|   +------------------------------------------------------------------+ |
|   | GS: Functional Group Header (e.g. PO, IN, HP)                    | |
|   |   +------------------------------------------------------------+ | |
|   |   | ST: Transaction Set Header (e.g. 850, 855, 837)            | | |
|   |   |   [Transaction Set Body Segments...]                       | | |
|   |   | SE: Transaction Set Trailer                                | | |
|   |   +------------------------------------------------------------+ | |
|   | GE: Functional Group Trailer                                     | |
|   +------------------------------------------------------------------+ |
| IEA: Interchange Control Trailer                                       |
+------------------------------------------------------------------------+
```

### 1.2 Fixed-Width ISA Header and Delimiter Detection

The `ISA` header is exactly 106 characters in length. Keystone inspects the raw stream to automatically detect interchange delimiters:
- **Element Delimiter**: Character index 4 (default: `*`).
- **Component Sub-Element Delimiter**: Character index 105 (default: `:` or `>`).
- **Segment Terminator**: Character index 106 (default: `~` or newline).
- **Repetition Separator**: In X12 version 005010 and later, character index 83 represents the repetition separator if non-alphanumeric. In version 004010, position 83 is the standard identifier code (`U`), and the repetition delimiter defaults to `^`.

### 1.3 Validation Engine Rules

The `X12Validator` executes the following checks:
- Mandatory segments presence: ISA, IEA, GS, GE, ST, SE.
- Envelope control number equality (ISA13 == IEA02, GS06 == GE02, ST02 == SE02).
- Counts verification: SE01 equals segment count, GE01 equals transaction set count, IEA01 equals functional group count.
- Standard transaction set schema compliance (mandatory segments, segment order, element minimum/maximum lengths).

### 1.4 Functional Acknowledgments (997 and 999)

Keystone generates ANSI X12 997 and 999 Functional Acknowledgments in response to inbound interchanges:
- `AK1`: Functional group response header referencing GS01 and GS06.
- `AK2`: Transaction set response header referencing ST01 and ST02.
- `AK3` and `AK4`: Detailed segment and data element syntax error indicators if errors occurred.
- `AK5`: Transaction set acknowledgment status (`A` = Accepted, `E` = Accepted with Errors, `R` = Rejected).
- `AK9`: Functional group acknowledgment status and accepted transaction set count.

---

## 2. UN/EDIFACT Specification

### 2.1 Interchange Envelope and UNA Service String Advice

UN/EDIFACT messages begin either with a conditional `UNA` Service String Advice (9 characters) or directly with a `UNB` Interchange Header:
- `UNA` format: `UNA:+.? '`
  - Position 4: Component data element separator (`:`)
  - Position 5: Data element separator (`+`)
  - Position 6: Decimal mark (`.` or `,`)
  - Position 7: Release character (`?`)
  - Position 8: Reserved space character
  - Position 9: Segment terminator (`'`)

### 2.2 Release Character Escaping Mechanics

When a delimiter character occurs inside data content, it must be escaped using the release character (`?`):
- `?+` represents a literal plus character.
- `?:` represents a literal colon character.
- `??` represents a literal question mark character.
- `?'` represents a literal quote / segment terminator.

The Keystone `EdifactLexer` implements an escape-aware lookahead state machine that handles escaped delimiters without prematurely splitting tokens or stripping valid data characters.

### 2.3 CONTRL Functional Acknowledgment

In response to EDIFACT interchanges, Keystone synthesizes `CONTRL` message sets:
- `UCI`: Interchange response referencing UNB sender, receiver, and interchange control reference.
- `UCM`: Message response referencing UNH reference and message status code (`7` = Acknowledged, `4` = Rejected).

---

## 3. HL7 Version 2.x and FHIR R4 Specification

### 3.1 MSH Header and Delimiter Definition

HL7 v2 messages are pipe-delimited segment streams terminated by carriage return (`\r`) or line feed (`\n`). Delimiters are declared in the `MSH` header:
- `MSH-1`: Field Separator (`|`).
- `MSH-2`: Encoding Characters (`^~\&`):
  - Component Separator (`^`)
  - Repetition Separator (`~`)
  - Escape Character (`\`)
  - Subcomponent Separator (`&`)

### 3.2 Minimal Lower Layer Protocol (MLLP) Framing

When transmitted over TCP raw sockets, HL7 v2 messages are framed using RFC 2553 / MLLP:
- **Start Block Character**: `0x0B` (`<VT>`, Vertical Tab).
- **Payload Data**: Raw HL7 ASCII / UTF-8 string.
- **End Block Characters**: `0x1C` (`<FS>`, File Separator) followed by `0x0D` (`<CR>`, Carriage Return).

Keystone implements `app.network.MllpServer` with full non-blocking socket handling, reading until the `0x1C 0x0D` trailer and immediately responding with an MLLP-framed `ACK` message.

### 3.3 Bidirectional FHIR R4 Conversion

Keystone provides semantic conversion between legacy HL7 v2 and HL7 FHIR R4 JSON resources:
- `ADT^A01` / `ADT^A08` maps to FHIR `Bundle` containing `Patient` and `Encounter` resources.
- `ORU^R01` maps to FHIR `Bundle` containing `Patient`, `Observation`, and `DiagnosticReport` resources.
- PID segment fields map to `Patient.identifier`, `Patient.name`, `Patient.telecom`, `Patient.gender`, `Patient.birthDate`, and `Patient.address`.
- OBX segments map to `Observation.code`, `Observation.valueQuantity`, `Observation.valueString`, and `Observation.referenceRange`.

---

## 4. ISO 20022 XML Specification

### 4.1 Schema Definitions and Namespaces

Keystone parses, validates, and serializes financial messages defined under the ISO 20022 Universal Financial Industry Message Scheme:
- **pain.001.001.09**: Customer Credit Transfer Initiation (`urn:iso:std:iso:20022:tech:xsd:pain.001.001.09`). Used for corporate payment originations, vendor disbursements, and payroll files.
- **pacs.008.001.10**: Financial Institutional Customer Credit Transfer (`urn:iso:std:iso:20022:tech:xsd:pacs.008.001.10`). Used for interbank financial clearing and settlement across FedNow, SEPA, and CHIPS.

### 4.2 Financial Identifiers and Validation

The `Iso20022Validator` enforces strict regulatory format validation:
- **IBAN (International Bank Account Number)**: Validates ISO 13616 format with country code prefix, length check (15 to 34 characters), and MOD-97-10 checksum validation (ISO 7064).
- **BIC / SWIFT Code**: Validates ISO 9362 8-character or 11-character format (`^[A-Z]{6}[A-Z0-9]{2}([A-Z0-9]{3})?$`).
- **Control Sum and Number of Transactions**: Ensures `NbOfTxs` matches the total transactions in `GrpHdr`, and `CtrlSum` matches the arithmetic sum of `InstdAmt` values.

---

## 5. Positional Flat File and CSV Specification

### 5.1 Fixed-Width Engine

The `FlatFileParser` reads continuous records against a layout specification dictionary:
- Each field specifies `name`, `start` (1-based index), `length`, `type` (`string`, `numeric`, `date`), and `padding` (`left`, `right`).
- Serialization pads strings with spaces and numeric fields with leading zeroes to maintain columnar integrity.

### 5.2 RFC 4180 CSV Engine

The CSV parser complies with RFC 4180:
- Fields containing commas, newlines, or quotes are enclosed in double quotes.
- Internal double quotes are escaped as two consecutive double quotes (`""`).
- Header row detection automatically builds keyed record structs.
