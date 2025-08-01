/**
 * @file Entry point for the library.
 */

import { type Configuration, type Scriptlet } from './configuration';
import { ContentScript } from './content-script';
import { type ScriptFunction, BackgroundScript } from './background-script';
import { setupDelayedEventDispatcher } from './delayed-event-dispatcher';
import {
    setLogger,
    ConsoleLogger,
    type Logger,
    LoggingLevel,
} from './log';

export {
    type Configuration,
    type Scriptlet,
    type ScriptFunction,
    ContentScript,
    BackgroundScript,
    setLogger,
    LoggingLevel,
    type Logger,
    ConsoleLogger,
    setupDelayedEventDispatcher,
};
