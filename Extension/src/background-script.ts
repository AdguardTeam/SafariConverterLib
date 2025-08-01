/**
 * @file Exports `BackgroundScript` object that it supposed to be used by
 * web extension's background script.
 */

import browser from 'webextension-polyfill';
import { type Source as ScriptletSource, scriptlets as ScriptletsAPI } from '@adguard/scriptlets';

import { type Scriptlet, type Configuration } from './configuration';
import { SCRIPTLET_ENGINE_NAME, toCSSRules } from './common';
import { version as extensionVersion } from '../package.json';
import { log, LoggingLevel } from './log';
import type { AdGuard } from './content-types';

/**
 * Type of the registered script function.
 */
export declare type ScriptFunction = (args: unknown[]) => unknown;

// Declare `adguard` as a global variable, but it is actually
// only available in the `ISOLATED` world.
declare global {
    const adguard: AdGuard;
}

/**
 * `BackgroundScript` is a class that is used by web extension's background
 * script to apply the configuration to the web page. It uses
 * `browser.scripting` API to inject scripts and CSS into the web page.
 *
 * It's important that for correct work this class relies on the presence of
 * `adguard.contentScript` object in the `ISOLATED` world that implements
 * `ContentScript` interface.
 */
export class BackgroundScript {
    /**
     * Map of registered script functions.
     */
    private readonly registeredScripts: Map<string, ScriptFunction>;

    /**
     * Creates an instance of the `BackgroundScript` object.
     *
     * The constructor accepts a map of registered functions. The idea is that
     * we would like JS rules to work in the same way as scriptlets, i.e. use
     * `browser.scripting.executeScript` with `world: 'MAIN'` In order to do
     * that we need to deal with JS functions. Unfortunately, due to security
     * limitations we cannot create `Function` objects from script text inside
     * the extension. To overcome that we can prepare a map of script texts and
     * functions. This map should be constructed in compile time and then
     * passed to the constructor. Whenever the script rule is applied, we will
     * first check if there's a registered `Function` object for the script
     * text and if there is, it will be used to execute the script. Otherwise,
     * we will attempt to execute it as a string (but the website CSP may
     * prevent that).
     *
     * @param registeredScripts Map of registered script functions.
     */
    constructor(registeredScripts: Map<string, ScriptFunction> = new Map()) {
        this.registeredScripts = registeredScripts;

        // Make sure that the default registered script is always added to the
        // map. This is a default registered script that is used on
        // testcases.agrd.dev for CSP tests.
        this.registeredScripts.set('console.log(Date.now(), "default registered script")', () => {
            // eslint-disable-next-line no-console
            console.log(Date.now(), 'default registered script');
        });
    }

    /**
     * Applies the configuration to the given tab and frame.
     *
     * @param tabId ID of the tab to apply the configuration to.
     * @param frameId ID of the frame to apply the configuration to.
     * @param configuration Configuration to apply.
     * @returns Promise that resolves when the configuration is applied.
     */
    public async applyConfiguration(tabId: number, frameId: number, configuration: Configuration) {
        log.debug('Applying configuration to tab', tabId, 'frame', frameId, 'configuration', configuration);

        await Promise.all(
            [
                BackgroundScript.insertCss(tabId, frameId, configuration.css),
                BackgroundScript.insertExtendedCss(tabId, frameId, configuration.extendedCss),
                BackgroundScript.runScriptlets(tabId, frameId, configuration.scriptlets),
                BackgroundScript.runScripts(tabId, frameId, configuration.js, this.registeredScripts),
            ],
        );

        log.debug('Finished applying configuration to tab', tabId, 'frame', frameId);
    }

    /**
     * Wrapper over `browser.scripting.scriptInjection` that logs errors.
     *
     * @param scriptInjection Script injection to execute.
     */
    private static async executeScript(scriptInjection: browser.Scripting.ScriptInjection) {
        const results = await browser.scripting.executeScript(scriptInjection);

        if (results.length === 0) {
            log.error('Failed to execute script in target', scriptInjection.target);

            return;
        }

        const result = results[0];

        if (result.error) {
            log.error('Failed to execute script in target', scriptInjection.target, 'error', result.error);
        }
    }

