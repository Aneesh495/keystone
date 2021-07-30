# Keystone AS2, Cryptography, and Audit Security Manual

## 1. RFC 4130 Applicability Statement 2 (AS2) Specification

AS2 is the global industry standard for secure B2B electronic data interchange over the public Internet. It encapsulates business documents (X12, EDIFACT, XML, JSON) within standard MIME multi-part envelopes signed and encrypted via S/MIME (RFC 3851 / RFC 5652).

Keystone provides native AS2 client transmission and server reception capabilities (`app.network.As2Receiver` and `app.security.As2Engine`).

```
+-----------------------------------------------------------------------------+
|                            AS2 TRANSMISSION LIFECYCLE                        |
+-----------------------------------------------------------------------------+

   Sender (Keystone)                                Receiver (Partner)
          |                                                 |
          |  1. Canonicalize Payload                        |
          |  2. Calculate SHA-256 MIC                       |
          |  3. Sign S/MIME Envelope (PKCS#7)               |
          |  4. Encrypt with Partner Cert (AES-256-CBC)     |
          |                                                 |
          | ------ HTTP/S POST (Signed, Encrypted) -------> |
          |        Headers: AS2-From, AS2-To, Message-ID    |
          |        Disposition-Notification-Options         |
          |                                                 |
          |                                                 | 5. Decrypt Private Key
          |                                                 | 6. Verify Signature
          |                                                 | 7. Recompute MIC
          |                                                 | 8. Verify MIC Match
          |                                                 |
          | <----- HTTP/S Response (Signed MDN Receipt) ---- |
          |        Headers: Disposition: processed          |
          |        Received-Content-MIC: <hash>, sha-256    |
          |                                                 |
          |  9. Verify Partner MDN Signature                |
          | 10. Confirm MIC Match -> Non-Repudiation        |
          v                                                 v
```

---

## 2. Certificate and Key Management

Keystone manages public-key infrastructure (PKI) through `app.security.CertificateStore`:
- Supports standard X.509 certificates (`.cer`, `.pem`, `.crt`) and PKCS#12 keystores (`.p12`, `.pfx`).
- Validates certificate validity dates (notBefore and notAfter).
- Matches partner AS2 identifier with corresponding public certificates declared in the `PartnerRegistry`.
- Implements self-signed certificate generation utilities for local sandbox testing.

---

## 3. Message Integrity Check (MIC) Calculation

The Message Integrity Check (MIC) is the foundational mechanism ensuring non-repudiation of receipt:
1. **Canonicalization**: The raw wire payload is normalized to network canonical line endings (`CRLF` / `\r\n`).
2. **Digest Hashing**: The hash is computed over the unencrypted, canonical MIME entity body:
   - Supported algorithms: SHA-256 (default, RFC 4130 recommendation), SHA-384, SHA-512, and SHA-1 (legacy backward compatibility).
3. **Format**: The resulting binary digest is Base64 encoded and formatted as:
   `Received-Content-MIC: <Base64Digest>, <algorithm>`

Example:
```
Received-Content-MIC: 47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=, sha-256
```

---

## 4. Message Disposition Notifications (MDN)

The MDN is the legal and cryptographic proof of receipt returned by the receiver to the sender.

### 4.1 Synchronous vs Asynchronous MDN

- **Synchronous MDN**: The receiver parses the message, verifies integrity, and returns the MDN directly within the HTTP 200 response of the original POST connection.
- **Asynchronous MDN**: The receiver returns an immediate HTTP 200 OK acknowledging transmission, then initiates an independent HTTP/S connection back to the URL specified in the `Receipt-Delivery-Option` header to deliver the MDN.

### 4.2 MDN Human-Readable and Machine-Readable Sections

An MDN is a `multipart/report` MIME message containing:
1. **Human-Readable Text Block**: A plain text description summarizing the receipt status and any warnings.
2. **Machine-Readable Disposition Block**: Headers including:
   - `Reporting-UA`: Software identifier (`Keystone B2B Gateway v1.0.0`).
   - `Original-Recipient`: Original RFC 822 recipient address.
   - `Final-Recipient`: Final AS2 identifier.
   - `Original-Message-ID`: Message-ID from the inbound POST request.
   - `Disposition`: Status token (`automatic-action/MDN-sent-automatically; processed`).
   - `Received-Content-MIC`: The computed MIC matching the sender digest.

---

## 5. Merkle Audit Ledger and Non-Repudiation

To guarantee non-repudiation and prevent historical transaction tampering, Keystone implements `app.security.AuditLedger`.

### 5.1 Merkle Hash Chain Mechanics

Each audit record is appended with a cryptographic hash link to the preceding record:

```
+--------------------+       +--------------------+       +--------------------+
| Block #1           |       | Block #2           |       | Block #3           |
| Index: 1           |       | Index: 2           |       | Index: 3           |
| Action: INGEST_850 |       | Action: MAP_ORDER  |       | Action: SEND_855   |
| PrevHash: 00000000 | <---- | PrevHash: a8f91c0e | <---- | PrevHash: f43b8192 |
| Hash: a8f91c0e...  |       | Hash: f43b8192...  |       | Hash: 927dbe10...  |
+--------------------+       +--------------------+       +--------------------+
```

### 5.2 Cryptographic Integrity Verification

The `verifyIntegrity()` method verifies:
1. `record[i].prevHash == record[i-1].hash` for all $i \ge 2$.
2. `record[i].hash == SHA256(record[i].fields)` for all records.

If any byte in any historical transaction record is altered, deleted, or inserted out of order, the hash chain breaks immediately, producing a verifiable audit discrepancy report with the exact block index and timestamp of tampering.
