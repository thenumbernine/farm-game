#!/usr/bin/env sh
# if texatlas.lua fails then don't overwrite:
set -e
../../texatlas/texatlas.lua sprites/
mv atlas.lua ../sprites/
mv atlas.png ../sprites/
