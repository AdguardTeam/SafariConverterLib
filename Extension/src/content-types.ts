/**
 * @file Defines the types for the content script.
 */

import { type Scriptlet, type Configuration } from './configuration';

/**
 * Content script interface. The way this object is used is different and
 * depends on whether this code is used from Safari App Extension or from
 * Safari Web Extension.
 *
 * In the case of Safari App Extension, this interface is used from within
 * the content script, i.e. it is used to apply the configuration to the web
 * page.
 *
 * In the case of Safari Web Extension, `BackgroundScript` relies on the
 * functions of this interface to run scripts and insert extended CSS into the
 * web page, i.e. it expects that there will be a global `adguard.contentScript`
 * object in the `ISOLATED` world that implements this interface.
 */
export interface IContentScript {
    /**
     * Applies the configuration to the web page. This method is supposed to be
     * run from the extension's content script (ISOLATED world) and it is only
     * supposed to be used by Safari App Extension.
     *
     * @param configuration Configuration to apply.
     * @param verbose Whether to log verbose output.
     */
    applyConfiguration(configuration: Configuration, verbose: boolean): void;

    /**
     * Inserts CSS rules into the web page. This method is supposed to be run
     * from the extension's content script (ISOLATED world) and it is only
     * supposed to be used by Safari App Extension.
     *
     * @param css Array of CSS rules to insert.
     */
    insertCss(css: string[]): void;

    /**
     * Inserts Extended CSS rules into the web page. This method is supposed to
     * be run from the extension's content script (ISOLATED world) and it is
     * used by both Safari App Extension and Safari Web Extension.
     *
     * In the case of Safari Web Extension this method is exposed via
     * `adguard.contentScript` global object in `ISOLATED` world.
     *
     * @param extendedCss Array of Extended CSS rules to insert.
     */
    insertExtendedCss(extendedCss: string[]): void;

    /**
     * Runs scripts in the web page. This method is supposed to be run from the
     * extension's content script (ISOLATED world).
     *
     * In the case of Safari Web Extension this method is exposed via
     * `adguard.contentScript` global object in `ISOLATED` world.
     *
     * @param scripts Array of scripts to run.
     */
    runScripts(scripts: string[]): void;

    /**
     * Runs scriptlets in the web page. This method is supposed to be run from
     * the extension's content script (ISOLATED world).
     *
     * In the case of Safari Web Extension this method is exposed via
     * `adguard.contentScript` global object in `ISOLATED` world.
     *
     * @param scriptlets Array of scriptlets to run.
     * @param verbose Whether to log verbose output.
     */
    runScriptlets(scriptlets: Scriptlet[], verbose: boolean): void;
}

/**
 * AdGuard interface. In the case of Safari Web Extension `BackgroundScript`
 * relies on this interface to access content script methods, i.e. it expects
 * that there will be a global `adguard` object in the `ISOLATED` world that
 * implements this interface.
 */
export interface AdGuard {
    contentScript: IContentScript;
}

/**
 * Default export for backward compatibility.
 * This represents the global adguard object structure.
 */
const adguard: AdGuard = {} as AdGuard;

export default adguard;
