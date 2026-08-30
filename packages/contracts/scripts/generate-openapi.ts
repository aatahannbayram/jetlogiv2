import { writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { stringify } from 'yaml';

import { buildOpenApiDocument } from '../src/openapi.js';

const packageRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const document = buildOpenApiDocument();

writeFileSync(resolve(packageRoot, 'openapi.json'), `${JSON.stringify(document, null, 2)}\n`, 'utf8');
writeFileSync(resolve(packageRoot, 'openapi.yaml'), stringify(document, { lineWidth: 100 }), 'utf8');

const pathCount = Object.keys(document.paths ?? {}).length;
const schemaCount = Object.keys(document.components?.schemas ?? {}).length;
console.log(`OpenAPI 3.1 uretildi: ${pathCount} yol, ${schemaCount} sema.`);
