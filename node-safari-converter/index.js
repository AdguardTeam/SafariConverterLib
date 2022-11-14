const { jsonFromRules, getConverterVersion } = require('./src/api');

module.exports = (function () {
    return {
        jsonFromRules,
        getConverterVersion,
    };
})();
