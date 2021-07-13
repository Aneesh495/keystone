<cfset viewTitle = "Distributed Saga Orchestration Workflows">
<cfinclude template="layout.cfm">

<div class="container">
    <div style="margin-bottom: 24px;">
        <h2 style="font-size: 18px; font-weight: 600;">Active & Historical Saga Executions</h2>
        <p style="color: var(--text-secondary); font-size: 13px;">Multi-step distributed transaction coordination with forward chaining and automated backward compensation.</p>
    </div>

    <!-- Active Sagas Table -->
    <div class="card" style="margin-bottom: 32px;">
        <table class="data-table">
            <thead>
                <tr>
                    <th>Saga Identifier</th>
                    <th>Workflow Definition</th>
                    <th>Started At</th>
                    <th>Status</th>
                    <th>Steps Completed</th>
                    <th>Current State / Outcome</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td style="font-family: var(--font-mono); font-weight: 600; color: var(--accent-cyan);">SAGA-B2B-10928</td>
                    <td style="font-weight: 600;">ORDER_FULFILLMENT_SAGA</td>
                    <td style="font-family: var(--font-mono); color: var(--text-secondary);">2026-11-02 18:31:00</td>
                    <td><span class="badge badge-success">COMPLETED</span></td>
                    <td style="font-family: var(--font-mono);">3 / 3</td>
                    <td style="color: var(--accent-emerald);">Inventory Reserved &rarr; Payment Captured &rarr; Warehouse Dispatched</td>
                </tr>
                <tr>
                    <td style="font-family: var(--font-mono); font-weight: 600; color: var(--accent-cyan);">SAGA-B2B-10927</td>
                    <td style="font-weight: 600;">HEALTHCARE_ADMISSION_SAGA</td>
                    <td style="font-family: var(--font-mono); color: var(--text-secondary);">2026-11-02 18:28:44</td>
                    <td><span class="badge badge-success">COMPLETED</span></td>
                    <td style="font-family: var(--font-mono);">4 / 4</td>
                    <td style="color: var(--accent-emerald);">Patient Identified &rarr; FHIR Resource Created &rarr; Bed Allocated &rarr; CareTeam Notified</td>
                </tr>
                <tr>
                    <td style="font-family: var(--font-mono); font-weight: 600; color: var(--accent-cyan);">SAGA-B2B-10926</td>
                    <td style="font-weight: 600;">PAYMENT_CLEARING_SAGA</td>
                    <td style="font-family: var(--font-mono); color: var(--text-secondary);">2026-11-02 18:24:19</td>
                    <td><span class="badge badge-edifact">COMPENSATED</span></td>
                    <td style="font-family: var(--font-mono);">2 / 3 (Rolled back)</td>
                    <td style="color: var(--accent-amber);">Debit Successful &rarr; Clearinghouse Reject &rarr; Credit Compensated</td>
                </tr>
            </tbody>
        </table>
    </div>

    <!-- Visual Saga Execution Timeline Flowchart -->
    <div class="card">
        <h3 style="font-size: 14px; font-weight: 600; margin-bottom: 16px;">Saga Step State Transition Diagram (Execution Lifecycle)</h3>
        <div style="background-color: #0d1117; padding: 20px; border-radius: 6px; border: 1px solid var(--border-color); font-family: var(--font-mono); font-size: 12px; line-height: 1.8;">
            <div style="color: var(--accent-cyan);">[PENDING] &rarr; [RUNNING]</div>
            <div style="padding-left: 20px; color: var(--text-secondary);">&boxur;&rarr; Step 1 Forward Action &rarr; [SUCCESS] (Persist State)</div>
            <div style="padding-left: 20px; color: var(--text-secondary);">&boxur;&rarr; Step 2 Forward Action &rarr; [SUCCESS] (Persist State)</div>
            <div style="padding-left: 20px; color: var(--accent-rose);">&boxur;&rarr; Step 3 Forward Action &rarr; [FAILED] (Network Timeout)</div>
            <div style="color: var(--accent-amber); margin-top: 8px;">[COMPENSATING CASCADE INITIATED] (Reverse Order Execution)</div>
            <div style="padding-left: 20px; color: var(--accent-emerald);">&boxur;&rarr; Step 2 Compensation Action &rarr; [COMPENSATED] (Reverted)</div>
            <div style="padding-left: 20px; color: var(--accent-emerald);">&boxur;&rarr; Step 1 Compensation Action &rarr; [COMPENSATED] (Reverted)</div>
            <div style="color: var(--accent-emerald); font-weight: 700; margin-top: 8px;">[TERMINAL STATUS: COMPENSATED] (Durably Journaled to Disk)</div>
        </div>
    </div>
</div>

    </main>
</body>
</html>
