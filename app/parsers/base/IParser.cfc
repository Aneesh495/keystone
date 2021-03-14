component {

    /**
     * Base interface for all Keystone protocol parsers.
     */
    public any function init() {
        return this;
    }

    /**
     * Parses a raw protocol payload into a standardized AST.
     *
     * @rawInput The raw protocol payload string
     * @options Parsing configuration options
     * @return app.parsers.base.ParseResult instance
     */
    public any function parse(required string rawInput, struct options = {}) {
        throw(type="NotImplementedException", message="Method parse() must be implemented by concrete parser subclasses.");
    }

    /**
     * Identifies whether the parser can handle the provided raw payload based on prefix or header inspection.
     *
     * @rawInput The raw protocol payload string
     * @return Boolean indicator
     */
    public boolean function canParse(required string rawInput) {
        return false;
    }
}
