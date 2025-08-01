/**
 * @file Contains the implementation of the content script.
 */

import { ExtendedCss } from '@adguard/extended-css';
import { type Source as ScriptletSource, scriptlets as ScriptletsAPI } from '@adguard/scriptlets';

import { type Configuration, type Scriptlet } from './configuration';
import { log } from './log';
import { version as extensionVersion } from '../package.json';
import { SCRIPTLET_ENGINE_NAME, toCSSRules } from './common';
import { type IContentScript } from './content-types';

/**
 * Executes code in the context of the page via new script tag and text content.
 *
 * @param {string} code String of scripts to be executed.
 * @returns {boolean} Returns true if code was executed, otherwise returns false.
 */
const executeScriptsViaTextContent = (code: string): boolean => {
    const scriptTag = document.createElement('script');
    scriptTag.setAttribute('type', 'text/javascript');
    scriptTag.textContent = code;
    const parent = document.head || document.documentElement;
    parent.appendChild(scriptTag);
    if (scriptTag.parentNode) {
        scriptTag.parentNode.removeChild(scriptTag);
        return false;
    }
    return true;
};

/**
 * Executes code in the context of page via new script tag and blob. We use
 * this way as a fallback if we fail to inject via textContent.
 *
 * @param {string} code String of scripts to be executed
 * @returns {boolean} Returns true if code was executed, otherwise returns false.
 */
const executeScriptsViaBlob = (code: string): boolean => {
    const blob = new Blob([code], { type: 'text/javascript' });
    const url = URL.createObjectURL(blob);
    const scriptTag = document.createElement('script');
    scriptTag.src = url;
    const parent = document.head || document.documentElement;
    parent.appendChild(scriptTag);
    URL.revokeObjectURL(url);
    if (scriptTag.parentNode) {
        scriptTag.parentNode.removeChild(scriptTag);
        return false;
    }
    return true;
};

/**
 * Execute scripts in a page context and cleanup itself when execution
 * completes.
 *
 * @param {string[]} scripts Array of scripts to execute.
 */
const executeScripts = (scripts: string[] = []) => {
    scripts.unshift('( function () { try {');
    // we use this script detect if the script was applied,
    // if the script tag was removed, then it means that code was applied, otherwise no
    scripts.push(';document.currentScript.remove();');
    scripts.push("} catch (ex) { console.error('Error executing AG js: ' + ex); } })();");
    const code = scripts.join('\r\n');
    if (!executeScriptsViaTextContent(code)) {
        if (!executeScriptsViaBlob(code)) {
            log.error('Failed to execute scripts');
        }
    }
};

/**
 * Protects specified style element from changes to the current document
 * Add a mutation observer, which is adds our rules again if it was removed
 *
 * @param {HTMLElement} protectStyleEl protected style element.
 */
const protectStyleElementContent = (protectStyleEl: HTMLElement) => {
    const { MutationObserver } = window;
    if (!MutationObserver) {
        return;
    }

    // Observer, which observe protectStyleEl inner changes, without deleting
    // styleEl.
    const innerObserver = new MutationObserver(((mutations) => {
        for (let i = 0; i < mutations.length; i += 1) {
            const m = mutations[i];
            if (protectStyleEl.hasAttribute('mod')
                && protectStyleEl.getAttribute('mod') === 'inner') {
                protectStyleEl.removeAttribute('mod');
                break;
            }

            protectStyleEl.setAttribute('mod', 'inner');
            let isProtectStyleElModified = false;

            // There are two mutually exclusive situations:
            //
            // 1. There were changes to the inner text of protectStyleEl.
            // 2. The whole "text" element of protectStyleEl was removed.
            if (m.removedNodes.length > 0) {
                for (let j = 0; j < m.removedNodes.length; j += 1) {
                    isProtectStyleElModified = true;
                    protectStyleEl.appendChild(m.removedNodes[j]);
                }
            } else if (m.oldValue) {
                isProtectStyleElModified = true;
                // eslint-disable-next-line no-param-reassign
                protectStyleEl.textContent = m.oldValue;
            }

            if (!isProtectStyleElModified) {
                protectStyleEl.removeAttribute('mod');
            }
        }
    }));

    innerObserver.observe(protectStyleEl, {
        childList: true,
        characterData: true,
        subtree: true,
        characterDataOldValue: true,
    });
};

