const path = require('path');
const { spawn } = require('child_process');
const { version } = require('./package.json');

module.exports = (function () {
    const RULES_LIMIT = 50000;

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
     * @param log
     */
    const jsonFromRules = async (rules, advancedBlocking, log) => {
        log.info(`ConverterTool version: ${version}`);
        log.info(`Conversion of ${rules.length} rules started..`);

        // TODO resolve path properly
        const toolPath = path.resolve('node_modules/safari-converter-lib/bin/ConverterTool');
        log.info(`Running converter from: ${toolPath}`);

        return new Promise((resolve) => {
            const child = runScript(toolPath, [
                `-limit=${RULES_LIMIT}`,
                '-optimize=false',
                `-advancedBlocking=${advancedBlocking}`,
            ], (code, stdout, stderr) => {
                if (code !== 0) {
                    log.warn(`Unexpected error converting rules: ${stderr}`);
                    resolve();
                    return;
                }

                log.info(`Conversion of ${rules.length} rules completed.`);
                const result = JSON.parse(stdout);
                log.info(result?.message);

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

    return {
        jsonFromRules,
    };
})();
