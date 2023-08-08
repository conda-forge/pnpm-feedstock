const fs = require('fs')
const packageJson = JSON.parse(fs.readFileSync('./package.json'));
delete packageJson.pnpm.patchedDependencies
delete packageJson.scripts.prepare
fs.writeFileSync('./package.json', JSON.stringify(packageJson, null, 2) + '\n')

