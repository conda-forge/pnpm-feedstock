#!/bin/sh

set -exuo pipefail

if [[ "${target_platform}" == "osx-arm64" ]]; then
    export npm_config_arch="arm64"
fi
# Don't use pre-built gyp packages
export npm_config_build_from_source=true

rm $PREFIX/bin/node
ln -s $BUILD_PREFIX/bin/node $PREFIX/bin/node

NPM_CONFIG_USERCONFIG=/tmp/nonexistentrc

# install pnpm globally from the npm registry
# all things coming after this are just concerned with generating the thirdPartyLicenses.txt file
npm install -g ${PKG_NAME}@${PKG_VERSION}

# pnpm uses pnpm as its package manager, which is kind of awkward to deal with sometimes
# we thus need to use npx pnpm@latest in a few places

# there are 2 dependencies which have patches applied by pnpm, this breaks `pnpm licenses list`, thus we remove the patches
npx pnpm@latest install
npx pnpm@latest patch-remove pkg@5.7.0
npx pnpm@latest patch-remove graceful-fs@4.2.11
npx pnpm@latest install

# generate the thirdPartyLicenses file using @quantco/pnpm-licenses
npx pnpm@latest licenses list --json | npx @quantco/pnpm-licenses generate-disclaimer --json-input --filter='["@pnpm/*"]' --output-file=ThirdPartyLicenses.txt
