const { jsonFromRules, getConverterVersion, safariVersions } = require('../index');
const pJson = require('../../package.json');

describe('API test', () => {
    it('jsonFromRules test', async () => {
        const rules = ['example.com##.ads-banner', '||test.com^$image'];
        const result = await jsonFromRules(rules, false);
        const converted = JSON.parse(result.converted);

        expect(converted[0].trigger['if-domain']).toStrictEqual(['*example.com']);
        expect(converted[0].action.type).toBe('css-display-none');
        expect(converted[0].action.selector).toBe('.ads-banner');

        expect(converted[1].trigger['resource-type']).toStrictEqual(['image']);
        expect(converted[1].action.type).toBe('block');

        // convert for Safari 15 and compare with previous conversion for detected Safari version
        const resultSafari15 = await jsonFromRules(rules, false, safariVersions.safari15);
        expect(resultSafari15).toStrictEqual(result);
    });

    it('Unsupported Safari version test', async () => {
        const rules = ['example.com##.ads-banner'];

        await expect(jsonFromRules(rules, false, safariVersions.safari12))
            .rejects.toThrow('AG: ContentBlockerConverter: Unexpected error: unsupportedSafariVersion(message: "The provided Safari version is not supported")');
    });

    it('getConverterVersion test', () => {
        let version = getConverterVersion();
        expect(version).toBe(pJson.version);
    });
});
