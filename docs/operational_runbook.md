# Keystone Operational Runbook and Production Guide

## 1. Prerequisites and Installation

Keystone runs as an enterprise service on Lucee CFML 5.4+ with Java 17+ or Java 21 LTS:
- Java Runtime Environment: OpenJDK 17 LTS or OpenJDK 21 LTS
- CommandBox CLI: Version 6.0+
- Native Acceleration: Clang or GCC for compiling `libkeystone_accel` (optional; falls back to pure CFML if absent)
- Python 3.10+ (for administrative CLI scripts and traffic simulator)

### 1.1 Local Development Startup

```bash
# Clone repository
git clone https://github.com/Aneesh495/keystone.git
cd keystone

# Start background server
./bin/keystone start

# Verify health status
./bin/keystone health

# Run full test matrix
./bin/test_runner
```

---

## 2. Production Deployment Configurations

### 2.1 JVM Memory and Garbage Collection Tuning

For high-volume production deployments (exceeding 5,000 transactions/second), configure JVM parameters in `server.json`:

```json
{
  "jvm": {
    "args": [
      "-server",
      "-Xms4096m",
      "-Xmx4096m",
      "-XX:+UseG1GC",
      "-XX:MaxGCPauseMillis=20",
      "-XX:InitiatingHeapOccupancyPercent=45",
      "-XX:G1ReservePercent=15",
      "-Dfile.encoding=UTF-8",
      "-Djava.awt.headless=true"
    ]
  }
}
```

### 2.2 Systemd Service Unit Definition

For bare-metal Linux or VM deployments:

```ini
[Unit]
Description=Keystone B2B Transaction Mesh Gateway
After=network.target

[Service]
Type=simple
User=keystone
Group=keystone
WorkingDirectory=/opt/keystone
ExecStart=/usr/local/bin/box server start directory=/opt/keystone --no-open-browser --console
ExecStop=/usr/local/bin/box server stop directory=/opt/keystone
Restart=always
RestartSec=10
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

---

## 3. Telemetry and Prometheus Metrics Reference

Keystone exposes Prometheus v0.0.4 metrics at `/api/v1/metrics`:

| Metric Name | Type | Description |
| :--- | :--- | :--- |
| `keystone_transactions_total` | Counter | Total transactions received by protocol, status, and partner |
| `keystone_transaction_duration_seconds` | Histogram | Request latency distribution across ingress handlers |
| `keystone_parser_errors_total` | Counter | Total syntax and validation failures by protocol |
| `keystone_dlq_messages_current` | Gauge | Total unresolved messages pending in Dead Letter Queue |
| `keystone_outbox_pending_current` | Gauge | Messages queued in transactional outbox awaiting relay |
| `keystone_idempotency_hits_total` | Counter | Total duplicate requests intercepted and deduplicated |
| `keystone_sagas_active` | Gauge | Sagas currently in progress or compensating |

### 3.1 PromQL Alert Rules

```yaml
groups:
  - name: keystone_alerts
    rules:
      - alert: KeystoneHighP99Latency
        expr: histogram_quantile(0.99, rate(keystone_transaction_duration_seconds_bucket[5m])) > 0.500
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Keystone P99 transaction latency exceeds 500ms"

      - alert: KeystoneDeadLetterQueueSpike
        expr: keystone_dlq_messages_current > 20
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Dead Letter Queue depth has exceeded 20 messages"

      - alert: KeystoneOutboxRelayLag
        expr: keystone_outbox_pending_current > 100
        for: 3m
        labels:
          severity: warning
        annotations:
          summary: "Transactional Outbox backlog exceeds 100 pending messages"
```

---

## 4. Operational Troubleshooting Playbook

### 4.1 Troubleshooting AS2 MIC Mismatch Errors

**Symptom**: Outbound AS2 transmission receives a rejected MDN stating `Error: integrity-check-failed` or `MIC mismatch`.

**Investigation**:
1. Check the raw payload line endings: AS2 requires standard CRLF (`\r\n`) line terminators.
2. Verify digest algorithm: Ensure both sender agreement and receiver configuration agree on `sha-256`.
3. Test locally using the `keystone mic` command:
   ```bash
   ./bin/keystone mic sample_data/x12/850_purchase_order.edi --algo=sha-256
   ```

### 4.2 Draining Outbox Backlogs

**Symptom**: `keystone_outbox_pending_current` increases monotonically while partner endpoints are unreachable.

**Remediation**:
1. Verify network egress connectivity to partner endpoint:
   ```bash
   curl -iv https://partner-gateway.example.com/as2
   ```
2. Trigger manual outbox drain cycle:
   ```bash
   curl -X POST http://127.0.0.1:8088/api/v1/outbox/drain
   ```
3. If partner is offline permanently, inspect and reassign destinations in `/storage/outbox/`.

### 4.3 DLQ Inspection and Atomic Replay

**Symptom**: Critical EDI orders landed in Dead Letter Queue due to temporary schema mismatch.

**Remediation**:
1. List DLQ items:
   ```bash
   curl -s http://127.0.0.1:8088/api/v1/dlq
   ```
2. Inspect failure cause and stack trace:
   ```bash
   curl -s http://127.0.0.1:8088/api/v1/dlq/DLQ-MESSAGE-ID
   ```
3. Update schema or partner configuration.
4. Trigger replay:
   ```bash
   curl -X POST http://127.0.0.1:8088/api/v1/dlq/DLQ-MESSAGE-ID/replay
   ```
