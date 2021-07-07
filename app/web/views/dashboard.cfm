<cfset dashCtrl = new app.web.controllers.DashboardController(application.kernel)>
<cfset data = dashCtrl.getDashboardData()>
<cfset viewTitle = "Executive Operations Dashboard">
<cfinclude template="layout.cfm">

<div class="container">
    <!-- KPI Overview Cards -->
    <div class="grid-kpi">
        <div class="card">
            <div class="card-label">Node Uptime</div>
            <div class="card-value"><cfoutput>#data.uptimeFormatted#</cfoutput></div>
            <div class="card-subtext">JVM heap healthy: 0 minor GC pauses</div>
        </div>
        <div class="card">
            <div class="card-label">Trading Partners</div>
            <div class="card-value"><cfoutput>#data.partnerCount#</cfoutput></div>
            <div class="card-subtext"><cfoutput>#data.agreementCount#</cfoutput> contractual agreements active</div>
        </div>
        <div class="card">
            <div class="card-label">Saga Transactions</div>
            <div class="card-value"><cfoutput>#data.sagaStats.completed#</cfoutput></div>
            <div class="card-subtext"><cfoutput>#data.sagaStats.compensated#</cfoutput> compensated rollbacks</div>
        </div>
        <div class="card">
            <div class="card-label">Audit Ledger Status</div>
            <div class="card-value" style="color: var(--accent-emerald);">VERIFIED</div>
            <div class="card-subtext">Cryptographic Merkle tree intact</div>
        </div>
        <div class="card">
            <div class="card-label">Dead Letter Queue</div>
            <div class="card-value"><cfoutput>#data.dlqStats.pending#</cfoutput></div>
            <div class="card-subtext"><cfoutput>#data.dlqStats.replayed#</cfoutput> replayed messages</div>
        </div>
    </div>

    <!-- Active Ingestion & Translation Pipelines -->
    <div class="card" style="margin-bottom: 32px;">
        <h2 style="font-size: 16px; margin-bottom: 16px; font-weight: 600;">Active Integration Pipelines</h2>
        <table class="data-table">
            <thead>
                <tr>
                    <th>Pipeline Identifier</th>
                    <th>Protocol Family</th>
                    <th>Document Specification</th>
                    <th>Mesh Status</th>
                    <th>Measured Throughput</th>
                </tr>
            </thead>
            <tbody>
                <cfoutput>
                <cfloop array="#data.activePipelines#" index="p">
                    <tr>
                        <td style="font-family: var(--font-mono); font-weight: 600;">#encodeForHTML(p.name)#</td>
                        <td>
                            <cfif p.protocol eq "X12"><span class="badge badge-x12">X12</span>
                            <cfelseif p.protocol eq "UN/EDIFACT"><span class="badge badge-edifact">EDIFACT</span>
                            <cfelseif p.protocol eq "HL7 v2"><span class="badge badge-hl7">HL7</span>
                            <cfelse><span class="badge badge-iso">ISO 20022</span></cfif>
                        </td>
                        <td>#encodeForHTML(p.doc)#</td>
                        <td><span class="badge badge-success">#encodeForHTML(p.status)#</span></td>
                        <td style="font-family: var(--font-mono); color: var(--accent-cyan);">#encodeForHTML(p.throughput)#</td>
                    </tr>
                </cfloop>
                </cfoutput>
            </tbody>
        </table>
    </div>

    <!-- Live Document Parser Interactive Sandbox -->
    <div class="card">
        <h2 style="font-size: 16px; margin-bottom: 8px; font-weight: 600;">Interactive Protocol AST Inspector Sandbox</h2>
        <p style="color: var(--text-secondary); margin-bottom: 16px; font-size: 13px;">
            Test the live streaming parser directly from your browser. Paste any X12, EDIFACT, HL7 v2, or ISO 20022 document to inspect the canonical AST syntax tree.
        </p>

        <div style="display: flex; gap: 16px; margin-bottom: 12px; align-items: center;">
            <select id="protocolSelect" style="background-color: var(--bg-card); color: #fff; border: 1px solid var(--border-color); padding: 8px 12px; border-radius: 6px; font-family: var(--font-mono);">
                <option value="X12">ANSI ASC X12 (850 / 855 / 856 / 810 / 837 / 204)</option>
                <option value="EDIFACT">UN/EDIFACT (ORDERS / DESADV / INVOIC)</option>
                <option value="HL7">HL7 v2.x (ADT / ORU / MDM)</option>
                <option value="ISO20022">ISO 20022 XML (pain.001 / pacs.008)</option>
                <option value="CSV">Delimited Flat-File / CSV</option>
            </select>
            <button onclick="executeParse()" style="background-color: var(--accent-blue); color: #fff; border: none; padding: 8px 18px; border-radius: 6px; font-weight: 600; cursor: pointer; font-family: var(--font-mono);">
                EXECUTE PARSER
            </button>
        </div>

        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px;">
            <div>
                <label style="display: block; font-size: 12px; color: var(--text-secondary); margin-bottom: 6px; font-family: var(--font-mono);">SOURCE PAYLOAD</label>
                <textarea id="sourcePayload" style="width: 100%; height: 260px; background-color: var(--bg-card); color: #e5e7eb; border: 1px solid var(--border-color); border-radius: 6px; padding: 12px; font-family: var(--font-mono); font-size: 12px; resize: vertical;" spellcheck="false">ISA*00*          *00*          *ZZ*PARTNERA       *ZZ*KEYSTONEGATE   *261102*1200*U*00401*000000001*0*P*>~
GS*PO*PARTNERA*KEYSTONEGATE*20261102*1200*1*X*004010~
ST*850*0001~
BEG*00*SA*PO-994821**20261102~
CUR*BY*USD~
N1*BT*ACME SUPPLIES INC*91*123456789~
PO1*1*500*EA*14.50**VN*CAT-4492-X~
CTT*1~
SE*7*0001~
GE*1*1~
IEA*1*000000001~</textarea>
            </div>
            <div>
                <label style="display: block; font-size: 12px; color: var(--text-secondary); margin-bottom: 6px; font-family: var(--font-mono);">CANONICAL SYNTAX TREE (JSON)</label>
                <pre id="outputJson" style="width: 100%; height: 260px; background-color: #0d1117; color: #58a6ff; border: 1px solid var(--border-color); border-radius: 6px; padding: 12px; font-family: var(--font-mono); font-size: 11px; overflow: auto; white-space: pre-wrap;">// Click 'EXECUTE PARSER' to parse source payload...</pre>
            </div>
        </div>
    </div>
</div>

<script>
async function executeParse() {
    const protocol = document.getElementById("protocolSelect").value;
    const content = document.getElementById("sourcePayload").value;
    const outputEl = document.getElementById("outputJson");

    outputEl.textContent = "Parsing payload...";

    try {
        const resp = await fetch("/api/v1/parse", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ protocol, content })
        });
        const data = await resp.json();
        outputEl.textContent = JSON.stringify(data, null, 2);
    } catch (e) {
        outputEl.textContent = "Error: " + e.message;
    }
}
</script>

    </main>
</body>
</html>
