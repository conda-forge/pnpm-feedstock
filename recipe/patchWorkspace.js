// Patch package.json and pnpm-workspace.yaml to make `pnpm licenses list` work.
// This is needed as pnpm is a rather complex package with lots of custom parts,
// which don't all play nicely with some pnpm features itself or which cause
// unnecessary complications and differences per platform.

const fs = require('fs')
const packageJson = JSON.parse(fs.readFileSync('./package.json'))
const pnpmWorkspace = fs.readFileSync('./pnpm-workspace.yaml', 'utf-8')
console.log('patching package.json and pnpm-workspace.yaml')

// This is typically one version behind the version we are trying to install
// as it is a sort of "bootstrapping" process to use a package manager to
// build a package manager. We want to ignore this as we just need to install
// the prod dependencies to then create a third-party-licenses file
delete packageJson.packageManager
console.log('deleted `packageManager` from package.json')

// pnpm also declares its package manager via `devEngines.packageManager`, which
// npm/npx enforces. Since we bootstrap the install with npm, this would fail with
// EBADDEVENGINES ("Invalid name 'pnpm' does not match 'npm'"). Remove it as well.
delete packageJson.devEngines
console.log('deleted `devEngines` from package.json')

// We don't want to run any custom commands upon installation
delete packageJson.scripts.prepare
console.log('deleted `scripts.prepare` from package.json')

// 1. We need to delete `patchedDependencies`.
//    pnpm switched from having their own patched dependencies in the package.json
//    file to having them in the pnpm-workspace.yaml file, which means that we
//    cannot simply JSON.parse it and we don't want to deal with having a dependency
//    for parsing yaml around. The easiest solution to "delete" the patchedDependencies
//    entry is to simply rename it. The same applies for other multiline entries as well.

// 2. Additionally we also need to disable the global virtual store as using this has
//    buggy behavior combined with `pnpm licenses list`. The command still outputs the
//    same paths, which do not exist when using `enableGlobalVirtualStore: true`.

// 3. Also remove `nodeVersion`.
//    This check is not needed here as conda-forge will ensure correct dependency versions

// 4. And `allowBuilds` to stop pnpm from running postinstall hooks, even for allowed packages
//    Some of the listed packages have very platform dependent behaviour and can easily cause
//    something to fail in the install process. As we don't intend to build pnpm here we can
//    just skip these and not deal with cross-platform issues that are likely hard to debug.

// Debugging this is a bit easier if the script is idempotent, therefore using regexes which
// have to start at the beginning of the line to avoid RENAMED_RENAMED_RENAMED_.. entries
updatedPnpmWorkspace = pnpmWorkspace
  .replace(/^patchedDependencies:/, 'RENAMED_patchedDependencies:')
  .replace(/^enableGlobalVirtualStore: true/, 'enableGlobalVirtualStore: false')
  .replace(/^nodeVersion:/, 'RENAMED_nodeVersion:')
  .replace(/^allowBuilds:/, 'RENAMED_allowBuilds:')

console.log('deleted `patchedDependencies` from pnpm-workspace.yaml')
console.log('deleted `enableGlobalVirtualStore` from pnpm-workspace.yaml')
console.log('deleted `nodeVersion` from pnpm-workspace.yaml')
console.log('deleted `allowBuilds` from pnpm-workspace.yaml')


fs.writeFileSync('./package.json', JSON.stringify(packageJson, null, 2) + '\n')
fs.writeFileSync('pnpm-workspace.yaml', updatedPnpmWorkspace)
console.log('wrote patched package.json and pnpm-workspace.yaml to disk')
