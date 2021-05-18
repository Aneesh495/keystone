component {

    property name="customFunctions" type="struct";

    /**
     * Constructor for ExpressionEngine.
     */
    public any function init() {
        variables.customFunctions = {};
        registerBuiltInFunctions();
        return this;
    }

    /**
     * Registers a custom transformation function.
     */
    public void function registerFunction(required string name, required any closure) {
        variables.customFunctions[lcase(arguments.name)] = arguments.closure;
    }

    /**
     * Evaluates an expression against a scoped context struct.
     *
     * @expression Expression string, e.g. "item.qty * item.price", "uppercase(customer.name)", "x > 0 ? 'YES' : 'NO'"
     * @context Scope dictionary containing variables
     */
    public any function evaluate(required string expression, struct context = {}) {
        var expr = trim(arguments.expression);
        if (len(expr) == 0) return "";

        // Check for ternary operator: <condition> ? <trueVal> : <falseVal>
        var ternaryMatch = parseTernary(expr);
        if (!structIsEmpty(ternaryMatch)) {
            var conditionVal = evaluate(ternaryMatch.condition, arguments.context);
            if (isBoolean(conditionVal) && conditionVal) {
                return evaluate(ternaryMatch.trueExpr, arguments.context);
            } else if (!isBoolean(conditionVal) && len(toString(conditionVal)) > 0 && conditionVal != 0) {
                return evaluate(ternaryMatch.trueExpr, arguments.context);
            } else {
                return evaluate(ternaryMatch.falseExpr, arguments.context);
            }
        }

        // Check for function call: fnName(arg1, arg2, ...)
        if (reFind("^[a-zA-Z0-9_]+\(.*\)$", expr)) {
            var openParen = find("(", expr);
            var fnName = lcase(trim(left(expr, openParen - 1)));
            var argsStr = mid(expr, openParen + 1, len(expr) - openParen - 1);
            var rawArgs = splitArguments(argsStr);
            var evaluatedArgs = [];

            for (var rawArg in rawArgs) {
                arrayAppend(evaluatedArgs, evaluate(rawArg, arguments.context));
            }

            if (structKeyExists(variables.customFunctions, fnName)) {
                var fn = variables.customFunctions[fnName];
                switch (arrayLen(evaluatedArgs)) {
                    case 0: return fn();
                    case 1: return fn(evaluatedArgs[1]);
                    case 2: return fn(evaluatedArgs[1], evaluatedArgs[2]);
                    case 3: return fn(evaluatedArgs[1], evaluatedArgs[2], evaluatedArgs[3]);
                    default: return fn(argumentCollection = evaluatedArgs);
                }
            } else {
                throw(type="UnknownFunctionException", message="Unknown transformation function: " & fnName);
            }
        }

        // Check for binary arithmetic: +, -, *, /
        var mathTokens = splitBinaryOperator(expr);
        if (!structIsEmpty(mathTokens)) {
            var leftVal = evaluate(mathTokens.left, arguments.context);
            var rightVal = evaluate(mathTokens.right, arguments.context);

            if (mathTokens.op == "+") {
                if (isNumeric(leftVal) && isNumeric(rightVal)) {
                    return val(leftVal) + val(rightVal);
                }
                return toString(leftVal) & toString(rightVal);
            } else if (mathTokens.op == "-") {
                return val(leftVal) - val(rightVal);
            } else if (mathTokens.op == "*") {
                return val(leftVal) * val(rightVal);
            } else if (mathTokens.op == "/") {
                var denom = val(rightVal);
                return denom != 0 ? (val(leftVal) / denom) : 0;
            } else if (mathTokens.op == "==") {
                return leftVal == rightVal;
            } else if (mathTokens.op == "!=") {
                return leftVal != rightVal;
            } else if (mathTokens.op == ">") {
                return val(leftVal) > val(rightVal);
            } else if (mathTokens.op == "<") {
                return val(leftVal) < val(rightVal);
            }
        }

        // Quoted string literal
        if ((left(expr, 1) == '"' && right(expr, 1) == '"') || (left(expr, 1) == "'" && right(expr, 1) == "'")) {
            return mid(expr, 2, len(expr) - 2);
        }

        // Numeric literal
        if (isNumeric(expr)) {
            return val(expr);
        }

        // Boolean literal
        if (expr == "true" || expr == "false") {
            return (expr == "true");
        }

        // Null literal
        if (expr == "null") {
            return "";
        }

        // Variable path resolution in context (e.g. 'order.total' or 'item.sku')
        return resolvePath(expr, arguments.context);
    }

    /**
     * Resolves dot-notation path in a scoped context struct.
     */
    public any function resolvePath(required string path, required struct context) {
        var parts = listToArray(arguments.path, ".");
        var current = arguments.context;

        for (var part in parts) {
            // Check for array index notation: field[0] or field[1]
            if (find("[", part) > 0 && right(part, 1) == "]") {
                var bracketIdx = find("[", part);
                var fieldName = left(part, bracketIdx - 1);
                var idx = val(mid(part, bracketIdx + 1, len(part) - bracketIdx - 1));

                if (isStruct(current) && structKeyExists(current, fieldName)) {
                    current = current[fieldName];
                    if (isArray(current) && idx <= arrayLen(current)) {
                        current = current[idx];
                    } else {
                        return "";
                    }
                } else {
                    return "";
                }
            } else {
                if (isStruct(current) && structKeyExists(current, part)) {
                    current = current[part];
                } else {
                    return "";
                }
            }
        }

        return current;
    }

    private void function registerBuiltInFunctions() {
        variables.customFunctions["uppercase"] = function(val) { return ucase(toString(val)); };
        variables.customFunctions["lowercase"] = function(val) { return lcase(toString(val)); };
        variables.customFunctions["trim"] = function(val) { return trim(toString(val)); };
        variables.customFunctions["concat"] = function(a, b = "", c = "") { return toString(a) & toString(b) & toString(c); };
        variables.customFunctions["coalesce"] = function(a, b) { return (len(trim(toString(a))) > 0) ? a : b; };
        variables.customFunctions["round"] = function(num, decimals = 2) { return round(val(num) * (10 ^ decimals)) / (10 ^ decimals); };
        variables.customFunctions["abs"] = function(num) { return abs(val(num)); };
        variables.customFunctions["length"] = function(str) { return len(toString(str)); };
    }

    private struct function parseTernary(required string expr) {
        var qIdx = find("?", arguments.expr);
        var colonIdx = find(":", arguments.expr);
        if (qIdx > 0 && colonIdx > qIdx) {
            return {
                "condition": trim(left(arguments.expr, qIdx - 1)),
                "trueExpr": trim(mid(arguments.expr, qIdx + 1, colonIdx - qIdx - 1)),
                "falseExpr": trim(right(arguments.expr, len(arguments.expr) - colonIdx))
            };
        }
        return {};
    }

    private struct function splitBinaryOperator(required string expr) {
        var ops = ["==", "!=", ">", "<", "+", "-", "*", "/"];
        for (var op in ops) {
            var idx = find(" " & op & " ", arguments.expr);
            if (idx > 0) {
                return {
                    "left": trim(left(arguments.expr, idx - 1)),
                    "op": op,
                    "right": trim(right(arguments.expr, len(arguments.expr) - idx - len(op) - 1))
                };
            }
        }
        return {};
    }

    private array function splitArguments(required string argsStr) {
        var args = [];
        if (len(trim(arguments.argsStr)) == 0) return args;

        var parts = listToArray(arguments.argsStr, ",");
        for (var p in parts) {
            arrayAppend(args, trim(p));
        }
        return args;
    }
}
