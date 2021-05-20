component {

    /**
     * Constructor for ValueTransforms.
     */
    public any function init() {
        return this;
    }

    /**
     * Converts X12 or EDIFACT date format (YYYYMMDD or YYMMDD) to ISO-8601 (YYYY-MM-DD).
     */
    public string function toIsoDate(required string rawDate) {
        var d = trim(arguments.rawDate);
        if (len(d) == 8 && isNumeric(d)) {
            return left(d, 4) & "-" & mid(d, 5, 2) & "-" & mid(d, 7, 2);
        } else if (len(d) == 6 && isNumeric(d)) {
            var yy = val(left(d, 2));
            var ccyy = (yy > 70) ? (1900 + yy) : (2000 + yy);
            return ccyy & "-" & mid(d, 3, 2) & "-" & mid(d, 5, 2);
        }
        return d;
    }

    /**
     * Converts ISO date (YYYY-MM-DD) to X12 date (YYYYMMDD).
     */
    public string function toX12Date(required string isoDate) {
        return replace(arguments.isoDate, "-", "", "all");
    }

    /**
     * Converts HL7 date/time (YYYYMMDDHHNNSS) to ISO-8601 timestamp.
     */
    public string function toIsoDateTime(required string hl7DateTime) {
        var dt = trim(arguments.hl7DateTime);
        if (len(dt) >= 14 && isNumeric(left(dt, 14))) {
            return left(dt, 4) & "-" & mid(dt, 5, 2) & "-" & mid(dt, 7, 2) & "T" & mid(dt, 9, 2) & ":" & mid(dt, 11, 2) & ":" & mid(dt, 13, 2) & "Z";
        }
        return toIsoDate(dt);
    }

    /**
     * Converts integer cents to decimal dollars string (e.g. 10250 -> '102.50').
     */
    public string function centsToDollars(required numeric cents) {
        var dol = arguments.cents / 100.0;
        return numberFormat(dol, "0.00");
    }

    /**
     * Converts decimal dollars to integer cents (e.g. 102.50 -> 10250).
     */
    public numeric function dollarsToCents(required numeric dollars) {
        return round(arguments.dollars * 100);
    }

    /**
     * Pads a string on the left with specified character.
     */
    public string function padLeft(required string str, required numeric targetLen, string padChar = "0") {
        var s = trim(arguments.str);
        while (len(s) < arguments.targetLen) {
            s = arguments.padChar & s;
        }
        return s;
    }

    /**
     * Pads a string on the right with specified character.
     */
    public string function padRight(required string str, required numeric targetLen, string padChar = " ") {
        var s = trim(arguments.str);
        while (len(s) < arguments.targetLen) {
            s &= arguments.padChar;
        }
        return s;
    }

    /**
     * Normalizes multiple consecutive whitespace characters to a single space.
     */
    public string function normalizeSpaces(required string str) {
        return trim(reReplace(arguments.str, "\s+", " ", "all"));
    }

    /**
     * Maps EDI/HL7 unit of measurement codes to canonical human-readable units.
     */
    public string function mapUom(required string uomCode) {
        var c = ucase(trim(arguments.uomCode));
        switch (c) {
            case "EA": return "Each";
            case "CA": return "Case";
            case "PCE": return "Piece";
            case "BX": return "Box";
            case "PL": return "Pallet";
            case "KG": return "Kilogram";
            case "LB": return "Pound";
            case "FT": return "Foot";
            case "MTR": return "Meter";
            default: return c;
        }
    }

    /**
     * Maps administrative sex code to FHIR gender value.
     */
    public string function mapGender(required string sexCode) {
        var s = ucase(trim(arguments.sexCode));
        if (s == "M" || s == "MALE") return "male";
        if (s == "F" || s == "FEMALE") return "female";
        if (s == "O" || s == "OTHER") return "other";
        return "unknown";
    }
}
