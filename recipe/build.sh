#!/bin/sh

set -exuo pipefail

# Don't use pre-built gyp packages
export npm_config_build_from_source=true

rm $PREFIX/bin/node
ln -s $BUILD_PREFIX/bin/node $PREFIX/bin/node

# disable any and all CI related checks which pnpm does by default
# we don't want to enforce a strict lock file check here right now
# pnpm uses https://github.com/watson/is-ci for this check, which uses `false` as a value to disable
# all CI detection (as opposed to `0` or unsetting the env var)
export CI=false

NPM_CONFIG_USERCONFIG=/tmp/nonexistentrc

# pnpm uses pnpm as its package manager, which is kind of awkward to deal with sometimes

# as pnpm is quite a complex project there are some oddities to deal with prior to installing dependencies
# and generating the third party licenses from there. Patching done using patchWorkspace.js and explained there.

rm pnpm-lock.yaml
rm -rf pnpm/artifacts/exe
node $RECIPE_DIR/patchWorkspace.js

# This runs on the build machine, so it has to happen before we install the
# target platform's pnpm into $PREFIX/bin -- otherwise npx would pick that one
# up from PATH and, when cross-compiling, fail to execute it.
npx pnpm@${PKG_VERSION} install --ignore-scripts

# generate the thirdPartyLicenses file using @quantco/pnpm-licenses
npx pnpm@${PKG_VERSION} licenses list --prod --json | npx @quantco/pnpm-licenses generate-disclaimer --json-input --filter='["@pnpm/*"]' --output-file=ThirdPartyLicenses.txt

# pnpm ships one native binary per platform as an optional dependency
# (`@pnpm/exe.<os>-<cpu>`), and its install script links the one matching the
# *host* (process.platform/process.arch) over the placeholder `pnpm` bin. That
# picks the wrong architecture whenever we cross-compile (linux-riscv64 is built
# on linux-64), so instead of relying on the install script we tell npm which
# platform to resolve the optional dependency for and place the binary ourselves.
# See #237 for the bug this guards against.
case "${target_platform}" in
    linux-64)      npm_os=linux  npm_cpu=x64     npm_libc=glibc pnpm_exe_arch_pattern="x86-64" ;;
    linux-aarch64) npm_os=linux  npm_cpu=arm64   npm_libc=glibc pnpm_exe_arch_pattern="aarch64" ;;
    linux-riscv64) npm_os=linux  npm_cpu=riscv64 npm_libc=glibc pnpm_exe_arch_pattern="RISC-V" ;;
    osx-64)        npm_os=darwin npm_cpu=x64     npm_libc=""    pnpm_exe_arch_pattern="x86_64" ;;
    osx-arm64)     npm_os=darwin npm_cpu=arm64   npm_libc=""    pnpm_exe_arch_pattern="arm64" ;;
    *)
        echo "Don't know which pnpm native binary to install for target_platform=${target_platform}" >&2
        exit 1
        ;;
esac

# install pnpm globally from the npm registry
npm install -g --ignore-scripts --os="${npm_os}" --cpu="${npm_cpu}" ${npm_libc:+--libc="${npm_libc}"} ${PKG_NAME}@${PKG_VERSION}

# `--ignore-scripts` above left the placeholder `pnpm` bin in place (a small `sh`
# script that shells out to node); replace it with the target's native binary,
# which is what pnpm's own install script would have done for a native build.
pnpm_dir="$PREFIX/lib/node_modules/pnpm"
pnpm_exe_pkg="@pnpm/exe.${npm_os}-${npm_cpu}"
pnpm_native_binary=""
# npm nests the optional dependency inside the global package, but hoists it to
# the global node_modules when something else already claims that name.
for modules_dir in "${pnpm_dir}/node_modules" "$PREFIX/lib/node_modules"; do
    if [ -f "${modules_dir}/${pnpm_exe_pkg}/pnpm" ]; then
        pnpm_native_binary="${modules_dir}/${pnpm_exe_pkg}/pnpm"
        break
    fi
done
if [ -z "${pnpm_native_binary}" ]; then
    echo "npm did not install ${pnpm_exe_pkg}, so there is no native pnpm binary for ${target_platform}" >&2
    exit 1
fi

cp "${pnpm_native_binary}" "${pnpm_dir}/pnpm"
chmod 755 "${pnpm_dir}/pnpm"

# Regression guard for #237: fail loudly if the binary we shipped above is not
# actually the one for target_platform.
pnpm_binary="${pnpm_dir}/pnpm"
file "${pnpm_binary}" | grep -q "${pnpm_exe_arch_pattern}" || {
    echo "pnpm binary architecture does not match target_platform=${target_platform}:" >&2
    file "${pnpm_binary}" >&2
    exit 1
}
