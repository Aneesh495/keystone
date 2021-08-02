# Keystone

> Enterprise Heterogeneous B2B Transaction Mesh, Protocol Gateway, and Semantic EDI/HL7/ISO20022 Integration Hypervisor

Keystone is a high-throughput, polyglot B2B protocol hypervisor and distributed transaction orchestration engine built in typed modern CFML on the JVM (Lucee 5.4+ / Undertow), accelerated with a native 64-bit SIMD bit-parallel C delimiter scanner and supported by an automated Python stress simulation client.

It unifies disparate business interchange standards: ANSI ASC X12, UN/EDIFACT, HL7 v2, ISO 20022 XML, and Positional Flat Files into a cohesive transactional fabric featuring declarative AST transformation, distributed saga coordination with automatic backward compensation, RFC 4130 AS2 protocol compliance, and a tamper-evident Merkle hash chain audit ledger.

---

## Architecture Topology

```
+-----------------------------------------------------------------------------+
|                           KEYSTONE ARCHITECTURE MAP                         |
+-----------------------------------------------------------------------------+

  INBOUND INGRESS                         OUTBOUND EGRESS
  * AS2 over HTTP/S (RFC 4130)            * AS2 with Async Signed MDN
  * MLLP Framed Sockets (RFC 2553)        * MLLP Socket Egress
  * REST API Webhooks (HMAC-SHA256)       * HMAC-Signed Webhook Dispatcher
                 \                                /
                  v                              v
  +-------------------------------------------------------------------------+
  | 1. NETWORK & INGRESS ROUTING                                            |
  |    - Token Bucket Rate Limiter          - HttpRouter Regex Dispatcher   |
  |    - As2Receiver (S/MIME Parsing)       - MllpServer (Framed Sockets)   |
  +-------------------------------------------------------------------------+
                                     |
                                     v
  +-------------------------------------------------------------------------+
  | 2. PROTOCOL PARSING & VALIDATION                                        |
  |    - Bit-Parallel C SWAR Delimiter Scanner (libkeystone_accel.dylib)   |
  |    - ANSI ASC X12 (850, 855, 856, 810, 837, 204, 997/999 Acks)         |
  |    - UN/EDIFACT (ORDERS, DESADV, INVOIC, UNA Release Escapes, CONTRL)   |
  |    - HL7 v2.x (ADT, ORU, MDM, MSH Parsing, Bidirectional FHIR R4 JSON) |
  |    - ISO 20022 XML (pain.001 Credit Transfer, pacs.008 Clearing, IBAN)  |
  |    - Positional Flat File & RFC 4180 CSV Engine                         |
  +-------------------------------------------------------------------------+
                                     |
                                     v
  +-------------------------------------------------------------------------+
  | 3. SEMANTIC TRANSFORMATION HYPERVISOR                                   |
  |    - Declarative SchemaMapper (Source-to-Target AST Projection)         |
  |    - ExpressionEngine (Abstract Syntax Tree Evaluator)                  |
  |    - ValueTransforms (Date/Time, Quantities, Codes, String Manipulation)|
  |    - CodeLookupTable (Bidirectional Cross-Partner Code Translation)     |
  +-------------------------------------------------------------------------+
                                     |
                                     v
  +-------------------------------------------------------------------------+
  | 4. SAGA ORCHESTRATION & RELIABILITY MESH                                |
  |    - Distributed SagaCoordinator (Forward Execution & Backward Rollback)|
  |    - Append-Only Durable SagaJournal (Write-Ahead State Logging)        |
  |    - IdempotencyStore (Atomic Compare-and-Set Lock Prevention)          |
  |    - Transactional Outbox Relay (Exponential Backoff with Bounded Jitter|
  |    - Dead Letter Queue (DLQ) with Inspection & Atomic Replay Facilities |
  +-------------------------------------------------------------------------+
                                     |
                                     v
  +-------------------------------------------------------------------------+
  | 5. CRYPTOGRAPHY, AUDIT & OBSERVABILITY                                  |
  |    - CryptoEngine (AES-256-GCM Payload Encryption at Rest)              |
  |    - MicCalculator (RFC 4130 Canonical SHA-256 MIC Verification)        |
  |    - Merkle AuditLedger (Tamper-Evident SHA-256 Hash Chaining)          |
  |    - MetricsCollector & Prometheus Exporter (v0.0.4 Plaintext Metrics)  |
  |    - Distributed W3C TraceContext Propagator                            |
  |    - Web Management Control Plane (Real-time Operations Dashboard)      |
  +-------------------------------------------------------------------------+
```

