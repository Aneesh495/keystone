<cfparam name="url.id" default="TXN-9041-884A">
<cfset viewTitle = "Transaction Record :: " & url.id>
<cfinclude template="layout.cfm">

<div class="container">
    <div style="margin-bottom: 24px;">
        <a href="index.cfm?view=transactions" style="color: var(--text-secondary); text-decoration: none; font-size: 13px;">&larr; Back to Transaction Stream</a>
        <h2 style="font-size: 20px; font-weight: 700; margin-top: 8px;">
            Transaction Detail: <span style="font-family: var(--font-mono); color: var(--accent-cyan);"><cfoutput>#encodeForHTML(url.id)#</cfoutput></span>
        </h2>
    </div>

    <!-- Cryptographic Proof Card -->
    <div class="card" style="margin-bottom: 24px; border-left: 4px solid var(--accent-emerald);">
        <h3 style="font-size: 14px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; color: var(--accent-emerald); margin-bottom: 12px;">
            Tamper-Evident Merkle Proof Validated
        </h3>
        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 16px; font-size: 12px; font-family: var(--font-mono);">
            <div>
                <span style="color: var(--text-secondary); display: block;">BLOCK HASH</span>
                <span style="color: #fff; word-break: break-all;">8f434346648f6b96df89dda901c5176b10a6d83961dd3c1ac88b59b2dc327aa4</span>
            </div>
            <div>
                <span style="color: var(--text-secondary); display: block;">PREVIOUS BLOCK HASH</span>
                <span style="color: var(--text-secondary); word-break: break-all;">0000000000000000000000000000000000000000000000000000000000000000</span>
            </div>
            <div>
                <span style="color: var(--text-secondary); display: block;">SIGNATURE ALGORITHM</span>
                <span style="color: #fff;">RSA-SHA256 (2048-bit X.509)</span>
            </div>
            <div>
                <span style="color: var(--text-secondary); display: block;">SIGNATURE VERIFICATION</span>
                <span style="color: var(--accent-emerald); font-weight: 700;">VALID & PROVEN</span>
            </div>
        </div>
    </div>

    <!-- Side-by-Side Payload and AST Viewer -->
    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 24px;">
        <div class="card">
            <h3 style="font-size: 14px; font-weight: 600; margin-bottom: 12px;">Raw Transmitted Payload</h3>
            <pre style="background-color: #0d1117; color: #e5e7eb; padding: 16px; border-radius: 6px; font-family: var(--font-mono); font-size: 12px; height: 350px; overflow: auto; border: 1px solid var(--border-color); white-space: pre-wrap;">ISA*00*          *00*          *ZZ*PARTNERA       *ZZ*KEYSTONEGATE   *261102*1200*U*00401*000000001*0*P*>~
GS*PO*PARTNERA*KEYSTONEGATE*20261102*1200*1*X*004010~
ST*850*0001~
BEG*00*SA*PO-994821**20261102~
CUR*BY*USD~
N1*BT*ACME SUPPLIES INC*91*123456789~
PO1*1*500*EA*14.50**VN*CAT-4492-X~
PID*F****INDUSTRIAL FASTENER GRADE 8~
CTT*1~
SE*8*0001~
GE*1*1~
IEA*1*000000001~</pre>
        </div>

        <div class="card">
            <h3 style="font-size: 14px; font-weight: 600; margin-bottom: 12px;">Transformed Canonical Object (JSON)</h3>
            <pre style="background-color: #0d1117; color: #58a6ff; padding: 16px; border-radius: 6px; font-family: var(--font-mono); font-size: 12px; height: 350px; overflow: auto; border: 1px solid var(--border-color); white-space: pre-wrap;">{
  "orderId": "PO-994821",
  "orderDate": "2026-11-02",
  "currency": "USD",
  "buyer": {
    "name": "ACME SUPPLIES INC",
    "duns": "123456789"
  },
  "lineItems": [
    {
      "lineNumber": "1",
      "quantity": 500,
      "uom": "EA",
      "unitPrice": 14.50,
      "vendorPartNumber": "CAT-4492-X",
      "description": "INDUSTRIAL FASTENER GRADE 8",
      "extendedPrice": 7250.00
    }
  ],
  "totalLines": 1,
  "totalAmount": 7250.00
}</pre>
        </div>
    </div>
</div>

    </main>
</body>
</html>