/**
 * Converts scriptlet to the code that can be executed.
 *
 * @param {Scriptlet} scriptlet Scriptlet data (name and arguments)
 * @param {boolean} verbose Whether to log verbose output
 * @returns {string} Scriptlet code
 */
const getScriptletCode = (scriptlet: Scriptlet, verbose: boolean): string => {
    try {
        const scriptletSource: ScriptletSource = {
            engine: SCRIPTLET_ENGINE_NAME,
            name: scriptlet.name,
            args: scriptlet.args,
            version: extensionVersion,
            verbose,
        };

        return ScriptletsAPI.invoke(scriptletSource);
    } catch (e) {
        log.error('Failed to get scriptlet code', scriptlet.name, e);
    }

    return '';
};

// Disable class-methods-use-this rule for the following code since it needs
// to implement particular interface.
/* eslint-disable class-methods-use-this  */

/**
 * Content script object. The way this object is used is different and
 * depends on whether this code is used from Safari App Extension or from
 * Safari Web Extension.
 *
 * In the case of Safari App Extension, this object is used from within
 * the content script, i.e. it is used to apply the configuration to the web
 * page.
 *
 * In the case of Safari Web Extension, `BackgroundScript` relies on the
 * functions of this object to run scripts and insert extended CSS into the
 * web page, i.e. it expects that there will be a global `adguard.contentScript`
 * object in the `ISOLATED` world that implements this interface.
 */
class ContentScript implements IContentScript {
    /**
     * Applies the configuration to the web page. This method is supposed to be
     * run from the extension's content script (ISOLATED world) and it is only
     * supposed to be used by Safari App Extension.
     *
     * @param configuration Configuration to apply.
     * @param verbose Whether to log verbose output.
     */
    public applyConfiguration(configuration: Configuration, verbose: boolean = false) {
        this.insertCss(configuration.css);
        this.insertExtendedCss(configuration.extendedCss);
        this.runScriptlets(configuration.scriptlets, verbose);
        this.runScripts(configuration.js);
    }

    /**
     * Inserts specified CSS rules to the page.
     *
     * @param css Array of CSS rules to apply. Can be a selector
     */
    public insertCss(css: string[]) {
        if (!css || !css.length) {
            return;
        }

        try {
            const styleElement = document.createElement('style');
            styleElement.setAttribute('type', 'text/css');
            (document.head || document.documentElement).appendChild(styleElement);

            if (styleElement.sheet) {
                const cssRules = toCSSRules(css);
                for (const style of cssRules) {
                    styleElement.sheet.insertRule(style);
                }
            }

            protectStyleElementContent(styleElement);
        } catch (e) {
            log.error('Failed to insert CSS', e);
        }
    }

    /**
     * Applies Extended Css stylesheet.
     *
     * @param {string[]} extendedCss Array with ExtendedCss rules.
     */
    public insertExtendedCss(extendedCss: string[]) {
        if (!extendedCss || !extendedCss.length) {
            return;
        }

        try {
            const cssRules = toCSSRules(extendedCss);
            const extCss = new ExtendedCss({ cssRules });

            extCss.apply();
        } catch (e) {
            log.error('Failed to insert extended CSS', e);
        }
    }

    /**
     * Runs scripts in the web page. This method is supposed to be run from the
     * extension's content script (ISOLATED world).
     *
     * In the case of Safari Web Extension this method is exposed via
     * `adguard.contentScript` global object in `ISOLATED` world.
     *
     * @param scripts Array of scripts to run.
     */
    public runScripts(scripts: string[]) {
        if (!scripts || scripts.length === 0) {
            return;
        }

        executeScripts(scripts);
    }

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
    public runScriptlets(scriptlets: Scriptlet[], verbose: boolean) {
        if (!scriptlets || !scriptlets.length) {
            return;
        }

        const getCode = (scriptlet: Scriptlet) => getScriptletCode(scriptlet, verbose);
        const scripts = scriptlets.map(getCode);

        executeScripts(scripts);
    }
}

export { ContentScript };

/* eslint-enable class-methods-use-this */