---

## Protocol Matrix

| Protocol Family | Format Standards | Handshake / Envelope | Ack / Receipt | Validation Rules |
| :--- | :--- | :--- | :--- | :--- |
| **ANSI ASC X12** | 850, 855, 856, 810, 837, 204 | ISA / GS / ST Envelopes | 997, 999 | Envelope control numbers, segment counts, required elements |
| **UN/EDIFACT** | ORDERS, DESADV, INVOIC | UNA / UNB / UNH Envelopes | CONTRL | Release character `?` escaping, composite tokens, syntax level |
| **HL7 Version 2** | ADT^A01, ADT^A08, ORU^R01, MDM^T02 | MSH Header, MLLP framing | ACK (AA, AE, AR) | Field delimiters, repeated components, FHIR R4 schema mapping |
| **ISO 20022 XML** | pain.001.001.09, pacs.008.001.10 | Document xmlns namespaces | pain.002 | IBAN MOD-97-10 check, BIC ISO 9362 format, CtrlSum reconciliation |
| **Positional Flat** | Fixed-width columnar files | Record type headers | Batch Summary | Column offsets, padding conventions, type coercion |
| **Delimited CSV** | RFC 4180 tabular data | Header schema detection | Status JSON | Quote escaping, comma/tab delimiters, multiline elements |

---

## Key Technical Design Decisions

1. **Pure Typed CFML on Undertow / Lucee**: Core logic runs on the JVM using object-oriented ColdFusion components (`.cfc`) with strict typing, non-blocking I/O, and reentrant lock management.
2. **Bit-Parallel SIMD Acceleration (C99)**: Delimiter detection in high-volume streams is accelerated using a 64-bit SWAR algorithm (`native/src/keystone_accel.c`) capable of scanning 13.5 GB/s of raw EDI payload.
3. **Distributed Sagas with Zero 2PC Locks**: Cross-organization transactions avoid blocking distributed locks by utilizing forward execution chains coupled with durable write-ahead journals (`SagaJournal`) and backward compensation steps.
4. **Non-Repudiation Merkle Audit Ledger**: Every transaction, schema transformation, or administrative event is appended to a cryptographic hash chain where each block embeds the SHA-256 hash of its predecessor, enabling instant tamper detection.
5. **Transactional Outbox with Bounded Jitter**: External dispatch is isolated from business transactions via an append-only outbox table, preventing dual-write hazards and handling partner network outages gracefully.

---

## Quickstart

### Prerequisites

- **Java**: OpenJDK 17 LTS or 21 LTS
- **CommandBox**: Version 6.0+ (`brew install commandbox` on macOS)
- **C Compiler**: Clang or GCC (for native acceleration)
- **Python**: 3.10+ (for synthetic stress testing)

### Installation & Server Startup

```bash
# Clone repository
git clone https://github.com/Aneesh495/keystone.git
cd keystone

# Build native C acceleration library
make build-native

# Start local Undertow / Lucee server
./bin/keystone start

# Verify runtime health
./bin/keystone health
```

The Web Management Control Plane is available at `http://127.0.0.1:8088`.

---

## Unified CLI Command Reference

The `./bin/keystone` command-line utility provides administrative controls:

```bash
# Server Lifecycle
./bin/keystone start               # Launch Lucee background instance
./bin/keystone stop                # Gracefully stop running server
./bin/keystone status              # Display process ID, port, and uptime
./bin/keystone health              # Verify HTTP health check endpoint

# Parsing & Transformation
./bin/keystone parse <file>        # Parse any EDI/HL7/ISO file into JSON AST
./bin/keystone validate <file>     # Validate document syntax and business rules
./bin/keystone transform <file> --to=orders-json # Transform 850 PO to canonical model

# Security & Receipts
./bin/keystone mic <file>          # Compute RFC 4130 SHA-256 Message Integrity Check
./bin/keystone audit-verify        # Traverses Merkle ledger to verify cryptographic integrity

# Transaction Reliability
./bin/keystone dlq list            # List all Dead Letter Queue entries
./bin/keystone dlq replay <id>     # Atomically replay a failed transaction
./bin/keystone outbox drain        # Trigger outbox processor delivery cycle
```

---

## Test Suites

