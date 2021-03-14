component {

    /**
     * Base interface for all Keystone protocol serializers.
     */
    public any function init() {
        return this;
    }

    /**
     * Serializes an in-memory document AST into wire format string.
     *
     * @ast Structured AST document
     * @options Serialization configuration options
     * @return Wire format representation string
     */
    public string function serialize(required struct ast, struct options = {}) {
        throw(type="NotImplementedException", message="Method serialize() must be implemented by concrete serializer subclasses.");
    }
}
