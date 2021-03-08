component {

    property name="counter" type="any";
    property name="group" type="any";

    public any function init(required any counter, required any group) {
        variables.counter = arguments.counter;
        variables.group = arguments.group;
        return this;
    }

    public any function newThread(required any runnable) {
        var tName = "keystone-worker-" & variables.counter.getAndIncrement();
        var thread = createObject("java", "java.lang.Thread").init(
            variables.group,
            arguments.runnable,
            tName
        );
        thread.setDaemon(true);
        thread.setPriority(5);
        return thread;
    }
}
