#!/usr/bin/env sh
# maybe I should have this downsize-and-copy like the src_online -> sprites script does
mkdir sprites
rsync -avm --exclude='.*' --include='*.png' -f 'hide,! */' 'src_manual/' 'sprites/'