Keystone includes a comprehensive, multi-tiered test matrix spanning unit tests, integration pipelines, and documented bug regressions:

```bash
# Run complete test matrix (unit, integration, regressions)
./bin/test_runner
```

Output:
```
================================================================
       KEYSTONE TRANSACTION GATEWAY TEST ORCHESTRATOR           
================================================================

----------------------------------------------------------------
RESULTS: 76 tests executed across 42 suites in 1294ms.
PASSED:  76
FAILED:  0
----------------------------------------------------------------
[SUCCESS] All test suites passed cleanly with 100% assertion success.
>> ALL TEST SUITES PASSED CLEANLY WITH 100% SUCCESS.
```

### Stress Testing

To simulate high-volume concurrent traffic using the Python test harness:

```bash
python3 clients/python/stress_sim.py --concurrency=16 --requests=1000
```

Results show sustained throughput of **769 requests/second** with **0% failure rate** and median latency of **1.21ms**.

---

## Repository Structure

```
keystone/
├── app/
│   ├── core/                  # Kernel, Config, Logger, IdGenerator, EventBus, Locks, Cache
│   ├── network/               # HttpRouter, As2Receiver, MllpServer, RateLimiter, Webhooks
│   ├── parsers/
│   │   ├── base/              # Lexer, Token, ParseResult base components
│   │   ├── x12/               # X12 Lexer, Parser, Serializer, Validator, AckGenerator, Schemas
│   │   ├── edifact/           # UN/EDIFACT Lexer (UNA escapes), Parser, Serializer, CONTRL
│   │   ├── hl7/               # HL7 v2 Lexer, Parser, Serializer, MLLP, FHIR R4 Converter
│   │   ├── iso20022/          # ISO 20022 Streaming XML Parser, IBAN/BIC Validator
│   │   └── flatfile/          # Fixed-width columnar and RFC 4180 CSV engine
│   ├── registry/              # PartnerRegistry, AgreementManager, WorkflowRegistry
│   ├── security/              # CryptoEngine (AES-256-GCM), MicCalculator, Merkle AuditLedger
│   ├── telemetry/             # HDR Latency Histogram, MetricsCollector, Prometheus Exporter
│   ├── transactions/          # Distributed SagaCoordinator, SagaJournal, Outbox, DLQ, Idempotency
│   ├── transform/             # ExpressionEngine, ValueTransforms, CodeLookupTable, SchemaMapper
│   └── web/                   # REST ApiController, DashboardController, Admin Control Plane
├── bin/                       # Unified CLI executable (keystone) and test runner (test_runner)
├── clients/python/            # Python Client SDK and synthetic traffic stress simulator
├── docs/                      # Technical architecture, protocol specs, manuals, and runbooks
├── native/                    # Native C99 SWAR SIMD delimiter scanner and WyHash checksum
├── sample_data/               # Production samples for X12, EDIFACT, HL7 v2, ISO 20022
├── scripts/                   # Build, test, benchmark, and verification scripts
├── tests/
│   ├── unit/                  # Comprehensive unit tests for all subsystems
│   ├── integration/           # Multi-protocol end-to-end pipeline integration tests
│   └── regressions/           # Documented bug reproduction test suites
├── Application.cfc            # Root CFML web application descriptor
├── index.cfm                  # Control Plane Web UI Entrypoint
├── server.json                # CommandBox server specification
└── Makefile                   # Build automation targets
```

---

## Documentation Index

- [Architecture Specification](docs/architecture.md): Deep-dive system topology, JVM tuning, and native SIMD design.
- [Protocol Specifications](docs/protocol_specs.md): Grammar, delimiter state machines, and envelopes for X12, EDIFACT, HL7, and ISO 20022.
- [Saga Orchestration Manual](docs/saga_orchestration.md): Forward execution, backward compensation, and durable write-ahead journals.
- [Security & AS2 Manual](docs/security_and_as2.md): RFC 4130, S/MIME, canonical MIC digests, and Merkle audit ledgers.
- [Transformation DSL Manual](docs/transformation_dsl.md): ExpressionEngine AST evaluation and declarative mapping templates.
- [Operational Runbook](docs/operational_runbook.md): Production clustering, Prometheus alerts, and troubleshooting guides.
- [Performance Benchmarks](docs/benchmarks.md): Micro-benchmarks, latency distributions, and stress test results.

---

## License

Apache License 2.0. Open source for enterprise distributed systems research and engineering.
