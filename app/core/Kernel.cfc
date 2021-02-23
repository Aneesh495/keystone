component {

    // Properties for core kernel subsystems
    property name="rootDir" type="string";
    property name="isBootstrapped" type="boolean";
    property name="bootstrappedAt" type="date";
    property name="subsystems" type="struct";

    /**
     * Constructor for the Keystone Runtime Kernel.
     *
     * @rootDir Root directory of the application
     */
    public any function init(required string rootDir) {
        variables.rootDir = arguments.rootDir;
        variables.isBootstrapped = false;
        variables.bootstrappedAt = now();
        variables.subsystems = {};
        return this;
    }

    /**
     * Bootstraps all core subsystems in strict dependency order.
     */
    public void function bootstrap() {
        if (variables.isBootstrapped) {
            return;
        }

        // Phase 1: Configuration and logging
        variables.subsystems["config"] = new app.core.Config(rootDir = variables.rootDir);
        variables.subsystems["config"].load();

        variables.subsystems["logger"] = new app.core.Logger(
            config = variables.subsystems["config"],
            logDir = variables.rootDir & "logs"
        );
        variables.subsystems["logger"].info("Initializing Keystone Runtime Kernel...");

        // Phase 2: Runtime primitives and concurrency
        variables.subsystems["idGenerator"] = new app.core.IdGenerator(
            nodeId = variables.subsystems["config"].get("node.id", 1)
        );

        variables.subsystems["eventBus"] = new app.core.EventBus(
            logger = variables.subsystems["logger"]
        );

        variables.subsystems["threadPool"] = new app.core.ThreadPool(
            poolSize = variables.subsystems["config"].get("concurrency.poolSize", 16),
            logger = variables.subsystems["logger"]
        );

        variables.subsystems["lockManager"] = new app.core.LockManager(
            lockDir = variables.rootDir & "storage/locks",
            logger = variables.subsystems["logger"]
        );

        variables.subsystems["cacheStore"] = new app.core.CacheStore(
            maxSize = variables.subsystems["config"].get("cache.maxEntries", 10000),
            defaultTtlSeconds = variables.subsystems["config"].get("cache.ttlSeconds", 3600)
        );

        // Phase 3: Observability and Telemetry
        variables.subsystems["metrics"] = new app.telemetry.MetricsCollector();
        variables.subsystems["hdrHistogram"] = new app.telemetry.HdrHistogram();
        variables.subsystems["prometheus"] = new app.telemetry.PrometheusExporter(
            metrics = variables.subsystems["metrics"]
        );

        // Phase 4: Security and Cryptographic Audit
        variables.subsystems["crypto"] = new app.security.CryptoEngine(
            masterSecret = variables.subsystems["config"].get("security.masterSecret", "keystone-default-secret-salt-32b")
        );

        variables.subsystems["certStore"] = new app.security.CertificateStore(
            certDir = variables.rootDir & "storage/certs",
            logger = variables.subsystems["logger"]
        );

        variables.subsystems["auditLedger"] = new app.security.AuditLedger(
            storageDir = variables.rootDir & "storage/audit",
            crypto = variables.subsystems["crypto"],
            logger = variables.subsystems["logger"]
        );

        // Phase 5: Registries and Agreements
        variables.subsystems["partnerRegistry"] = new app.registry.PartnerRegistry(
            storageDir = variables.rootDir & "storage/partners",
            logger = variables.subsystems["logger"]
        );

        variables.subsystems["agreementManager"] = new app.registry.AgreementManager(
            partnerRegistry = variables.subsystems["partnerRegistry"],
            logger = variables.subsystems["logger"]
        );

        variables.subsystems["workflowRegistry"] = new app.registry.WorkflowRegistry(
            logger = variables.subsystems["logger"]
        );

        // Phase 6: Distributed Transactions and Sagas
        variables.subsystems["idempotencyStore"] = new app.transactions.IdempotencyStore(
            cacheStore = variables.subsystems["cacheStore"],
            ttlSeconds = 86400
        );

        variables.subsystems["deadLetterQueue"] = new app.transactions.DeadLetterQueue(
            storageDir = variables.rootDir & "storage/dlq",
            logger = variables.subsystems["logger"]
        );

        variables.subsystems["outboxProcessor"] = new app.transactions.OutboxProcessor(
            storageDir = variables.rootDir & "storage/outbox",
            logger = variables.subsystems["logger"],
            threadPool = variables.subsystems["threadPool"]
        );

        variables.subsystems["sagaCoordinator"] = new app.transactions.SagaCoordinator(
            journalDir = variables.rootDir & "storage/journal",
            eventBus = variables.subsystems["eventBus"],
            logger = variables.subsystems["logger"],
            metrics = variables.subsystems["metrics"]
        );

        // Phase 7: Transformation and Expression Engine
        variables.subsystems["expressionEngine"] = new app.transform.ExpressionEngine();
        variables.subsystems["valueTransforms"] = new app.transform.ValueTransforms();
        variables.subsystems["schemaMapper"] = new app.transform.SchemaMapper(
            expressionEngine = variables.subsystems["expressionEngine"],
            valueTransforms = variables.subsystems["valueTransforms"],
            logger = variables.subsystems["logger"]
        );

        // Phase 8: Protocol Ingress and Routing
        variables.subsystems["httpRouter"] = new app.network.HttpRouter(
            kernel = this,
            logger = variables.subsystems["logger"]
        );
        variables.subsystems["httpRouter"].registerRoutes();

        variables.isBootstrapped = true;
        variables.bootstrappedAt = now();
        variables.subsystems["logger"].info("Keystone Runtime Kernel successfully bootstrapped.");
    }

    /**
     * Shuts down all active services, flushes journals, and releases thread pools.
     */
    public void function shutdown() {
        if (!variables.isBootstrapped) {
            return;
        }

        if (structKeyExists(variables.subsystems, "logger")) {
            variables.subsystems["logger"].info("Initiating Keystone Runtime Kernel shutdown sequence...");
        }

        // Flush outbox and journal
        if (structKeyExists(variables.subsystems, "sagaCoordinator")) {
            variables.subsystems["sagaCoordinator"].flush();
        }

        if (structKeyExists(variables.subsystems, "outboxProcessor")) {
            variables.subsystems["outboxProcessor"].flush();
        }

        // Release thread pool
        if (structKeyExists(variables.subsystems, "threadPool")) {
            variables.subsystems["threadPool"].shutdown();
        }

        variables.isBootstrapped = false;
        if (structKeyExists(variables.subsystems, "logger")) {
            variables.subsystems["logger"].info("Keystone Runtime Kernel halted cleanly.");
        }
    }

    // Typed subsystem accessors
    public any function getConfig() { return variables.subsystems["config"]; }
    public any function getLogger() { return variables.subsystems["logger"]; }
    public any function getIdGenerator() { return variables.subsystems["idGenerator"]; }
    public any function getEventBus() { return variables.subsystems["eventBus"]; }
    public any function getThreadPool() { return variables.subsystems["threadPool"]; }
    public any function getLockManager() { return variables.subsystems["lockManager"]; }
    public any function getCacheStore() { return variables.subsystems["cacheStore"]; }
    public any function getMetrics() { return variables.subsystems["metrics"]; }
    public any function getHdrHistogram() { return variables.subsystems["hdrHistogram"]; }
    public any function getPrometheus() { return variables.subsystems["prometheus"]; }
    public any function getCrypto() { return variables.subsystems["crypto"]; }
    public any function getCertStore() { return variables.subsystems["certStore"]; }
    public any function getAuditLedger() { return variables.subsystems["auditLedger"]; }
    public any function getPartnerRegistry() { return variables.subsystems["partnerRegistry"]; }
    public any function getAgreementManager() { return variables.subsystems["agreementManager"]; }
    public any function getWorkflowRegistry() { return variables.subsystems["workflowRegistry"]; }
    public any function getIdempotencyStore() { return variables.subsystems["idempotencyStore"]; }
    public any function getDeadLetterQueue() { return variables.subsystems["deadLetterQueue"]; }
    public any function getOutboxProcessor() { return variables.subsystems["outboxProcessor"]; }
    public any function getSagaCoordinator() { return variables.subsystems["sagaCoordinator"]; }
    public any function getExpressionEngine() { return variables.subsystems["expressionEngine"]; }
    public any function getValueTransforms() { return variables.subsystems["valueTransforms"]; }
    public any function getSchemaMapper() { return variables.subsystems["schemaMapper"]; }
    public any function getHttpRouter() { return variables.subsystems["httpRouter"]; }
    public boolean function isBootstrapped() { return variables.isBootstrapped; }
    public date function getBootstrappedAt() { return variables.bootstrappedAt; }
    public string function getRootDir() { return variables.rootDir; }
}
