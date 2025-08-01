/**
 * @file Handles delaying and dispatching of DOMContentLoaded and load events.
 */
import { log } from './log';

/**
 * The interceptors delay the events until either a response is received or the
 * timeout expires. If the events have already fired, no interceptors are added.
 *
 * In Safari extensions running scripts and scriptlets has a slight delay and
 * the page scripts may already do their work. By delaying DOMContentLoaded and
 * load we try to delay the execution of page scripts so that the extension's
 * scriptlets work as expected.
 *
 * @param timeoutMs - Timeout in milliseconds after which the events are forced
 *                  (if not already handled). Default is 1000ms.
 * @returns A function which, when invoked, cancels the timeout and dispatches
 *         (or removes) the interceptors.
 */
export function setupDelayedEventDispatcher(timeoutMs = 1000): () => void {
    interface Interceptor {
        name: string;
        options: EventInit;
        intercepted: boolean;
        listener: EventListener;
        target: EventTarget;
    }

    const interceptors: Interceptor[] = [];
    const events = [
        {
            name: 'DOMContentLoaded',
            options: { bubbles: true, cancelable: false },
            target: document,
        },
        {
            name: 'load',
            options: { bubbles: false, cancelable: false },
            target: window,
        },
    ];

    events.forEach((ev) => {
        const interceptor: Interceptor = {
            name: ev.name,
            options: ev.options,
            intercepted: false,
            target: ev.target,
            listener: (event: Event) => {
                // Prevent immediate propagation.
                event.stopImmediatePropagation();
                interceptor.intercepted = true;

                log.debug('Event has been intercepted:', ev.name);
            },
        };
        interceptors.push(interceptor);

        interceptor.target.addEventListener(ev.name, interceptor.listener, { capture: true });
    });

    let dispatched = false;
    const dispatchEvents = (trigger: string) => {
        if (dispatched) {
            // The events were already dispatched, do nothing.
            return;
        }
        dispatched = true;
        interceptors.forEach((interceptor) => {
            // Remove the interceptor listener.
            interceptor.target.removeEventListener(interceptor.name, interceptor.listener, { capture: true });
            if (interceptor.intercepted) {
                // If intercepted, dispatch the event manually so downstream listeners eventually receive it.
                const newEvent = new Event(interceptor.name, interceptor.options);
                interceptor.target.dispatchEvent(newEvent);

                const targetName = interceptor.target === document ? 'document' : 'window';
                log.debug(`${interceptor.name} event re-dispatched due to ${trigger} on ${targetName}.`);
            } else {
                log.debug(`Interceptor for ${interceptor.name} removed due to ${trigger}.`);
            }
        });
    };

    // Set a timer to automatically dispatch the events after the timeout.
    const timer = setTimeout(() => {
        dispatchEvents('timeout');
    }, timeoutMs);

    // Return a function to cancel the timer and dispatch events immediately.
    return () => {
        clearTimeout(timer);
        dispatchEvents('response received');
    };
}
