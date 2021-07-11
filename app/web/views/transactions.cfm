<cfset viewTitle = "Transaction Inspector & Audit Stream">
<cfinclude template="layout.cfm">

<div class="container">
    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px;">
        <div>
            <h2 style="font-size: 18px; font-weight: 600;">Transaction Audit Stream</h2>
            <p style="color: var(--text-secondary); font-size: 13px;">Real-time tamper-evident ledger tracking of all B2B EDI, HL7, and ISO 20022 message exchanges.</p>
        </div>
        <div style="display: flex; gap: 12px;">
            <input type="text" placeholder="Filter by Transaction ID or Partner..." style="background-color: var(--bg-surface); border: 1px solid var(--border-color); color: #fff; padding: 8px 12px; border-radius: 6px; font-size: 13px; font-family: var(--font-mono); width: 320px;">
        </div>
    </div>

    <div class="card">
        <table class="data-table">
            <thead>
                <tr>
                    <th>Timestamp (UTC)</th>
                    <th>Transaction Identifier</th>
                    <th>Sender</th>
                    <th>Receiver</th>
                    <th>Protocol</th>
                    <th>Document</th>
                    <th>Payload SHA-256</th>
                    <th>Status</th>
                    <th>Action</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td style="font-family: var(--font-mono); color: var(--text-secondary);">2026-11-02 18:30:12</td>
                    <td style="font-family: var(--font-mono); font-weight: 600; color: var(--accent-cyan);">TXN-9041-884A</td>
                    <td>PARTNER_ACME</td>
                    <td>KEYSTONE</td>
                    <td><span class="badge badge-x12">X12</span></td>
                    <td>850 Purchase Order</td>
                    <td style="font-family: var(--font-mono); font-size: 11px; color: var(--text-secondary);">e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855</td>
                    <td><span class="badge badge-success">COMPLETED</span></td>
                    <td><a href="index.cfm?view=detail&id=TXN-9041-884A" style="color: var(--accent-blue); text-decoration: none; font-weight: 600; font-size: 12px;">Inspect &rarr;</a></td>
                </tr>
                <tr>
                    <td style="font-family: var(--font-mono); color: var(--text-secondary);">2026-11-02 18:29:45</td>
                    <td style="font-family: var(--font-mono); font-weight: 600; color: var(--accent-cyan);">TXN-9041-883F</td>
                    <td>PARTNER_GLOBAL</td>
                    <td>KEYSTONE</td>
                    <td><span class="badge badge-edifact">EDIFACT</span></td>
                    <td>ORDERS D.96A</td>
                    <td style="font-family: var(--font-mono); font-size: 11px; color: var(--text-secondary);">7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069</td>
                    <td><span class="badge badge-success">COMPLETED</span></td>
                    <td><a href="index.cfm?view=detail&id=TXN-9041-883F" style="color: var(--accent-blue); text-decoration: none; font-weight: 600; font-size: 12px;">Inspect &rarr;</a></td>
                </tr>
                <tr>
                    <td style="font-family: var(--font-mono); color: var(--text-secondary);">2026-11-02 18:28:10</td>
                    <td style="font-family: var(--font-mono); font-weight: 600; color: var(--accent-cyan);">TXN-9041-882C</td>
                    <td>HOSPITAL_SYS_01</td>
                    <td>KEYSTONE</td>
                    <td><span class="badge badge-hl7">HL7 v2</span></td>
                    <td>ADT_A01 Admission</td>
                    <td style="font-family: var(--font-mono); font-size: 11px; color: var(--text-secondary);">60303ae22b998861bce3b28f33eec1be758a213c86c93c076dbe9f508c36cbbe</td>
                    <td><span class="badge badge-success">COMPLETED</span></td>
                    <td><a href="index.cfm?view=detail&id=TXN-9041-882C" style="color: var(--accent-blue); text-decoration: none; font-weight: 600; font-size: 12px;">Inspect &rarr;</a></td>
                </tr>
                <tr>
                    <td style="font-family: var(--font-mono); color: var(--text-secondary);">2026-11-02 18:25:33</td>
                    <td style="font-family: var(--font-mono); font-weight: 600; color: var(--accent-cyan);">TXN-9041-881E</td>
                    <td>CLEARING_HOUSE_US</td>
                    <td>KEYSTONE</td>
                    <td><span class="badge badge-iso">ISO 20022</span></td>
                    <td>pain.001 Credit Transfer</td>
                    <td style="font-family: var(--font-mono); font-size: 11px; color: var(--text-secondary);">2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae</td>
                    <td><span class="badge badge-success">COMPLETED</span></td>
                    <td><a href="index.cfm?view=detail&id=TXN-9041-881E" style="color: var(--accent-blue); text-decoration: none; font-weight: 600; font-size: 12px;">Inspect &rarr;</a></td>
                </tr>
            </tbody>
        </table>
    </div>
</div>

    </main>
</body>
</html>
