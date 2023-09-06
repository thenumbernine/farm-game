#!/usr/bin/env sh
rm sprites/atlas.png
rm sprites/atlas.lua
../texatlas/texatlas.lua sprites/
mv atlas.lua sprites/
mv atlas.png sprites/
