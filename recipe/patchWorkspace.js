// Patch package.json and pnpm-workspace.yaml to make `pnpm licenses list` work.
// This is needed as pnpm is a rather complex package with lots of custom parts,
// which don't all play nicely with some pnpm features itself or which cause unnecessary
// complications and differences per platform.

const fs = require('fs')
const packageJson = JSON.parse(fs.readFileSync('./package.json'))
const pnpmWorkspace = fs.readFileSync('./pnpm-workspace.yaml', 'utf-8')
console.log('patching package.json and pnpm-workspace.yaml')

// This is typically one version behind the version we are trying to install as it is a sort
// of "bootstrapping" process to use a package manager to build a package manager. We want
// to ignore this as we just need to install the prod dependencies to then create a
// third-party-licenses file
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
//    pnpm switched from having their own patched dependencies in the package.json file to
//    having them in the pnpm-workspace.yaml file, which means that we cannot simply JSON.parse
//    it and we don't want to deal with having a dependency for parsing yaml around.
//    The easiest solution to "delete" the patchedDependencies entry is to simply rename it.
//    The same applies for other multiline entries as well.

// 2. Additionally we also need to disable the global virtual store as using this has buggy
//    behavior combined with `pnpm licenses list`. The command still outputs the same paths,
//    which do not exist when using `enableGlobalVirtualStore: true`.

// 3. Also remove `nodeVersion`.
//    This check is not needed here as conda-forge will ensure correct dependency versions

// 4. And `allowBuilds` to stop pnpm from running postinstall hooks, even for allowed packages
//    Some of the listed packages have very platform dependent behaviour and can easily cause
//    something to fail in the install process. As we don't intend to build pnpm here we can
//    just skip these and not deal with cross-platform issues that are likely hard to debug.

// 5. Disable `configDependencies` as well, because with this option pnpm tries to use their
//    new rust based port of parts of pnpm, which fails.

// 6. Disable `cargo` too. Since v12.5 pnpm manages its own Rust crates (Cargo deps)
//    which requires a Rust toolchain (`cargo metadata`) and git checkouts of
//    Cargo git dependencies. Neither is needed to collect the npm licenses.

// 7. Since v12.17 pnpm moves some of these settings (e.g. `patchedDependencies`, `allowBuilds`)
//    out of pnpm-workspace.yaml into separate files referenced by its top-level `include:` map.
//    pnpm rejects keys in an included file that are not delegated to it, so renaming them there
//    does not work. Instead the whole top-level block is removed from included files.

const disabledSettings = ['patchedDependencies', 'nodeVersion', 'allowBuilds', 'configDependencies', 'cargo']

// Debugging this is a bit easier if the script is idempotent, therefore using regexes which
// have to start at the beginning of the line to avoid RENAMED_RENAMED_RENAMED_.. entries
let updatedPnpmWorkspace = pnpmWorkspace
  .replace(/^enableGlobalVirtualStore: true/gm, 'enableGlobalVirtualStore: false')
for (const setting of disabledSettings) {
  updatedPnpmWorkspace = updatedPnpmWorkspace.replace(new RegExp(`^${setting}:`, 'gm'), `RENAMED_${setting}:`)
}

console.log('deleted `patchedDependencies` from pnpm-workspace.yaml')
console.log('deleted `enableGlobalVirtualStore` from pnpm-workspace.yaml')
console.log('deleted `nodeVersion` from pnpm-workspace.yaml')
console.log('deleted `allowBuilds` from pnpm-workspace.yaml')
console.log('deleted `configDependencies` from pnpm-workspace.yaml')
console.log('deleted `cargo` from pnpm-workspace.yaml')

// Collect the file paths listed as keys of the top-level `include:` block, e.g.
// include:
//   ./.config/pnpm/patches/patches.yaml:
//     - patchedDependencies
const includeBlock = pnpmWorkspace.match(/^include:[^\S\n]*\n((?:[ \t]+.*\n|[^\S\n]*\n)*)/m)
const includedFiles = includeBlock
  ? [...includeBlock[1].matchAll(/^ {2}['"]?([^'"\s#][^'"\n]*?)['"]?:[^\S\n]*$/gm)].map((m) => m[1])
  : []

for (const includedFile of includedFiles) {
  if (!fs.existsSync(includedFile)) {
    console.log(`included file ${includedFile} does not exist, skipping`)
    continue
  }
  const content = fs.readFileSync(includedFile, 'utf-8')
  let updatedContent = content
    .replace(/^enableGlobalVirtualStore: true/gm, 'enableGlobalVirtualStore: false')
  for (const setting of disabledSettings) {
    // A top-level block is the `key:` line plus all following indented or blank lines
    updatedContent = updatedContent.replace(new RegExp(`^${setting}:.*(?:\\n(?:[ \\t].*|[ \\t]*$))*\\n?`, 'gm'), '')
  }
  if (updatedContent !== content) {
    fs.writeFileSync(includedFile, updatedContent, 'utf-8')
    console.log(`patched included file ${includedFile}`)
  }
}

fs.writeFileSync('./package.json', JSON.stringify(packageJson, null, 2) + '\n', 'utf-8')
fs.writeFileSync('./pnpm-workspace.yaml', updatedPnpmWorkspace, 'utf-8')
console.log('wrote patched package.json and pnpm-workspace.yaml to disk')
