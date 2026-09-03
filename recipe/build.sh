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

# Regression fix for #237: select and place the target-platform native
# binary ourselves instead of letting pnpm's preinstall script auto-detect it
# (it picks the build platform's binary when cross-compiling).
case "${target_platform}" in
    linux-64)
        pnpm_exe_pkg="@pnpm/exe.linux-x64"
        pnpm_exe_arch_pattern="x86-64"
        ;;
    linux-aarch64)
        pnpm_exe_pkg="@pnpm/exe.linux-arm64"
        pnpm_exe_arch_pattern="aarch64"
        ;;
    osx-64)
        pnpm_exe_pkg="@pnpm/exe.darwin-x64"
        pnpm_exe_arch_pattern="x86_64"
        ;;
    osx-arm64)
        pnpm_exe_pkg="@pnpm/exe.darwin-arm64"
        pnpm_exe_arch_pattern="arm64"
        ;;
    *)
        echo "Don't know which pnpm native-binary package ships ${target_platform}" >&2
        exit 1
        ;;
esac

# install pnpm globally from the npm registry
npm install -g --ignore-scripts ${PKG_NAME}@${PKG_VERSION}

pnpm_module_dir="$PREFIX/lib/node_modules/pnpm"

# fetch just the native-binary package for target_platform and place its
# binary where pnpm expects to find it, then drop the build-platform
# native-binary packages npm downloaded as optional dependencies -- they are
# never used and only take up space.
# `npm pack` (unlike `npm install -g`) runs in local project context, so it
# is done from a scratch directory: run from $SRC_DIR it would hit
# EBADDEVENGINES against this checkout's still-unpatched
# devEngines.packageManager (see patchWorkspace.js below).
pnpm_exe_scratch=$(mktemp -d)
pnpm_exe_tarball="${pnpm_exe_scratch}/$(cd "${pnpm_exe_scratch}" && npm pack --silent --ignore-scripts "${pnpm_exe_pkg}@${PKG_VERSION}")"
tar -xzf "${pnpm_exe_tarball}" -O package/pnpm > "${pnpm_module_dir}/pnpm"
chmod 0755 "${pnpm_module_dir}/pnpm"
rm -rf "${pnpm_exe_scratch}"
rm -rf "${pnpm_module_dir}/node_modules/@pnpm"

file "${pnpm_module_dir}/pnpm" | grep -q "${pnpm_exe_arch_pattern}" || {
    echo "pnpm binary architecture does not match target_platform=${target_platform}:" >&2
    file "${pnpm_module_dir}/pnpm" >&2
    exit 1
}

# pnpm uses pnpm as its package manager, which is kind of awkward to deal with sometimes

# as pnpm is quite a complex project there are some oddities to deal with prior to installing dependencies
# and generating the third party licenses from there. Patching done using patchWorkspace.js and explained there.

rm pnpm-lock.yaml
rm -rf pnpm/artifacts/exe
node $RECIPE_DIR/patchWorkspace.js

npx pnpm@${PKG_VERSION} install --ignore-scripts

# generate the thirdPartyLicenses file using @quantco/pnpm-licenses
npx pnpm@${PKG_VERSION} licenses list --prod --json | npx @quantco/pnpm-licenses generate-disclaimer --json-input --filter='["@pnpm/*"]' --output-file=ThirdPartyLicenses.txt
