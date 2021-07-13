<cfset viewTitle = "Trading Partner Directory">
<cfinclude template="layout.cfm">

<div class="container">
    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px;">
        <div>
            <h2 style="font-size: 18px; font-weight: 600;">Trading Partner Profiles & Agreements</h2>
            <p style="color: var(--text-secondary); font-size: 13px;">AS2 identifiers, EDI interchange qualifiers, digital certificates, and routing endpoints.</p>
        </div>
        <div>
            <button style="background-color: var(--accent-blue); color: #fff; border: none; padding: 8px 16px; border-radius: 6px; font-weight: 600; font-size: 13px; cursor: pointer; font-family: var(--font-mono);">
                + ENROLL PARTNER
            </button>
        </div>
    </div>

    <div class="card">
        <table class="data-table">
            <thead>
                <tr>
                    <th>Partner Identifier</th>
                    <th>Organization Name</th>
                    <th>AS2 Station ID</th>
                    <th>EDI Interchange ID</th>
                    <th>Qualifier</th>
                    <th>Certificate Status</th>
                    <th>Mesh Status</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td style="font-family: var(--font-mono); font-weight: 600; color: var(--accent-cyan);">PARTNER_ACME</td>
                    <td>Acme Industrial Supplies Inc.</td>
                    <td style="font-family: var(--font-mono);">ACME_AS2_PROD</td>
                    <td style="font-family: var(--font-mono);">PARTNERA</td>
                    <td style="font-family: var(--font-mono);">ZZ</td>
                    <td><span class="badge badge-success">X.509 VALID</span></td>
                    <td><span class="badge badge-success">ACTIVE</span></td>
                </tr>
                <tr>
                    <td style="font-family: var(--font-mono); font-weight: 600; color: var(--accent-cyan);">PARTNER_GLOBAL</td>
                    <td>Global Logistics & Freight Corp.</td>
                    <td style="font-family: var(--font-mono);">GLOBAL_LOG_AS2</td>
                    <td style="font-family: var(--font-mono);">GLOBALLOG</td>
                    <td style="font-family: var(--font-mono);">01</td>
                    <td><span class="badge badge-success">X.509 VALID</span></td>
                    <td><span class="badge badge-success">ACTIVE</span></td>
                </tr>
                <tr>
                    <td style="font-family: var(--font-mono); font-weight: 600; color: var(--accent-cyan);">HOSPITAL_SYS_01</td>
                    <td>Metro Health Regional Hospital Network</td>
                    <td style="font-family: var(--font-mono);">-</td>
                    <td style="font-family: var(--font-mono);">METROHEALTH</td>
                    <td style="font-family: var(--font-mono);">ZZ</td>
                    <td><span class="badge badge-success">TLS CLIENT CERT</span></td>
                    <td><span class="badge badge-success">ACTIVE</span></td>
                </tr>
                <tr>
                    <td style="font-family: var(--font-mono); font-weight: 600; color: var(--accent-cyan);">CLEARING_HOUSE_US</td>
                    <td>Federal Clearing & Settlement Intermediary</td>
                    <td style="font-family: var(--font-mono);">US_CLEARING_AS2</td>
                    <td style="font-family: var(--font-mono);">FEDCLEAR</td>
                    <td style="font-family: var(--font-mono);">01</td>
                    <td><span class="badge badge-success">X.509 VALID</span></td>
                    <td><span class="badge badge-success">ACTIVE</span></td>
                </tr>
            </tbody>
        </table>
    </div>
</div>

    </main>
</body>
</html>
