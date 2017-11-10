scriptencoding utf-8
"見た目
if has("win32")
  set guifont=Fira_Code:h10.5
  set guifontwide=Myrica_M
  set linespace=0
  " DirectX
  set renderoptions=type:directx,renmode:5,taamode:1
endif
"カレントラインのハイライト
" set cursorline
"アイコンバーの非表示
set guioptions-=T
"メニュー非表示
set guioptions-=m
"タブ
set guioptions-=e
"http://vim-jp.org/vim-users-jp/2011/10/05/Hack-234.html
"透明度
"とっても透けるよ！
if has("win32") && has("kaoriya")
  augroup beTransparent
    autocmd!
    autocmd FocusGained * set transparency=256
    autocmd FocusLost * set transparency=128
  augroup END
endif
"gvimrcからコピペ
if has("kaoriya")
  set ambiwidth=auto
endif
