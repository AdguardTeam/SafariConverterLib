/**
 * @file Contains the implementation of the content script.
 */

import { ExtendedCss } from '@adguard/extended-css';
import { type Source as ScriptletSource, scriptlets as ScriptletsAPI } from '@adguard/scriptlets';

import { type Configuration, type Scriptlet } from './configuration';

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
            // TODO: log error
        }
    }
};

/**
 * Applies JS injections.
 *
 * @param {string[]} scripts Array with JS scripts.
 */
const applyScripts = (scripts: string[]) => {
    if (!scripts || scripts.length === 0) {
        return;
    }

    executeScripts(scripts.reverse());
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
 * Makes sure that we're dealing with CSS rules (selector + style)
 *
 * @param {string[]} css Array of CSS selectors (for hiding elemets) or full CSS rules.
 * @returns {string[]} Array of CSS rules.
 */
const toCSSRules = (css: string[]): string[] => {
    return css
        .filter((s) => s.length > 0)
        .map((s) => s.trim())
        .map((s) => {
            return s[s.length - 1] !== '}'
                ? `${s} {display:none!important;}`
                : s;
        });
};

/**
 * Applies css stylesheet.
 *
 * @param {string[]} css Array of CSS rules to apply.
 */
const applyCss = (css: string[]) => {
    if (!css || !css.length) {
        return;
    }

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
};

/**
 * Applies Extended Css stylesheet.
 *
 * @param {string[]} extendedCss Array with ExtendedCss rules.
 */
const applyExtendedCss = (extendedCss: string[]) => {
    if (!extendedCss || !extendedCss.length) {
        return;
    }

    const cssRules = toCSSRules(extendedCss);
    const extCss = new ExtendedCss({ cssRules });
    extCss.apply();
};

/**
 * Converts scriptlet to the code that can be executed.
 *
 * @param {Scriptlet} scriptlet Scriptlet data (name and arguments)
 * @returns {string} Scriptlet code
 */
const getScriptletCode = (scriptlet: Scriptlet): string => {
    try {
        const scriptletSource: ScriptletSource = {
            engine: 'safari-extension',
            name: scriptlet.name,
            args: scriptlet.args,

            // TODO: Set proper version.
            version: '1.0.0',

            // TODO: remove
            verbose: false,
        };

        return ScriptletsAPI.invoke(scriptletSource);
    } catch (e) {
        // TODO: log error
    }

    return '';
};

/**
 * Applies scriptlets.
 *
 * @param {Scriptlet[]} scriptlets Array with scriptlets data..
 */
const applyScriptlets = (scriptlets: Scriptlet[]) => {
    if (!scriptlets || !scriptlets.length) {
        return;
    }

    const scripts = scriptlets.map(getScriptletCode);

    executeScripts(scripts);
};

/**
 * Content script that applies all the rules from the configuration.
 */
class ContentScript {
    private readonly configuration: Configuration;

    constructor(configuration: Configuration) {
        this.configuration = configuration;
    }

    public run() {
        applyCss(this.configuration.css);
        applyExtendedCss(this.configuration.extendedCSS);
        applyScriptlets(this.configuration.scriptlets);
        applyScripts(this.configuration.js);
    }
}

export { ContentScript };
