if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal dictionary+=~/.vim/bundle/repos/github.com/guileen/vim-node-dict/dict/node.dict
