component {

    property name="poolSize" type="numeric";
    property name="logger" type="any";
    property name="executorService" type="any";
    property name="isShutdown" type="boolean";

    /**
     * Constructor for ThreadPool executor.
     *
     * @poolSize Number of concurrent worker threads
     * @logger Logger instance
     */
    public any function init(numeric poolSize = 16, required any logger) {
        variables.poolSize = arguments.poolSize;
        variables.logger = arguments.logger;
        variables.isShutdown = false;

        var threadCounter = createObject("java", "java.util.concurrent.atomic.AtomicInteger").init(1);
        var threadGroup = createObject("java", "java.lang.ThreadGroup").init("KeystoneWorkers");

        // Custom ThreadFactory for identifiable worker threads
        var threadFactory = createDynamicProxy(
            new WorkerThreadFactory(threadCounter, threadGroup),
            ["java.util.concurrent.ThreadFactory"]
        );

        // Fixed thread pool executor
        variables.executorService = createObject("java", "java.util.concurrent.Executors").newFixedThreadPool(
            javaCast("int", variables.poolSize),
            threadFactory
        );

        return this;
    }

    /**
     * Submits a closure task to be executed by the thread pool.
     *
     * @task Closure with signature ()
     */
    public any function submit(required any task) {
        if (variables.isShutdown) {
            throw(type="ThreadPoolShutdownException", message="Cannot submit task: ThreadPool is shutdown.");
        }

        var runnableProxy = createDynamicProxy(
            new TaskRunnable(arguments.task, variables.logger),
            ["java.lang.Runnable"]
        );

        return variables.executorService.submit(runnableProxy);
    }

    /**
     * Executes a fire-and-forget task asynchronously.
     */
    public void function execute(required any task) {
        submit(arguments.task);
    }

    /**
     * Initiates graceful shutdown of worker threads.
     */
    public void function shutdown() {
        variables.isShutdown = true;
        variables.executorService.shutdown();
        try {
            var timeUnit = createObject("java", "java.util.concurrent.TimeUnit").SECONDS;
            if (!variables.executorService.awaitTermination(5, timeUnit)) {
                variables.executorService.shutdownNow();
            }
        } catch (any e) {
            variables.executorService.shutdownNow();
        }
    }

    public struct function getStats() {
        var isTerminated = variables.executorService.isTerminated();
        return {
            "configuredPoolSize": variables.poolSize,
            "isShutdown": variables.isShutdown,
            "isTerminated": isTerminated
        };
    }
}
