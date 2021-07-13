<cfset viewTitle = "Dead Letter Queue (DLQ) Manager">
<cfinclude template="layout.cfm">

<div class="container">
    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px;">
        <div>
            <h2 style="font-size: 18px; font-weight: 600;">Dead Letter Queue (DLQ) Management</h2>
            <p style="color: var(--text-secondary); font-size: 13px;">Poison message isolation, retry exhaustion containment, and interactive message re-drive triage.</p>
        </div>
        <div>
            <button style="background-color: var(--accent-emerald); color: #fff; border: none; padding: 8px 16px; border-radius: 6px; font-weight: 600; font-size: 13px; cursor: pointer; font-family: var(--font-mono);">
                REPLAY ALL PENDING
            </button>
        </div>
    </div>

    <!-- DLQ Status Table -->
    <div class="card">
        <table class="data-table">
            <thead>
                <tr>
                    <th>Enqueued Timestamp</th>
                    <th>Message Identifier</th>
                    <th>Original Routing Topic</th>
                    <th>Diagnostic Failure Reason</th>
                    <th>Retry Attempts</th>
                    <th>DLQ Status</th>
                    <th>Triage Actions</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td style="font-family: var(--font-mono); color: var(--text-secondary);">2026-11-02 18:15:22</td>
                    <td style="font-family: var(--font-mono); font-weight: 600; color: var(--accent-cyan);">MSG-ERR-00918</td>
                    <td style="font-family: var(--font-mono);">EDI.X12.850.OUTBOUND</td>
                    <td style="color: var(--accent-rose);">Max delivery attempts exceeded (5): Partner AS2 endpoint HTTP 503</td>
                    <td style="font-family: var(--font-mono);">5 / 5</td>
                    <td><span class="badge badge-fail">PENDING_REVIEW</span></td>
                    <td>
                        <button style="background: none; border: 1px solid var(--accent-blue); color: var(--accent-blue); padding: 4px 8px; border-radius: 4px; font-size: 11px; cursor: pointer;">Replay</button>
                        <button style="background: none; border: 1px solid var(--accent-rose); color: var(--accent-rose); padding: 4px 8px; border-radius: 4px; font-size: 11px; cursor: pointer;">Discard</button>
                    </td>
                </tr>
                <tr>
                    <td style="font-family: var(--font-mono); color: var(--text-secondary);">2026-11-02 17:40:09</td>
                    <td style="font-family: var(--font-mono); font-weight: 600; color: var(--accent-cyan);">MSG-ERR-00917</td>
                    <td style="font-family: var(--font-mono);">HEALTHCARE.HL7.ADT</td>
                    <td style="color: var(--accent-amber);">Corrupt MLLP framing trailer: Missing 0x1C 0x0D terminator</td>
                    <td style="font-family: var(--font-mono);">1 / 1</td>
                    <td><span class="badge badge-success">REPLAYED</span></td>
                    <td style="color: var(--text-secondary); font-size: 12px;">Resolved</td>
                </tr>
            </tbody>
        </table>
    </div>
</div>

    </main>
</body>
</html>
