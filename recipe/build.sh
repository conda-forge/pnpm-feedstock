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

# install pnpm globally from the npm registry
npm install -g ${PKG_NAME}@${PKG_VERSION}

# pnpm uses pnpm as its package manager, which is kind of awkward to deal with sometimes

# as pnpm is quite a complex project there are some oddities to deal with prior to installing dependencies
# and generating the third party licenses from there. Patching done using patchWorkspace.js and explained there.

rm pnpm-lock.yaml
rm -rf pnpm/artifacts/exe
node $RECIPE_DIR/patchWorkspace.js

npx pnpm@${PKG_VERSION} install --ignore-scripts

# generate the thirdPartyLicenses file using @quantco/pnpm-licenses
npx pnpm@${PKG_VERSION} licenses list --prod --json | npx @quantco/pnpm-licenses generate-disclaimer --json-input --filter='["@pnpm/*"]' --output-file=ThirdPartyLicenses.txt

# Regression guard for #237: pnpm's preinstall script picks its native binary
# via process.arch/process.platform, so a build/target platform mismatch
# would silently ship the wrong architecture. All targets build natively now,
# so this should never trip -- it's here to fail loudly if that ever changes.
case "${target_platform}" in
    linux-64) pnpm_exe_arch_pattern="x86-64" ;;
    linux-aarch64) pnpm_exe_arch_pattern="aarch64" ;;
    linux-riscv64) pnpm_exe_arch_pattern="riscv64" ;;
    osx-64) pnpm_exe_arch_pattern="x86_64" ;;
    osx-arm64) pnpm_exe_arch_pattern="arm64" ;;
    *)
        echo "Don't know the expected pnpm binary architecture for target_platform=${target_platform}" >&2
        exit 1
        ;;
esac

pnpm_binary="$PREFIX/lib/node_modules/pnpm/pnpm"
file "${pnpm_binary}" | grep -q "${pnpm_exe_arch_pattern}" || {
    echo "pnpm binary architecture does not match target_platform=${target_platform}:" >&2
    file "${pnpm_binary}" >&2
    exit 1
}