    /**
     * Runs scripts in the given tab and frame.
     *
     * @param tabId ID of the tab to run the scripts in.
     * @param frameId ID of the frame to run the scripts in.
     * @param scripts Scripts to run.
     * @param registeredScripts Map of registered script functions.
     * @returns Promise that resolves when the scripts are run.
     */
    private static async runScripts(
        tabId: number,
        frameId: number,
        scripts: string[],
        registeredScripts: Map<string, ScriptFunction>,
    ) {
        if (scripts.length === 0) {
            log.debug('No scripts to run in tab', tabId, 'frame', frameId);
            return;
        }

        // Scan scripts for registered functions.
        const scriptFunctions: ScriptFunction[] = [];
        const scriptTexts: string[] = [];
        for (const script of scripts) {
            const scriptFunction = registeredScripts.get(script);
            if (scriptFunction) {
                scriptFunctions.push(scriptFunction);
            } else {
                scriptTexts.push(script);
            }
        }

        log.debug(
            'Found',
            scriptFunctions.length,
            'registered functions and',
            scriptTexts.length,
            'scripts to run in tab',
            tabId,
            'frame',
            frameId,
        );

        await Promise.all([
            BackgroundScript.runScriptFunctions(tabId, frameId, scriptFunctions),
            BackgroundScript.runScriptTexts(tabId, frameId, scriptTexts),
        ]);

        log.debug('Finished running scripts in tab', tabId, 'frame', frameId);
    }

    /**
     * Runs script functions in the given tab and frame.
     *
     * @param tabId ID of the tab to run the scripts in.
     * @param frameId ID of the frame to run the scripts in.
     * @param scriptFunctions Scripts to run.
     * @returns Promise that resolves when the scripts are run.
     */
    private static async runScriptFunctions(tabId: number, frameId: number, scriptFunctions: ScriptFunction[]) {
        if (scriptFunctions.length === 0) {
            log.debug('No script functions to run in tab', tabId, 'frame', frameId);

            return;
        }

        log.debug('Running script functions in tab', tabId, 'frame', frameId, 'script functions', scriptFunctions);

        const promises = scriptFunctions.map((scriptFunction) => {
            return BackgroundScript.runScriptFunction(tabId, frameId, scriptFunction);
        });

        await Promise.all(promises);

        log.debug('Finished running script functions in tab', tabId, 'frame', frameId);
    }

    /**
     * Runs a script in the given tab and frame.
     *
     * @param tabId ID of the tab to run the script in.
     * @param frameId ID of the frame to run the script in.
     * @param scriptFunction Script to run.
     * @returns Promise that resolves when the script is run.
     */
    private static async runScriptFunction(tabId: number, frameId: number, scriptFunction: ScriptFunction) {
        log.debug('Running script function in tab', tabId, 'frame', frameId, 'script function', scriptFunction);

        await BackgroundScript.executeScript({
            target: {
                tabId,
                frameIds: [frameId],
            },
            func: scriptFunction as (...args: unknown[]) => unknown,
            world: 'MAIN',
            injectImmediately: true,
        });

        log.debug('Finished running script function in tab', tabId, 'frame', frameId);
    }

    /**
     * Runs script texts in the given tab and frame.
     *
     * @param tabId ID of the tab to run the script texts in.
     * @param frameId ID of the frame to run the script texts in.
     * @param scriptTexts Script texts to run.
     * @returns Promise that resolves when the script texts are run.
     */
    private static async runScriptTexts(tabId: number, frameId: number, scriptTexts: string[]) {
        if (scriptTexts.length === 0) {
            log.debug('No script texts to run in tab', tabId, 'frame', frameId);

            return;
        }

        log.debug('Running script texts in tab', tabId, 'frame', frameId, 'script texts', scriptTexts);

        await BackgroundScript.executeScript({
            target: {
                tabId,
                frameIds: [frameId],
            },
            func: (scripts: string[] = []) => {
                try {
                    adguard.contentScript.runScripts(scripts);
                } catch (e) {
                    // eslint-disable-next-line no-console
                    console.error('Failed to run scripts, make sure adguard.contentScript is available', e);
                }
            },
            args: [scriptTexts],
            world: 'ISOLATED',
            injectImmediately: true,
        });

        log.debug('Finished running script texts in tab', tabId, 'frame', frameId);
    }

