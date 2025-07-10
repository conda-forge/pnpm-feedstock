#!/bin/sh

set -exuo pipefail

if [[ "${target_platform}" == "osx-arm64" ]]; then
    export npm_config_arch="arm64"
fi
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
# all things coming after this are just concerned with generating the thirdPartyLicenses.txt file
npm install -g ${PKG_NAME}@${PKG_VERSION}

# pnpm uses pnpm as its package manager, which is kind of awkward to deal with sometimes

# as pnpm is quite a complex project there is one oddity we need to take care before we can do a
# `pnpm install` and generate our thirdPartyLicenses.txt file

# we need to remove two patches that get applied on top of two dependencies, as this breaks the `pnpm licenses list` command
# we also need to remove the whole `pnpm/artifacts/exe` folder as it contains one of these patched dependencies which leads
# to `pnpm install` failing (it tries to build vercel/pkg from source which requires yarn, yarn-install then fails as it detects
# that it is being run in a pnpm managed project)
# this isn't a problem license-wise as `pnpm/exe` (pnpm/artifacts/exe) is not part of the pnpm package but its own separate *thing*

rm pnpm-lock.yaml
rm -rf pnpm/artifacts/exe
sed -i '/^nodeVersion/d' pnpm-workspace.yaml

# get rid of the patchedDependencies entry in the root package.json
node $RECIPE_DIR/deletePatchedDependencies.js

npx pnpm@${PKG_VERSION} install

# generate the thirdPartyLicenses file using @quantco/pnpm-licenses
npx pnpm@${PKG_VERSION} licenses list --json | npx @quantco/pnpm-licenses generate-disclaimer --json-input --filter='["@pnpm/*"]' --output-file=ThirdPartyLicenses.txt
