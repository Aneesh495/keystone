component {

    /**
     * Constructor for Iso20022Validator.
     */
    public any function init() {
        return this;
    }

    /**
     * Validates parsed ISO 20022 AST including IBAN checksums and BIC formatting.
     */
    public array function validate(required any parseResult) {
        var errors = [];
        var ast = arguments.parseResult.getAst();

        if (structIsEmpty(ast.groupHeader ?: {})) {
            arrayAppend(errors, {
                "code": "MISSING_GROUP_HEADER",
                "message": "ISO 20022 message is missing mandatory GrpHdr (Group Header)"
            });
        }

        var txs = ast.transactions ?: [];
        if (arrayLen(txs) == 0) {
            arrayAppend(errors, {
                "code": "NO_TRANSACTIONS",
                "message": "ISO 20022 message contains no Credit Transfer transaction records"
            });
        }

        var txIdx = 0;
        for (var tx in txs) {
            txIdx++;

            // Validate IBAN debtor
            if (len(trim(tx.debtorIban ?: ""))) {
                if (!validateIban(tx.debtorIban)) {
                    arrayAppend(errors, {
                        "code": "INVALID_DEBTOR_IBAN",
                        "message": "Debtor IBAN [" & tx.debtorIban & "] failed Mod-97 checksum validation at tx index " & txIdx
                    });
                }
            }

            // Validate IBAN creditor
            if (len(trim(tx.creditorIban ?: ""))) {
                if (!validateIban(tx.creditorIban)) {
                    arrayAppend(errors, {
                        "code": "INVALID_CREDITOR_IBAN",
                        "message": "Creditor IBAN [" & tx.creditorIban & "] failed Mod-97 checksum validation at tx index " & txIdx
                    });
                }
            }

            // Validate BIC
            if (len(trim(tx.debtorBic ?: ""))) {
                if (!validateBic(tx.debtorBic)) {
                    arrayAppend(errors, {
                        "code": "INVALID_DEBTOR_BIC",
                        "message": "Debtor BIC [" & tx.debtorBic & "] is not a valid 8 or 11 character ISO 9362 code at tx index " & txIdx
                    });
                }
            }

            if (len(trim(tx.creditorBic ?: ""))) {
                if (!validateBic(tx.creditorBic)) {
                    arrayAppend(errors, {
                        "code": "INVALID_CREDITOR_BIC",
                        "message": "Creditor BIC [" & tx.creditorBic & "] is not a valid 8 or 11 character ISO 9362 code at tx index " & txIdx
                    });
                }
            }

            // Validate currency
            if (len(trim(tx.currency ?: ""))) {
                if (len(tx.currency) != 3 || !reFind("^[A-Z]{3}$", tx.currency)) {
                    arrayAppend(errors, {
                        "code": "INVALID_CURRENCY",
                        "message": "Currency code [" & tx.currency & "] is not a valid 3-letter ISO 4217 code at tx index " & txIdx
                    });
                }
            }
        }

        for (var err in errors) {
            arguments.parseResult.addError(err.message, err.code);
        }

        return errors;
    }

    /**
     * Validates an International Bank Account Number (IBAN) using ISO 7064 Mod-97-10 algorithm.
     */
    public boolean function validateIban(required string iban) {
        var clean = ucase(reReplace(arguments.iban, "[^a-zA-Z0-9]", "", "all"));
        if (len(clean) < 15 || len(clean) > 34) {
            return false;
        }

        // Move the first 4 characters to the end
        var rearranged = right(clean, len(clean) - 4) & left(clean, 4);

        // Convert letters to digits (A=10, ..., Z=35)
        var numStr = "";
        for (var i = 1; i <= len(rearranged); i++) {
            var ch = mid(rearranged, i, 1);
            var code = asc(ch);
            if (code >= 65 && code <= 90) {
                numStr &= (code - 55);
            } else {
                numStr &= ch;
            }
        }

        // Perform Mod-97 using Java BigInteger
        try {
            var bigInt = createObject("java", "java.math.BigInteger").init(numStr);
            var mod97 = bigInt.mod(createObject("java", "java.math.BigInteger").valueOf(97));
            return (mod97.intValue() == 1);
        } catch (any e) {
            return false;
        }
    }

    /**
     * Validates ISO 9362 Business Identifier Code (BIC / SWIFT).
     * Format: 4 letters bank code, 2 letters country code, 2 letters location code, optional 3 branch code.
     */
    public boolean function validateBic(required string bic) {
        var clean = ucase(trim(arguments.bic));
        return reFind("^[A-Z]{6}[A-Z0-9]{2}([A-Z0-9]{3})?$", clean) > 0;
    }
}
