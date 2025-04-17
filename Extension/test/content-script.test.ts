/* eslint-disable @typescript-eslint/dot-notation */

/**
 * @file Contains tests for the ContentScript class.
 *
 * @vitest-environment jsdom
 */

import {
    vi,
    expect,
    test,
    afterEach,
} from 'vitest';

import { ContentScript } from '../src/content-script';

afterEach(() => {
    // Clear DOM
    document.head.innerHTML = '';
    document.body.innerHTML = '';
});

test('ContentScript is defined', () => {
    expect(ContentScript).toBeDefined();
});

test('ContentScript adds CSS to the page', () => {
    // Arrange: create a configuration with some CSS
    const config = {
        css: ['.test-element { background-color: blue; }'],
        extendedCss: [],
        scriptlets: [],
        js: [],
        engineTimestamp: 0,
    };

    // Act: run the content script with the given configuration
    new ContentScript(config).run();

    // Assert: verify that the style is added to the document
    const styleElements = document.head.querySelectorAll('style');
    expect(styleElements.length).toBeGreaterThan(0);
    expect(styleElements[0].sheet?.cssRules).toHaveLength(1);

    const cssRule = styleElements[0].sheet?.cssRules[0];
    expect(cssRule).toBeDefined();
    expect(cssRule ? cssRule['selectorText'] : null).toBe('.test-element');

    // Check the style
    const style = cssRule ? cssRule['style'] : null;
    expect(style).toBeDefined();
    expect(style ? style['background-color'] : null).toBe('blue');
});

test('ContentScript adds CSS display:none when given only selector', () => {
    // Arrange: create a configuration with some CSS selector
    const config = {
        css: ['.test-element'],
        extendedCss: [],
        scriptlets: [],
        js: [],
        engineTimestamp: 0,
    };

    // Act: run the content script with the given configuration
    new ContentScript(config).run();

    // Assert: verify that the style is added to the document
    const styleElements = document.head.querySelectorAll('style');
    expect(styleElements.length).toBeGreaterThan(0);
    expect(styleElements[0].sheet?.cssRules).toHaveLength(1);

    const cssRule = styleElements[0].sheet?.cssRules[0];
    expect(cssRule).toBeDefined();
    expect(cssRule ? cssRule['selectorText'] : null).toBe('.test-element');

    // Check the style
    const style = cssRule ? cssRule['style'] : null;
    expect(style).toBeDefined();
    expect(style ? style['display'] : null).toBe('none');
});

test('ContentScript applies extended CSS', () => {
    // Arrange: create a configuration with some extended CSS.
    const config = {
        css: [],
        extendedCss: ['.test-element:contains(Hello) { background-color: blue; }'],
        scriptlets: [],
        js: [],
        engineTimestamp: 0,
    };

    // Create element with text "Hello"
    const element = document.createElement('div');
    element.setAttribute('class', 'test-element');
    element.textContent = 'Hello';
    document.body.appendChild(element);

    // Act: run the content script with the given configuration
    new ContentScript(config).run();

    // Assert: verify that the style is added inline to the element
    expect(element.style.backgroundColor).toBe('blue');
});

test('ContentScript adds JS to the page', () => {
    // Spy on console.log
    const logSpy = vi.spyOn(console, 'log');

    // Provide a configuration that will trigger the console.log
    const config = {
        css: [],
        extendedCss: [],
        scriptlets: [],
        js: ['console.log("Hello, world!");'],
        engineTimestamp: 0,
    };

    // Run the content script
    new ContentScript(config).run();

    // Now you can safely use the spy
    expect(logSpy).toHaveBeenCalledWith('Hello, world!');
});

test('ContentScript applies scriptlets', () => {
    // Spy on console.log
    const logSpy = vi.spyOn(console, 'log');

    // Arrange: create a configuration with some scriptlets
    const config = {
        css: [],
        extendedCss: [],
        scriptlets: [{ name: 'log', args: ['I am a scriptlet'] }],
        js: [],
        engineTimestamp: 0,
    };

    // Run the content script
    new ContentScript(config).run();

    // Loosely match the expected argument.
    const expectedArgument = expect.arrayContaining([
        expect.objectContaining({
            name: 'log',
            args: ['I am a scriptlet'],
        }),
    ]);

    // Check that the scriptlet was applied.
    expect(logSpy).toHaveBeenCalledWith(expectedArgument);
});