    /**
     * Inserts extended CSS into the given tab and frame.
     *
     * @param tabId ID of the tab to insert extended CSS into.
     * @param frameId ID of the frame to insert extended CSS into.
     * @param extendedCss Extended CSS to insert.
     * @returns Promise that resolves when the extended CSS is inserted.
     */
    private static async insertExtendedCss(tabId: number, frameId: number, extendedCss: string[]) {
        if (extendedCss.length === 0) {
            log.debug('No extended CSS to insert into tab', tabId, 'frame', frameId);

            return;
        }

        await BackgroundScript.executeScript({
            target: {
                tabId,
                frameIds: [frameId],
            },
            func: (extCss: string[] = []) => {
                try {
                    adguard.contentScript.insertExtendedCss(extCss);
                } catch (e) {
                    // eslint-disable-next-line no-console
                    console.error('Failed to insert extended CSS, make sure adguard.contentScript is available', e);
                }
            },
            args: [extendedCss],
            world: 'ISOLATED',
            injectImmediately: true,
        });
    }

    /**
     * Inserts CSS into the given tab and frame.
     *
     * @param tabId ID of the tab to insert CSS into.
     * @param frameId ID of the frame to insert CSS into.
     * @param css CSS to insert.
     * @returns Promise that resolves when the CSS is inserted.
     */
    private static async insertCss(tabId: number, frameId: number, css: string[]) {
        if (css.length === 0) {
            log.debug('No CSS to insert into tab', tabId, 'frame', frameId);

            return;
        }

        log.debug('Inserting CSS into tab', tabId, 'frame', frameId, 'css', css);

        const cssRules = toCSSRules(css);
        const cssStyle = cssRules.join('\n');

        await browser.scripting.insertCSS({
            target: {
                tabId,
                frameIds: [frameId],
            },
            origin: 'USER',
            css: cssStyle,
        });

        log.debug('CSS inserted into tab', tabId, 'frame', frameId);
    }

    /**
     * Runs scriptlets in the given tab and frame.
     *
     * @param tabId ID of the tab to run the scriptlets in.
     * @param frameId ID of the frame to run the scriptlets in.
     * @param scriptlets Scriptlets to run.
     * @returns Promise that resolves when the scriptlets are run.
     */
    private static async runScriptlets(tabId: number, frameId: number, scriptlets: Scriptlet[]) {
        if (scriptlets.length === 0) {
            log.debug('No scriptlets to run into tab', tabId, 'frame', frameId);

            return;
        }

        log.debug('Running scriptlets in the tab', tabId, 'frame', frameId, 'scriptlets', scriptlets);

        const promises = scriptlets.map((scriptlet) => BackgroundScript.runScriptlet(tabId, frameId, scriptlet));

        await Promise.all(promises);

        log.debug('Finished running scriptlets in the tab', tabId, 'frame', frameId);
    }

    /**
     * Runs a scriptlet in the given tab and frame.
     *
     * @param tabId ID of the tab to run the scriptlet in.
     * @param frameId ID of the frame to run the scriptlet in.
     * @param scriptlet Scriptlet to run.
     * @returns Promise that resolves when the scriptlet is run.
     */
    private static async runScriptlet(tabId: number, frameId: number, scriptlet: Scriptlet) {
        log.debug('Running scriptlet', scriptlet.name, 'in the tab', tabId, 'frame', frameId);

        const scriptletFunction = ScriptletsAPI.getScriptletFunction(scriptlet.name);
        if (!scriptletFunction) {
            log.error('Scriptlet function not found', scriptlet.name);

            return;
        }

        // Use verbose logging in scriptlets when debug-level logging is
        // enabled.
        const verbose = log.level === LoggingLevel.Debug;

        const scriptletSource: ScriptletSource = {
            engine: SCRIPTLET_ENGINE_NAME,
            name: scriptlet.name,
            args: scriptlet.args,
            version: extensionVersion,
            verbose,
        };

        const args = [];
        args.push(scriptletSource);
        args.push(scriptlet.args);

        await BackgroundScript.executeScript({
            target: {
                tabId,
                frameIds: [frameId],
            },
            func: scriptletFunction,
            args,
            world: 'MAIN',
            injectImmediately: true,
        });

        log.debug('Finished running scriptlet', scriptlet.name, 'in the tab', tabId, 'frame', frameId);
    }
}
