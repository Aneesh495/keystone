# Keystone Transformation DSL and Mapping Manual

## 1. Declarative Semantic Mapping Overview

Heterogeneous B2B protocols represent identical business concepts using wildly divergent schemas:
- A Purchase Order in X12 uses `BEG*00*SA*PO-90112**20261102~`.
- In UN/EDIFACT, it is represented as `BGM+220+PO-90112+9'`.
- In a modern microservices ERP, it is represented as JSON `{"orderId": "PO-90112", "orderDate": "2026-11-02"}`.

Keystone bridges these representations through a unified declarative Transformation Hypervisor (`app.transform.SchemaMapper`).

---

## 2. ExpressionEngine Specification

The `ExpressionEngine` is a lightweight, sandboxed abstract syntax tree (AST) evaluator designed for mapping expressions without exposing the host JVM or CFML runtime to arbitrary code execution risks.

### 2.1 Supported Operators and Literals

- **Literals**: Strings (`"USD"`), numbers (`42.50`), booleans (`true`, `false`), and null values.
- **Identifiers & Context Lookups**: Variable references (`item.quantity`, `header.senderId`).
- **Binary Operators**: Addition (`+`), subtraction (`-`), multiplication (`*`), division (`/`), modulo (`%`).
- **Comparison Operators**: `==`, `!=`, `<`, `<=`, `>`, `>=`.
- **Logical Operators**: `&&`, `||`, `!`.
- **Ternary Operator**: `condition ? trueBranch : falseBranch`.

### 2.2 Built-in Function Library

- `toIsoDate(dateStr, format)`: Converts EDI dates (`YYYYMMDD` or `YYMMDD`) to standard ISO 8601 (`YYYY-MM-DD`).
- `toEdiDate(isoDateStr, format)`: Converts ISO 8601 dates to EDI date strings.
- `mapUom(code)`: Translates legacy ANSI unit-of-measure codes (`EA`, `CA`, `BX`, `FT`, `KG`) to canonical units (`EACH`, `CASE`, `BOX`, `FOOT`, `KILOGRAM`).
- `lookup(tableName, code, defaultVal)`: Resolves partner codes against the `CodeLookupTable`.
- `padLeft(str, len, char)`: Formats fixed-width numbers with leading zeroes.
- `padRight(str, len, char)`: Formats fixed-width alphanumeric strings with trailing spaces.
- `trim(str)`: Trims leading and trailing whitespace.
- `upper(str)` and `lower(str)`: Case normalization.

---

## 3. Code Lookup Tables

Enterprise partners frequently utilize proprietary or legacy codes that must be mapped to internal canonical representations.

Keystone implements `app.transform.CodeLookupTable`:
```json
{
  "UNIT_OF_MEASURE": {
    "EA": "EACH",
    "CA": "CASE",
    "BX": "BOX",
    "PC": "PIECE"
  },
  "CARRIER_CODES": {
    "UPSN": "UPS",
    "FDEN": "FEDEX",
    "ODFL": "OLD_DOMINION"
  },
  "ORDER_STATUS": {
    "00": "ORIGINAL",
    "01": "CANCELLATION",
    "04": "CHANGE"
  }
}
```

Tables support bidirectional lookups (`lookup` and `reverseLookup`) with thread-safe atomic reloading.

---

## 4. Production Mapping Templates

### 4.1 Inbound X12 850 PO to Canonical Orders JSON

The `app.transform.templates.X12_850_To_OrdersJson` component transforms an X12 850 AST into a clean canonical JSON struct:
- Extracts ISA sender/receiver credentials.
- Parses `BEG` segment to obtain order number and date.
- Maps `CUR` segment for monetary currency.
- Iterates over `N1/N3/N4` loops to extract Ship-To and Bill-To addresses.
- Iterates over `PO1` item loops to synthesize structured line item arrays with quantity, price, SKU, and description.
- Computes aggregated summary metrics (total item lines, total quantity, total monetary order value).

### 4.2 Outbound Canonical Orders JSON to X12 855 PO Acknowledgment

The `app.transform.templates.OrdersJson_To_X12_855` component performs reverse serialization:
- Generates outbound `ISA` and `GS` envelopes with configured sender/receiver identifiers and control numbers.
- Emits `ST*855` and `BAK` segments acknowledging purchase order acceptance or rejection.
- Synthesizes `PO1` and `ACK` line item segments reflecting scheduled delivery dates and accepted quantities.
- Calculates segment counts in `SE01` and closes `GE` and `IEA` envelopes.
