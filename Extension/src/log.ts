/* eslint-disable no-console */
/* eslint-disable class-methods-use-this */
/* eslint-disable max-classes-per-file */

/**
 * @file Defines the logger interface and its default implementation.
 */

/**
 * Logging level.
 */
export enum LoggingLevel {
    Debug = 2,
    Info = 1,
    Error = 0,
}

/**
 * Logger interface.
 */
export interface Logger {
    level: LoggingLevel;

    debug(...args: unknown[]): void;
    info(...args: unknown[]): void;
    error(...args: unknown[]): void;
}

const getTimestamp = (): string => `[${new Date().toISOString()}]`;

/**
 * Console logger implementation.
 */
export class ConsoleLogger implements Logger {
    private prefix: string = '[Safari Extension]';

    private loggingLevel: LoggingLevel = LoggingLevel.Info;

    /**
     * Creates a new console logger.
     *
     * @param prefix Prefix to add to the log messages.
     * @param level Logging level.
     */
    constructor(prefix: string, level: LoggingLevel) {
        this.prefix = prefix;
        this.loggingLevel = level;
    }

    get level(): LoggingLevel {
        return this.loggingLevel;
    }

    set level(level: LoggingLevel) {
        this.loggingLevel = level;
    }

    debug(...args: unknown[]): void {
        if (this.loggingLevel >= LoggingLevel.Debug) {
            console.debug(getTimestamp(), this.prefix, ...args);
        }
    }

    info(...args: unknown[]): void {
        if (this.loggingLevel >= LoggingLevel.Info) {
            console.info(getTimestamp(), this.prefix, ...args);
        }
    }

    error(...args: unknown[]): void {
        if (this.loggingLevel >= LoggingLevel.Error) {
            console.error(getTimestamp(), this.prefix, ...args);
        }
    }
}

/**
 * Logger that does not print anything.
 */
export class NullLogger implements Logger {
    level: LoggingLevel = LoggingLevel.Debug;

    debug(): void {
        // Do nothing.
    }

    info(): void {
        // Do nothing.
    }

    error(): void {
        // Do nothing.
    }
}

/**
 * Default logger. Can be redefined by the library user.
 */
let internalLogger: Logger = new NullLogger();

/**
 * Sets the logger to use.
 *
 * @param logger to use.
 */
const setLogger = (logger: Logger): void => {
    internalLogger = logger;
};

/**
 * Proxy logger that delegates all calls to the internal logger.
 * This internal logger can be redefined by the library user
 * via `setLogger`.
 */
class ProxyLogger implements Logger {
    get level(): LoggingLevel {
        return internalLogger.level;
    }

    set level(level: LoggingLevel) {
        internalLogger.level = level;
    }

    debug(...args: unknown[]): void {
        internalLogger.debug(...args);
    }

    info(...args: unknown[]): void {
        internalLogger.info(...args);
    }

    error(...args: unknown[]): void {
        internalLogger.error(...args);
    }
}

export const log: Logger = new ProxyLogger();
export {
    setLogger,
};
