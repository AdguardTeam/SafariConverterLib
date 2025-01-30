/**
 * @file Contains tests for the ContentScript class.
 *
 * @vitest-environment jsdom
 */

import { expect, test } from 'vitest';
import { ContentScript } from '../src/content-script';

test('defined', () => {
    expect(ContentScript).toBeDefined();
    expect(1).toBe(1);
});
