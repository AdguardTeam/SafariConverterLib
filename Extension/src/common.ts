/**
 * @file Contains common constants and helper functions.
 */

/**
 * Name of the engine used to run scriptlets.
 */
export const SCRIPTLET_ENGINE_NAME = 'safari-extension';

/**
 * Makes sure that we're dealing with CSS rules (selector + style)
 *
 * @param css Array of CSS selectors (for hiding elements) or full CSS rules.
 * @returns Array of CSS rules.
 */
export const toCSSRules = (css: string[]): string[] => {
    return css
        .map((s) => s.trim())
        .filter((s) => s.length > 0)
        .map((s) => {
            return s.at(-1) !== '}'
                ? `${s} {display:none!important;}`
                : s;
        });
};
