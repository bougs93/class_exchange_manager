// Give each release a distinct URL so cached Flutter entrypoints cannot mix.
import { createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';

const directory = path.resolve(process.argv[2] ?? 'build/web');
const bootstrapPath = path.join(directory, 'flutter_bootstrap.js');
const indexPath = path.join(directory, 'index.html');
let bootstrap = await readFile(bootstrapPath, 'utf8');
const index = await readFile(indexPath, 'utf8');
const configMatch = bootstrap.match(/^_flutter\.buildConfig = (.+);$/m);
if (!configMatch || !index.includes('src="flutter_bootstrap.js"')) {
  throw new Error('Unexpected Flutter build output; refusing to deploy unversioned entrypoints.');
}

const config = JSON.parse(configMatch[1]);
const renamed = new Map();
const fingerprint = (name, bytes) => {
  const extension = path.extname(name);
  const hash = createHash('sha256').update(bytes).digest('hex').slice(0, 16);
  return `${name.slice(0, -extension.length)}.${hash}${extension}`;
};

for (const build of config.builds) {
  for (const key of ['mainJsPath', 'mainWasmPath', 'jsSupportRuntimePath']) {
    const name = build[key];
    if (!name) continue;
    if (!renamed.has(name)) {
      const bytes = await readFile(path.join(directory, name));
      renamed.set(name, fingerprint(name, bytes));
    }
    build[key] = renamed.get(name);
  }
}
if (renamed.size === 0) throw new Error('No Flutter entrypoints found.');

bootstrap = bootstrap.replace(
  configMatch[0],
  `_flutter.buildConfig = ${JSON.stringify(config)};`,
);
const bootstrapName = fingerprint('flutter_bootstrap.js', bootstrap);
for (const [original, versioned] of renamed) {
  await writeFile(
    path.join(directory, versioned),
    await readFile(path.join(directory, original)),
  );
}
await writeFile(path.join(directory, bootstrapName), bootstrap);
await writeFile(bootstrapPath, bootstrap);
await writeFile(
  indexPath,
  index.replace('src="flutter_bootstrap.js"', `src="${bootstrapName}"`),
);
console.log(`Versioned ${renamed.size} Flutter entrypoints and ${bootstrapName}`);
