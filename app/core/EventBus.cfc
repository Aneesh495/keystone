component {

    property name="logger" type="any";
    property name="listeners" type="struct";
    property name="metrics" type="struct";

    /**
     * Constructor for EventBus.
     */
    public any function init(required any logger) {
        variables.logger = arguments.logger;
        variables.listeners = {};
        variables.metrics = {
            "eventsPublished": 0,
            "dispatchesCompleted": 0,
            "dispatchErrors": 0
        };
        return this;
    }

    /**
     * Subscribes a callback to an event pattern.
     *
     * @eventName Event pattern, supports wildcard suffix like 'transaction.*'
     * @handler Closure or function callback taking (eventPayload, eventName)
     * @priority Numerical priority (higher runs earlier, default 50)
     * @return Subscription ID for unregistering
     */
    public string function subscribe(required string eventName, required any handler, numeric priority = 50) {
        var subId = createUUID();
        var entry = {
            "id": subId,
            "pattern": arguments.eventName,
            "handler": arguments.handler,
            "priority": arguments.priority
        };

        lock name="keystone_eventbus_lock" type="exclusive" timeout="3" {
            if (!structKeyExists(variables.listeners, arguments.eventName)) {
                variables.listeners[arguments.eventName] = [];
            }
            arrayAppend(variables.listeners[arguments.eventName], entry);
            // Sort by priority descending
            arraySort(variables.listeners[arguments.eventName], function(a, b) {
                return b.priority - a.priority;
            });
        }

        return subId;
    }

    /**
     * Unsubscribes a listener by subscription ID.
     */
    public boolean function unsubscribe(required string subscriptionId) {
        var removed = false;
        lock name="keystone_eventbus_lock" type="exclusive" timeout="3" {
            for (var pattern in variables.listeners) {
                var list = variables.listeners[pattern];
                for (var i = arrayLen(list); i >= 1; i--) {
                    if (list[i].id == arguments.subscriptionId) {
                        arrayDeleteAt(list, i);
                        removed = true;
                    }
                }
            }
        }
        return removed;
    }

    /**
     * Publishes an event synchronously to all matching subscribers.
     */
    public void function publish(required string eventName, struct payload = {}) {
        variables.metrics.eventsPublished++;
        var matchedHandlers = resolveHandlers(arguments.eventName);

        for (var listener in matchedHandlers) {
            try {
                listener.handler(arguments.payload, arguments.eventName);
                variables.metrics.dispatchesCompleted++;
            } catch (any e) {
                variables.metrics.dispatchErrors++;
                variables.logger.error("EventBus handler failed for event: " & arguments.eventName, {
                    "error": e.message,
                    "listenerId": listener.id
                });
            }
        }
    }

    /**
     * Publishes an event asynchronously in a background thread.
     */
    public void function publishAsync(required string eventName, struct payload = {}) {
        var self = this;
        var evt = arguments.eventName;
        var data = duplicate(arguments.payload);

        cfthread(action="run", name="evt_async_" & createUUID()) {
            self.publish(evt, data);
        }
    }

    /**
     * Resolves all handlers matching an event name (exact or wildcard).
     */
    public array function resolveHandlers(required string eventName) {
        var result = [];
        lock name="keystone_eventbus_lock" type="readOnly" timeout="2" {
            for (var pattern in variables.listeners) {
                if (matchesPattern(arguments.eventName, pattern)) {
                    var list = variables.listeners[pattern];
                    for (var item in list) {
                        arrayAppend(result, item);
                    }
                }
            }
        }

        // Re-sort matched handlers by priority
        arraySort(result, function(a, b) {
            return b.priority - a.priority;
        });

        return result;
    }

    public struct function getMetrics() {
        return duplicate(variables.metrics);
    }

    public numeric function getListenerCount() {
        var count = 0;
        lock name="keystone_eventbus_lock" type="readOnly" timeout="2" {
            for (var k in variables.listeners) {
                count += arrayLen(variables.listeners[k]);
            }
        }
        return count;
    }

    private boolean function matchesPattern(required string eventName, required string pattern) {
        if (arguments.pattern == "*" || arguments.pattern == arguments.eventName) {
            return true;
        }

        if (right(arguments.pattern, 2) == ".*") {
            var prefix = left(arguments.pattern, len(arguments.pattern) - 2);
            return findNoCase(prefix & ".", arguments.eventName) == 1;
        }

        return false;
    }
}
