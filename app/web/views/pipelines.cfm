<cfset viewTitle = "Integration Pipeline Catalog">
<cfinclude template="layout.cfm">

<div class="container">
    <div style="margin-bottom: 24px;">
        <h2 style="font-size: 18px; font-weight: 600;">Registered Integration Pipelines</h2>
        <p style="color: var(--text-secondary); font-size: 13px;">End-to-end processing topologies linking transport receivers, parsers, mappers, and transaction coordinators.</p>
    </div>

    <div class="card">
        <table class="data-table">
            <thead>
                <tr>
                    <th>Pipeline Identifier</th>
                    <th>Protocol</th>
                    <th>Document</th>
                    <th>Parser Component</th>
                    <th>Validation Component</th>
                    <th>Transformation Component</th>
                    <th>Saga Workflow</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td style="font-family: var(--font-mono); font-weight: 600; color: var(--accent-cyan);">INBOUND_X12_850</td>
                    <td><span class="badge badge-x12">X12</span></td>
                    <td>850 Purchase Order</td>
                    <td style="font-family: var(--font-mono); font-size: 11px;">app.parsers.x12.X12Parser</td>
                    <td style="font-family: var(--font-mono); font-size: 11px;">app.parsers.x12.X12Validator</td>
                    <td style="font-family: var(--font-mono); font-size: 11px;">X12_850_To_OrdersJson</td>
                    <td style="font-family: var(--font-mono); font-size: 11px; color: var(--accent-emerald);">ORDER_INGESTION_SAGA</td>
                </tr>
                <tr>
                    <td style="font-family: var(--font-mono); font-weight: 600; color: var(--accent-cyan);">OUTBOUND_X12_855</td>
                    <td><span class="badge badge-x12">X12</span></td>
                    <td>855 PO Acknowledgment</td>
                    <td style="font-family: var(--font-mono); font-size: 11px;">app.parsers.x12.X12Serializer</td>
                    <td style="font-family: var(--font-mono); font-size: 11px;">Schema855</td>
                    <td style="font-family: var(--font-mono); font-size: 11px;">OrdersJson_To_X12_855</td>
                    <td style="font-family: var(--font-mono); font-size: 11px; color: var(--accent-emerald);">ORDER_ACK_DISPATCH_SAGA</td>
                </tr>
                <tr>
                    <td style="font-family: var(--font-mono); font-weight: 600; color: var(--accent-cyan);">INBOUND_HL7_ADT</td>
                    <td><span class="badge badge-hl7">HL7 v2</span></td>
                    <td>ADT_A01 Admission</td>
                    <td style="font-family: var(--font-mono); font-size: 11px;">app.parsers.hl7.HL7Parser</td>
                    <td style="font-family: var(--font-mono); font-size: 11px;">SchemaADT</td>
                    <td style="font-family: var(--font-mono); font-size: 11px;">FhirConverter (FHIR R4)</td>
                    <td style="font-family: var(--font-mono); font-size: 11px; color: var(--accent-emerald);">PATIENT_ADMISSION_SAGA</td>
                </tr>
                <tr>
                    <td style="font-family: var(--font-mono); font-weight: 600; color: var(--accent-cyan);">INBOUND_ISO20022_PAIN001</td>
                    <td><span class="badge badge-iso">ISO 20022</span></td>
                    <td>pain.001 Credit Transfer</td>
                    <td style="font-family: var(--font-mono); font-size: 11px;">Iso20022Parser</td>
                    <td style="font-family: var(--font-mono); font-size: 11px;">Iso20022Validator</td>
                    <td style="font-family: var(--font-mono); font-size: 11px;">Pain001ToPacs008</td>
                    <td style="font-family: var(--font-mono); font-size: 11px; color: var(--accent-emerald);">PAYMENT_CLEARING_SAGA</td>
                </tr>
            </tbody>
        </table>
    </div>
</div>

    </main>
</body>
</html>
