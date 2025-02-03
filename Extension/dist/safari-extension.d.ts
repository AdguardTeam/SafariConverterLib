/*
 * SafariExtension v3.0.0 (build date: Thu, 30 Jan 2025 19:29:02 GMT)
 * (c) 2025 Adguard Software Ltd.
 * Released under the GPL-3.0 license
 * https://github.com/AdguardTeam/SafariConverterLib/tree/master/Extension
 */
/**
 * @file Defines the configuration for the content script.
 */
/**
 * Represents configuration for the content script.
 */
interface Configuration {
    /**
     * A set of CSS rules that will be used to apply additional styles to the
     * elements on a page via injecting a <style> tag into the page. The array
     * can contain full CSS rules or just selectors.
     */
    css: string[];
    /**
     * A set of CSS rules that will be used to apply additional styles to the
     * elements on a page via Extended CSS library. The array can contain full
     * CSS rules or just selectors.
     */
    extendedCss: string[];
    /**
     * A list of JS scripts that will be executed on the page.
     */
    js: string[];
    /**
     * A set of scriptlet parameters that will be used to run "scriptlets"
     * on the page.
     */
    scriptlets: Scriptlet[];
}
/**
 * Represents scriptlet data that will be used to run "scriptlets" on the page.
 */
interface Scriptlet {
    /**
     * Scriptlet name.
     */
    name: string;
    /**
     * Scriptlet arguments.
     */
    args: string[];
}

/**
 * @file Contains the implementation of the content script.
 */

/**
 * Content script that applies all the rules from the configuration.
 */
declare class ContentScript {
    private readonly configuration;
    constructor(configuration: Configuration);
    run(): void;
}

export { type Configuration, ContentScript, type Scriptlet };
