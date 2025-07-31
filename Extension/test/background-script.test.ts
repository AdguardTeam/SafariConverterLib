/* eslint-disable @typescript-eslint/dot-notation */

/**
 * @file Contains tests for the BackgroundScript class.
 */

import {
    vi,
    expect,
    test,
    describe,
    beforeEach,
    afterEach,
    type MockedFunction,
} from 'vitest';
import browser from 'webextension-polyfill';
import { scriptlets as ScriptletsAPI } from '@adguard/scriptlets';

import { BackgroundScript, type ScriptFunction } from '../src/background-script';
import { type Configuration } from '../src/configuration';
import { SCRIPTLET_ENGINE_NAME } from '../src/common';
import { version as extensionVersion } from '../package.json';

// Mock browser.scripting API
vi.mock('webextension-polyfill', () => ({
    default: {
        scripting: {
            executeScript: vi.fn(),
            insertCSS: vi.fn(),
        },
    },
}));

// Mock scriptlets API
vi.mock('@adguard/scriptlets', () => ({
    scriptlets: {
        getScriptletFunction: vi.fn(),
    },
}));

describe('BackgroundScript', () => {
    let backgroundScript: BackgroundScript;
    let registeredScripts: Map<string, ScriptFunction>;
    let mockExecuteScript: MockedFunction<typeof browser.scripting.executeScript>;
    let mockInsertCSS: MockedFunction<typeof browser.scripting.insertCSS>;
    let mockGetScriptletFunction: MockedFunction<typeof ScriptletsAPI.getScriptletFunction>;

    beforeEach(() => {
        // Reset all mocks
        vi.clearAllMocks();

        // Setup registered scripts
        registeredScripts = new Map();
        const mockFunction: ScriptFunction = vi.fn();
        registeredScripts.set('test-script', mockFunction);

        // Create BackgroundScript instance
        backgroundScript = new BackgroundScript(registeredScripts);

        // Setup browser API mocks
        mockExecuteScript = browser.scripting.executeScript as MockedFunction<typeof browser.scripting.executeScript>;
        mockInsertCSS = browser.scripting.insertCSS as MockedFunction<typeof browser.scripting.insertCSS>;
        mockGetScriptletFunction = ScriptletsAPI.getScriptletFunction as
            MockedFunction<typeof ScriptletsAPI.getScriptletFunction>;

        // Default successful responses
        mockExecuteScript.mockResolvedValue([{
            result: undefined,
            frameId: 0,
        }]);
        mockInsertCSS.mockResolvedValue();
    });

    afterEach(() => {
        vi.clearAllMocks();
    });

    describe('constructor', () => {
        test('should create instance with registered scripts', () => {
            expect(backgroundScript).toBeDefined();
            expect(backgroundScript['registeredScripts']).toBe(registeredScripts);
        });
    });

    describe('applyConfiguration', () => {
        test('should apply complete configuration successfully', async () => {
            // Arrange
            const configuration: Configuration = {
                css: ['.test { color: red; }', '.banner'],
                extendedCss: ['.extended { display: none; }'],
                js: [
                    'test-script',
                    'console.log("test");',
                ],
                scriptlets: [{ name: 'test-scriptlet', args: ['arg1', 'arg2'] }],
                engineTimestamp: 123456,
            };

            mockGetScriptletFunction.mockReturnValue(vi.fn());

            // Act
            await backgroundScript.applyConfiguration(1, 0, configuration);

            // Assert
            expect(mockExecuteScript).toHaveBeenCalledTimes(4);
            expect(mockInsertCSS).toHaveBeenCalledTimes(1);

            // Assert css
            expect(mockInsertCSS).toHaveBeenCalledWith({
                target: {
                    tabId: 1,
                    frameIds: [0],
                },
                origin: 'USER',
                css: '.test { color: red; }\n.banner {display:none!important;}',
            });

            // Assert extendedCss
            expect(mockExecuteScript).toHaveBeenCalledWith({
                target: {
                    tabId: 1,
                    frameIds: [0],
                },
                func: expect.any(Function),
                args: [['.extended { display: none; }']],
                world: 'ISOLATED',
                injectImmediately: true,
            });

            // Assert scriptlets
            expect(mockExecuteScript).toHaveBeenCalledWith({
                target: {
                    tabId: 1,
                    frameIds: [0],
                },
                func: expect.any(Function),
                args: [
                    {
                        args: ['arg1', 'arg2'],
                        engine: SCRIPTLET_ENGINE_NAME,
                        name: 'test-scriptlet',
                        verbose: true,
                        version: extensionVersion,
                    },
                    ['arg1', 'arg2'],
                ],
                world: 'MAIN',
                injectImmediately: true,
            });

            // Assert registered scripts
            expect(mockExecuteScript).toHaveBeenCalledWith({
                target: {
                    tabId: 1,
                    frameIds: [0],
                },
                func: expect.any(Function),
                args: [['console.log("test");']],
                world: 'ISOLATED',
                injectImmediately: true,
            });

            expect(mockExecuteScript).toHaveBeenCalledWith({
                target: {
                    tabId: 1,
                    frameIds: [0],
                },
                func: expect.any(Function),
                world: 'MAIN',
                injectImmediately: true,
            });
        });

        test('should handle empty configuration', async () => {
            // Arrange
            const configuration: Configuration = {
                css: [],
                extendedCss: [],
                js: [],
                scriptlets: [],
                engineTimestamp: 0,
            };

            // Act
            await backgroundScript.applyConfiguration(1, 0, configuration);

            // Assert
            expect(mockExecuteScript).not.toHaveBeenCalled();
            expect(mockInsertCSS).not.toHaveBeenCalled();
        });
    });
});
