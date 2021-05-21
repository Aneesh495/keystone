component {

    property name="expressionEngine" type="any";
    property name="valueTransforms" type="any";
    property name="codeLookupTable" type="any";
    property name="logger" type="any";

    /**
     * Constructor for SchemaMapper.
     */
    public any function init(
        any expressionEngine = nullValue(),
        any valueTransforms = nullValue(),
        any codeLookupTable = nullValue(),
        any logger = nullValue()
    ) {
        variables.expressionEngine = isNull(arguments.expressionEngine) ? new app.transform.ExpressionEngine() : arguments.expressionEngine;
        variables.valueTransforms = isNull(arguments.valueTransforms) ? new app.transform.ValueTransforms() : arguments.valueTransforms;
        variables.codeLookupTable = isNull(arguments.codeLookupTable) ? new app.transform.CodeLookupTable() : arguments.codeLookupTable;
        variables.logger = arguments.logger;
        return this;
    }

    /**
     * Executes declarative transformation specification on source data.
     *
     * @sourceData Struct representing source document AST
     * @mappingDefinition Array of rule structs:
     *   [
     *     { "type": "direct", "source": "ast.header.poNumber", "target": "poNumber" },
     *     { "type": "expression", "expr": "toIsoDate(ast.header.date)", "target": "orderDate" },
     *     { "type": "loop", "source": "segments", "filter": "id=='PO1'", "as": "item", "target": "items", "rules": [...] }
     *   ]
     * @return Transformed target data struct
     */
    public struct function transform(required struct sourceData, required array mappingDefinition) {
        var context = new app.transform.MappingContext(sourceData = arguments.sourceData);

        for (var rule in arguments.mappingDefinition) {
            applyRule(rule, context);
        }

        return context.getTargetData();
    }

    private void function applyRule(required struct rule, required any context) {
        var ruleType = arguments.rule.type ?: "direct";

        // Check rule condition if specified
        if (structKeyExists(arguments.rule, "condition") && len(trim(arguments.rule.condition))) {
            var condResult = variables.expressionEngine.evaluate(arguments.rule.condition, buildScope(arguments.context));
            if (!isBoolean(condResult) || !condResult) {
                return;
            }
        }

        if (ruleType == "direct") {
            var val = variables.expressionEngine.resolvePath(arguments.rule.source, arguments.context.getSourceData());
            arguments.context.setTarget(arguments.rule.target, val);
        } else if (ruleType == "expression") {
            var scopeMap = buildScope(arguments.context);
            var computed = variables.expressionEngine.evaluate(arguments.rule.expr, scopeMap);
            arguments.context.setTarget(arguments.rule.target, computed);
        } else if (ruleType == "lookup") {
            var keyVal = variables.expressionEngine.resolvePath(arguments.rule.source, arguments.context.getSourceData());
            var lookupResult = variables.codeLookupTable.lookup(arguments.rule.table, toString(keyVal), arguments.rule.default ?: "");
            arguments.context.setTarget(arguments.rule.target, lookupResult);
        } else if (ruleType == "loop") {
            executeLoopRule(arguments.rule, arguments.context);
        }
    }

    private void function executeLoopRule(required struct rule, required any context) {
        var srcPath = arguments.rule.source;
        var asVar = arguments.rule.as ?: "item";
        var targetArrayPath = arguments.rule.target;
        var innerRules = arguments.rule.rules ?: [];

        var items = variables.expressionEngine.resolvePath(srcPath, arguments.context.getSourceData());
        if (!isArray(items)) {
            return;
        }

        for (var item in items) {
            // Check loop item filter if specified (e.g. filterId: 'PO1')
            if (structKeyExists(arguments.rule, "filterId") && isStruct(item)) {
                if (!structKeyExists(item, "id") || item.id != arguments.rule.filterId) {
                    continue;
                }
            }

            arguments.context.setVar(asVar, item);

            // Execute sub-transformation for this item
            var itemContext = new app.transform.MappingContext(sourceData = item);
            itemContext.setVar(asVar, item);

            for (var subRule in innerRules) {
                if (subRule.type == "direct") {
                    var val = variables.expressionEngine.resolvePath(subRule.source, item);
                    itemContext.setTarget(subRule.target, val);
                } else if (subRule.type == "expression") {
                    var subScope = { "item": item, "source": arguments.context.getSourceData() };
                    var computed = variables.expressionEngine.evaluate(subRule.expr, subScope);
                    itemContext.setTarget(subRule.target, computed);
                }
            }

            arguments.context.appendTargetArray(targetArrayPath, itemContext.getTargetData());
        }
    }

    private struct function buildScope(required any context) {
        var scope = duplicate(arguments.context.getSourceData());
        scope["source"] = arguments.context.getSourceData();
        scope["target"] = arguments.context.getTargetData();
        return scope;
    }
}
