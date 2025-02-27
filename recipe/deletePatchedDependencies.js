const fs = require('fs')
const packageJson = JSON.parse(fs.readFileSync('./package.json'))
let pnpmWorkspace = fs.readFileSync('./pnpm-workspace.yaml', 'utf-8')

// This is typically one version behind the version we are trying to install
// as it is a sort of "bootstrapping" process to use a package manager to
// build a package manager. We want to ignore this as we just need to install
// the prod dependencies to then create a third-party-licenses file
delete packageJson.packageManager

// We don't want to run any custom commands upon installation
delete packageJson.scripts.prepare

// pnpm switched from having their own patched dependencies in the package.json
// file to having them in the pnpm-workspace.yaml file, which means that we
// cannot simply JSON.parse it and we don't want to deal with having a dependency
// for parsing yaml around. The easiest solution to "delete" the patchedDependencies
// entry is to simply rename it
pnpmWorkspace = pnpmWorkspace.replace('patchedDependencies:', 'RENAMED_patchedDependencies:')

fs.writeFileSync('./package.json', JSON.stringify(packageJson, null, 2) + '\n')
fs.writeFileSync('pnpm-workspace.yaml', pnpmWorkspace)
