component {

    /**
     * Constructor for FhirConverter.
     */
    public any function init() {
        return this;
    }

    /**
     * Converts an HL7 v2 ParseResult into a FHIR R4 Patient resource.
     *
     * @hl7Result app.parsers.base.ParseResult instance containing parsed HL7 AST
     * @return Struct representing FHIR R4 Patient JSON resource
     */
    public struct function toPatientResource(required any hl7Result) {
        var pid = arguments.hl7Result.findFirstSegment("PID");
        if (structIsEmpty(pid)) {
            throw(type="MissingSegmentException", message="Cannot generate FHIR Patient resource: PID segment not found.");
        }

        var elems = pid.elements ?: [];

        // PID-3: Patient Identifier
        var pid3 = arrayLen(elems) >= 3 ? elems[3] : "";
        var idVal = isArray(pid3) ? (arrayLen(pid3) >= 1 ? pid3[1] : "") : toString(pid3);
        var idAuth = isArray(pid3) ? (arrayLen(pid3) >= 4 ? pid3[4] : "EHR") : "EHR";

        // PID-5: Patient Name (Family^Given^Middle^Prefix^Suffix)
        var pid5 = arrayLen(elems) >= 5 ? elems[5] : "";
        var familyName = "";
        var givenNames = [];
        var namePrefix = "";

        if (isArray(pid5)) {
            if (arrayLen(pid5) >= 1) familyName = pid5[1];
            if (arrayLen(pid5) >= 2 && len(trim(pid5[2]))) arrayAppend(givenNames, pid5[2]);
            if (arrayLen(pid5) >= 3 && len(trim(pid5[3]))) arrayAppend(givenNames, pid5[3]);
            if (arrayLen(pid5) >= 4) namePrefix = pid5[4];
        } else {
            familyName = toString(pid5);
        }

        // PID-7: Date of birth (YYYYMMDD -> YYYY-MM-DD)
        var pid7 = arrayLen(elems) >= 7 ? toString(elems[7]) : "";
        var birthDateStr = "";
        if (len(pid7) >= 8) {
            birthDateStr = left(pid7, 4) & "-" & mid(pid7, 5, 2) & "-" & mid(pid7, 7, 2);
        }

        // PID-8: Administrative Sex
        var pid8 = arrayLen(elems) >= 8 ? ucase(toString(elems[8])) : "U";
        var fhirGender = "unknown";
        switch (pid8) {
            case "M": fhirGender = "male"; break;
            case "F": fhirGender = "female"; break;
            case "O": fhirGender = "other"; break;
            default: fhirGender = "unknown"; break;
        }

        // PID-11: Patient Address (Street^Other^City^State^Zip^Country)
        var pid11 = arrayLen(elems) >= 11 ? elems[11] : "";
        var addresses = [];
        if (isArray(pid11)) {
            var addrStruct = {
                "use": "home",
                "line": (arrayLen(pid11) >= 1 && len(trim(pid11[1]))) ? [pid11[1]] : [],
                "city": arrayLen(pid11) >= 3 ? pid11[3] : "",
                "state": arrayLen(pid11) >= 4 ? pid11[4] : "",
                "postalCode": arrayLen(pid11) >= 5 ? pid11[5] : "",
                "country": arrayLen(pid11) >= 6 ? pid11[6] : "USA"
            };
            if (arrayLen(pid11) >= 2 && len(trim(pid11[2]))) {
                arrayAppend(addrStruct.line, pid11[2]);
            }
            arrayAppend(addresses, addrStruct);
        }

        // PID-13: Phone number
        var pid13 = arrayLen(elems) >= 13 ? toString(elems[13]) : "";
        var telecoms = [];
        if (len(trim(pid13))) {
            arrayAppend(telecoms, {
                "system": "phone",
                "value": pid13,
                "use": "home"
            });
        }

        var nameEntry = {
            "use": "official",
            "family": familyName,
            "given": givenNames
        };
        if (len(trim(namePrefix))) {
            nameEntry["prefix"] = [namePrefix];
        }

        var fhirPatient = {
            "resourceType": "Patient",
            "id": len(trim(idVal)) ? idVal : createUUID(),
            "identifier": [
                {
                    "use": "usual",
                    "type": {
                        "coding": [
                            {
                                "system": "http://terminology.hl7.org/CodeSystem/v2-0203",
                                "code": "MR",
                                "display": "Medical Record Number"
                            }
                        ]
                    },
                    "system": "urn:oid:keystone:facility:" & idAuth,
                    "value": idVal
                }
            ],
            "active": true,
            "name": [nameEntry],
            "gender": fhirGender,
            "birthDate": birthDateStr,
            "address": addresses,
            "telecom": telecoms
        };

        return fhirPatient;
    }

    /**
     * Converts an HL7 OBX segment into a FHIR R4 Observation resource.
     */
    public struct function toObservationResource(required struct obxSegment, string patientId = "") {
        var elems = arguments.obxSegment.elements ?: [];
        var valType = arrayLen(elems) >= 2 ? toString(elems[2]) : "ST";
        var obsId = arrayLen(elems) >= 3 ? elems[3] : "";

        var codeVal = "";
        var codeDisplay = "";
        var codeSystem = "http://loinc.org";

        if (isArray(obsId)) {
            codeVal = arrayLen(obsId) >= 1 ? obsId[1] : "";
            codeDisplay = arrayLen(obsId) >= 2 ? obsId[2] : "";
            if (arrayLen(obsId) >= 3 && len(trim(obsId[3]))) {
                codeSystem = "urn:oid:" & obsId[3];
            }
        } else {
            codeVal = toString(obsId);
            codeDisplay = codeVal;
        }

        var obsValue = arrayLen(elems) >= 5 ? toString(elems[5]) : "";
        var obsUnits = arrayLen(elems) >= 6 ? toString(elems[6]) : "";
        var refRange = arrayLen(elems) >= 7 ? toString(elems[7]) : "";
        var abnormalFlag = arrayLen(elems) >= 8 ? toString(elems[8]) : "";

        var obsResource = {
            "resourceType": "Observation",
            "id": createUUID(),
            "status": "final",
            "code": {
                "coding": [
                    {
                        "system": codeSystem,
                        "code": codeVal,
                        "display": codeDisplay
                    }
                ],
                "text": codeDisplay
            }
        };

        if (len(trim(arguments.patientId))) {
            obsResource["subject"] = {
                "reference": "Patient/" & arguments.patientId
            };
        }

        // Value format based on value type
        if (valType == "NM" && isNumeric(obsValue)) {
            obsResource["valueQuantity"] = {
                "value": val(obsValue),
                "unit": obsUnits,
                "system": "http://unitsofmeasure.org",
                "code": obsUnits
            };
        } else {
            obsResource["valueString"] = obsValue;
        }

        if (len(trim(refRange))) {
            obsResource["referenceRange"] = [
                {"text": refRange}
            ];
        }

        if (len(trim(abnormalFlag))) {
            obsResource["interpretation"] = [
                {
                    "coding": [
                        {
                            "system": "http://terminology.hl7.org/CodeSystem/v3-ObservationInterpretation",
                            "code": abnormalFlag
                        }
                    ]
                }
            ];
        }

        return obsResource;
    }

    /**
     * Converts an entire HL7 message into a FHIR R4 Bundle resource containing all parsed entities.
     */
    public struct function toBundleResource(required any hl7Result) {
        var patient = toPatientResource(arguments.hl7Result);
        var patientId = patient.id;

        var entries = [
            {
                "fullUrl": "urn:uuid:" & patientId,
                "resource": patient
            }
        ];

        var obxSegments = arguments.hl7Result.findSegments("OBX");
        for (var obx in obxSegments) {
            var obs = toObservationResource(obx, patientId);
            arrayAppend(entries, {
                "fullUrl": "urn:uuid:" & obs.id,
                "resource": obs
            });
        }

        return {
            "resourceType": "Bundle",
            "id": createUUID(),
            "type": "collection",
            "timestamp": dateTimeFormat(now(), "yyyy-mm-dd'T'HH:nn:ss.l'Z'"),
            "entry": entries
        };
    }
}
