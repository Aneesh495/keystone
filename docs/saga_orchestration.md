# Keystone Distributed Saga Orchestration Manual

## 1. Saga Coordination Overview

In heterogeneous enterprise ecosystems, business transactions span multiple sovereign systems: ERPs (SAP, NetSuite), Warehouse Management Systems (Manhattan, Blue Yonder), Electronic Health Record databases (Epic, Cerner), payment networks (FedNow, SWIFT), and third-party SaaS applications. Because cross-organization transactions cannot rely on distributed two-phase commit (2PC) locks, Keystone implements the Saga Pattern.

A Saga is a sequence of local transactions where each step updates data within a single service. If a step fails because of business rule violations, network failures, or remote system errors, the Saga Coordinator executes compensating transactions in reverse order to undo the changes made by preceding steps.

```
+-----------------------------------------------------------------------------+
|                        SAGA COORDINATION STATE MACHINE                       |
+-----------------------------------------------------------------------------+
                                       |
                                       v
                                 +-----------+
                                 |  PENDING  |
                                 +-----------+
                                       |
                                       | (start)
                                       v
                             +-------------------+
                             |      RUNNING      | <---+
                             +-------------------+     |
                               |               |       | (next step)
                 (all steps ok)|               | (step failure)
                               v               v
                        +-----------+    +--------------+
                        | COMPLETED |    | COMPENSATING | <---+
                        +-----------+    +--------------+     |
                                               |              | (step rollback)
                                 (all undone)  v              |
                                         +-----------+        |
                                         |  ABORTED  | -------+
                                         +-----------+
```

---

## 2. Core Components

### 2.1 SagaDefinition and SagaStep

A saga workflow is declared as a `SagaDefinition` comprising an ordered list of `SagaStep` objects:
- `name`: Unique step identifier (e.g. `ValidateInventory`, `ReserveStock`, `CapturePayment`).
- `action`: Function or closure that executes the forward operation. It accepts the current saga context struct and returns an updated context or result struct.
- `compensation`: Function or closure that undoes the step effect if a downstream step subsequently fails.
- `timeoutMs`: Maximum duration allowed for the forward action before marking the step timed out.

### 2.2 SagaCoordinator Execution Engine

The `SagaCoordinator` is responsible for driving the lifecycle:
1. Instantiates a unique `SagaExecution` instance with a monotonic UUID.
2. Appends an initial `SAGA_STARTED` record to the `SagaJournal`.
3. Iterates sequentially through each forward step:
   - Sets step status to `RUNNING` and writes a journal event.
   - Executes the step action within a guarded try-catch block.
   - Upon success, records step output into the shared execution context and appends `STEP_COMPLETED`.
4. If a step throws an exception or returns a failure status:
   - Sets saga status to `COMPENSATING`.
   - Iterates in reverse chronological order over all previously completed steps.
   - Executes each step's compensation handler.
   - Appends `STEP_COMPENSATED` events to the journal.
   - Sets final saga status to `ABORTED` or `FAILED` and raises a descriptive alert.

---

## 3. Durable State Logging (SagaJournal)

To survive server crashes, power failures, or unexpected process restarts, Keystone writes all state transitions to an append-only, durable disk journal (`app.transactions.SagaJournal`):

```json
{"timestamp": 1798894200100, "sagaId": "SAGA-90182", "eventType": "SAGA_STARTED", "definition": "OrderIngestionSaga"}
{"timestamp": 1798894200150, "sagaId": "SAGA-90182", "eventType": "STEP_START", "step": "ValidateEdi"}
{"timestamp": 1798894200210, "sagaId": "SAGA-90182", "eventType": "STEP_COMPLETED", "step": "ValidateEdi"}
{"timestamp": 1798894200220, "sagaId": "SAGA-90182", "eventType": "STEP_START", "step": "ReserveInventory"}
{"timestamp": 1798894200380, "sagaId": "SAGA-90182", "eventType": "STEP_FAILED", "step": "ReserveInventory", "error": "Insufficient stock"}
{"timestamp": 1798894200390, "sagaId": "SAGA-90182", "eventType": "COMPENSATION_START", "step": "ValidateEdi"}
{"timestamp": 1798894200420, "sagaId": "SAGA-90182", "eventType": "COMPENSATION_COMPLETED", "step": "ValidateEdi"}
{"timestamp": 1798894200430, "sagaId": "SAGA-90182", "eventType": "SAGA_ABORTED", "reason": "Insufficient stock"}
```

On system startup, the `SagaJournal` scans the journal directory for uncompleted sagas (`PENDING` or `COMPENSATING`) and automatically resumes backward compensation to preserve data consistency across external backends.

---

## 4. Idempotency Guarantees

Because B2B protocols frequently retransmit messages on network timeouts, Keystone incorporates `app.transactions.IdempotencyStore`:
- **Atomic Compare-and-Set**: When an inbound transmission arrives, Keystone generates an idempotency key (e.g. `HASH(senderId + ":" + controlNumber)`).
- **In-Progress Guard**: If an incoming request matches a key currently executing, Keystone rejects the duplicate with HTTP 409 or returns the cached response if already completed.
- **TTL Expiration**: Idempotency records are maintained across a configurable sliding retention window (default: 86,400 seconds / 24 hours).

---

## 5. Transactional Outbox Relay

To prevent dual-write inconsistencies between local database updates and remote network dispatches, outbound messages are written into the transactional outbox table/directory before external delivery.

The `OutboxProcessor` continuously drains pending entries:
- **Exponential Backoff**: Subsequent retry delays scale exponentially: `delay = baseDelayMs * (2 ^ (attempt - 1))`.
- **Bounded Jitter**: Random jitter is added to prevent thundering herd spikes against external partner gateways.
- **Max Attempt Exhaustion**: Messages that exceed maximum retry thresholds are automatically migrated to the Dead Letter Queue.

---

## 6. Dead Letter Queue (DLQ) Management

Messages routed to the DLQ (`app.transactions.DeadLetterQueue`) are persisted with complete diagnostic metadata:
- Original raw payload bytes.
- Header context and protocol destination.
- Attempt count and timestamp history.
- Full stack trace and error diagnostic message.

Operators can inspect failed transmissions via the Web Control Plane (`/dashboard/dlq`) or CLI (`keystone dlq list`), resolve root causes (such as bad partner credentials or malformed segments), and trigger atomic replays (`keystone dlq replay <id>`).
