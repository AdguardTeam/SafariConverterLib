const path = require('path');
const { spawn } = require('child_process');
const { version } = require('../../package.json');

const CONVERTER_TOOL_PATH = path.resolve(__dirname, '../../bin/ConverterTool');

const DEFAULT_SAFARI_VERSION = 13;

module.exports = (function () {
    /**
     * Validates and checks safari version
     * @param version
     */
    const handleSafariVersion = (version) => {
        if (Number.isInteger(version) && version >= DEFAULT_SAFARI_VERSION) {
            return version;
        } else {
            return DEFAULT_SAFARI_VERSION;
        }
    }

    /**
     * Runs shell script
     *
     * @param command
     * @param args
     * @param callback
     */
    const runScript = (command, args, callback) => {
        const child = spawn(command, args);

        let stdout = '';
        let stderr = '';

        child.stdout.setEncoding('utf8');
        child.stdout.on('data', (data) => {
            data = data.toString();
            stdout += data;
        });

        child.stderr.setEncoding('utf8');
        child.stderr.on('data', (data) => {
            data = data.toString();
            stderr += data;
        });

        child.on('close', (code) => {
            callback(code, stdout, stderr);
        });

        return child;
    };

    /**
     * Runs converter method for rules
     *
     * @param rules array of rules
     * @param advancedBlocking if we need advanced blocking content
     * @param safariVersion
     * @param converterToolPath - optional path to converter resolved by Electron
     */
    const jsonFromRules = async (rules, advancedBlocking, safariVersion, converterToolPath) => {
        const currentSafariVersion = handleSafariVersion(safariVersion);

        return new Promise((resolve, reject) => {
            const child = runScript(converterToolPath || CONVERTER_TOOL_PATH, [
                `--safari-version=${currentSafariVersion}`,
                '--optimize=false',
                `--advanced-blocking=${advancedBlocking}`,
            ], (code, stdout, stderr) => {
                if (code !== 0) {
                    reject(new Error(stderr));
                    return;
                }
                const result = JSON.parse(stdout);

                resolve(result);
            });

            child.stdin.setEncoding('utf8');
            for (const r of rules) {
                child.stdin.write(r);
                child.stdin.write('\n');
            }

            child.stdin.end();
        });
    };

    /**
     * Returns Safari Converter Lib version
     */
    const getConverterVersion = () => {
        return version;
    }

    return {
        jsonFromRules,
        getConverterVersion,
    };
})();
