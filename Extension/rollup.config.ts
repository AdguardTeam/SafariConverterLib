/**
 * @file Rollup configurations for generating SafariExtension builds.
 *
 * ! Please ALWAYS use the "pnpm build" command for building
 * ! Running Rollup directly will not enough, the build script
 * ! does some additional work before and after running Rollup.
 */

import path from 'path';
import { readFileSync } from 'fs';
import typescript from '@rollup/plugin-typescript';
import resolve from '@rollup/plugin-node-resolve';
import commonjs from '@rollup/plugin-commonjs';
import dtsPlugin from 'rollup-plugin-dts';
import json from '@rollup/plugin-json';
import { getBabelOutputPlugin } from '@rollup/plugin-babel';

// Common constants
const ROOT_DIR = './';
const BASE_NAME = 'SafariExtension';
const BASE_FILE_NAME = 'safari-extension';
const PKG_FILE_NAME = 'package.json';

const distDirLocation = path.join(ROOT_DIR, 'dist');
const pkgFileLocation = path.join(ROOT_DIR, PKG_FILE_NAME);

// Read package.json
const pkg = JSON.parse(readFileSync(pkgFileLocation, 'utf-8'));

// Check if the package.json file has all required fields (we need them for
// the banner)
const REQUIRED_PKG_FIELDS = [
    'author',
    'homepage',
    'license',
    'version',
];

for (const field of REQUIRED_PKG_FIELDS) {
    if (!(field in pkg)) {
        throw new Error(`Missing required field "${field}" in ${PKG_FILE_NAME}`);
    }
}

// Generate a banner with the current package & build info.
const BANNER = `/*
 * ${BASE_NAME} v${pkg.version} (build date: ${new Date().toUTCString()})
 * (c) ${new Date().getFullYear()} ${pkg.author}
 * Released under the ${pkg.license} license
 * ${pkg.homepage}
 */
`;

// Pre-configured TypeScript plugin.
const typeScriptPlugin = typescript({
    compilerOptions: {
        // Don't emit declarations, we will do it in a separate command
        // "pnpm build-types"
        declaration: false,
    },
});

// Common plugins for all types of builds.
const commonPlugins = [
    json({ preferConst: true }),
    commonjs({ sourceMap: false }),
    resolve({ preferBuiltins: false }),
    typeScriptPlugin,
];

// Plugins for Node.js builds.
const nodePlugins = [
    ...commonPlugins,
    getBabelOutputPlugin({
        presets: [
            [
                '@babel/preset-env',
                {
                    targets: {
                        node: '18.0',
                    },
                },
            ],
        ],
        allowAllFormats: true,
        compact: false,
    }),
];

// ECMAScript build configuration
const esm = {
    input: path.join(ROOT_DIR, 'src', 'index.ts'),
    output: [
        {
            file: path.join(distDirLocation, `${BASE_FILE_NAME}.esm.js`),
            format: 'esm',
            sourcemap: true,
            banner: BANNER,
        },
    ],
    plugins: nodePlugins,
    external: [
        '@adguard/extended-css',
        '@adguard/scriptlets',
        'webextension-polyfill',
    ],
};

// Merge .d.ts files (requires `tsc` to be run first, because it merges .d.ts
// files from `dist/types` directory).
const dts = {
    input: path.join(ROOT_DIR, 'dist', 'types', 'src', 'index.d.ts'),
    output: [
        {
            file: path.join(distDirLocation, `${BASE_FILE_NAME}.d.ts`),
            format: 'es',
            banner: BANNER,
        },
    ],
    plugins: [
        dtsPlugin(),
    ],
};

// Export build configs for Rollup
export default [esm, dts];
