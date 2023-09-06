#!/bin/env sh
# TODO have ../dist/run do this
rm -fr dist
../dist/run.lua
# and maybe TODO have ../dist/run allow from->to mapping so this is easier to implement in distinfo
rm dist/Zelda4D-linux64.zip
mv dist/Zelda4D-linux64 dist/Zelda4D
cp -R bin_Windows dist/Zelda4D/data/bin/Windows
cp run_Windows/* dist/Zelda4D/
mv dist/Zelda4D/run.sh dist/Zelda4D/run-linux.sh
cd dist
zip -r Zelda4D.zip Zelda4D/
