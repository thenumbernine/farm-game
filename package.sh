#!/bin/env sh
# TODO have ../dist/run do this
rm -fr dist
../dist/run.lua
# and maybe TODO have ../dist/run allow from->to mapping so this is easier to implement in distinfo
rm dist/FarmGame-linux64.zip
mv dist/FarmGame-linux64 dist/FarmGame
cp -R bin_Windows dist/FarmGame/data/bin/Windows
cp run_Windows/* dist/FarmGame/
mv dist/FarmGame/run.sh dist/FarmGame/run-linux.sh
cd dist
zip -r FarmGame.zip FarmGame/
