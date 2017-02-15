if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal dictionary+=~/vimfiles/pack/minpac/opt/vim-node-dict/dict/node.dict
