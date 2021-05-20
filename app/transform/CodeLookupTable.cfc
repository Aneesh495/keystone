component {

    property name="tables" type="struct";

    /**
     * Constructor for CodeLookupTable.
     */
    public any function init() {
        variables.tables = {};
        seedStandardTables();
        return this;
    }

    /**
     * Adds an entry to a named lookup table.
     */
    public void function put(required string tableName, required string key, required string value) {
        var tbl = lcase(trim(arguments.tableName));
        if (!structKeyExists(variables.tables, tbl)) {
            variables.tables[tbl] = {};
        }
        variables.tables[tbl][arguments.key] = arguments.value;
    }

    /**
     * Looks up a value by key.
     */
    public string function lookup(required string tableName, required string key, string defaultValue = "") {
        var tbl = lcase(trim(arguments.tableName));
        if (structKeyExists(variables.tables, tbl) && structKeyExists(variables.tables[tbl], arguments.key)) {
            return variables.tables[tbl][arguments.key];
        }
        return arguments.defaultValue;
    }

    /**
     * Reverse lookup: finds key by value.
     */
    public string function reverseLookup(required string tableName, required string value, string defaultKey = "") {
        var tbl = lcase(trim(arguments.tableName));
        if (structKeyExists(variables.tables, tbl)) {
            for (var k in variables.tables[tbl]) {
                if (variables.tables[tbl][k] == arguments.value) {
                    return k;
                }
            }
        }
        return arguments.defaultKey;
    }

    /**
     * Pre-populates standard industry code lookup tables.
     */
    private void function seedStandardTables() {
        // Carrier SCAC codes
        variables.tables["carrier_scac"] = {
            "UPSN": "United Parcel Service",
            "FDXG": "FedEx Ground",
            "FDXE": "FedEx Express",
            "ODFL": "Old Dominion Freight Line",
            "SAIA": "Saia Motor Freight",
            "KNIG": "Knight Transportation",
            "SWFT": "Swift Transportation",
            "CHRW": "C.H. Robinson"
        };

        // Payment Terms (X12 ITD01 / EDIFACT 4279)
        variables.tables["payment_terms"] = {
            "01": "Basic (Net 30)",
            "02": "End of Month (EOM)",
            "03": "Fixed Date",
            "04": "Deferred or Installment",
            "05": "Discount with Advance Payment",
            "08": "Basic Discount (2/10 Net 30)"
        };

        // State Abbreviations
        variables.tables["us_states"] = {
            "AL": "Alabama", "AK": "Alaska", "AZ": "Arizona", "CA": "California",
            "CO": "Colorado", "CT": "Connecticut", "FL": "Florida", "GA": "Georgia",
            "IL": "Illinois", "MA": "Massachusetts", "NJ": "New Jersey", "NY": "New York",
            "TX": "Texas", "WA": "Washington"
        };
    }
}
