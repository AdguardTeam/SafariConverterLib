const { jsonFromRules, getConverterVersion, safariVersions } = require('./src/api');

module.exports = (function () {
    return {
        jsonFromRules,
        getConverterVersion,
        safariVersions,
    };
})();
