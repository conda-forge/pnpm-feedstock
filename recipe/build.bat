@echo on

md %LIBRARY_PREFIX%\share\pnpm
pushd %LIBRARY_PREFIX%\share\pnpm
md node_modules
cmd /c "npm install pnpm@%PKG_VERSION%"
if errorlevel 1 exit 1
popd

pushd %LIBRARY_PREFIX%\bin
for %%c in (pnpm) do (
  echo @echo off >> %%c.bat
  echo "%LIBRARY_PREFIX%\share\pnpm\node_modules\.bin\%%c.cmd" %%* >> %%c.bat
)
popd

rmdir pnpm\artifacts\exe /s /q
if errorlevel 1 exit 1
del pnpm-lock.yaml
if errorlevel 1 exit 1
node %RECIPE_DIR%\deletePatchedDependencies.js
if errorlevel 1 exit 1
sed -i "/^nodeVersion/d" pnpm-workspace.yaml
if errorlevel 1 exit 1

@echo "## Installing prod dependencies"
cmd /c npx pnpm@%PKG_VERSION% install --prod
if errorlevel 1 exit 1

@echo "## Generating ThirdPartyLicenses.txt"
cmd /c npx pnpm@%PKG_VERSION% licenses list --json | npx @quantco/pnpm-licenses generate-disclaimer --json-input "--filter=["""@pnpm/*"""]" --output-file=ThirdPartyLicenses.txt
if errorlevel 1 exit 1
