scriptencoding utf-8
"見た目
if has("win32")
  set guifont=Fira_Code:h10.5
  set guifontwide=Myrica_M
  set linespace=0
  " DirectX
  set renderoptions=type:directx,renmode:5,taamode:1
endif
"アイコンバーの非表示
set guioptions-=T
"メニュー非表示
set guioptions-=m
set guioptions+=M
set winaltkeys=no
"スクロールバー非表示
set guioptions-=r
set guioptions-=R
set guioptions-=l
set guioptions-=L
set guioptions-=b
"タブ
set guioptions-=e
"gvimrcからコピペ
if has("kaoriya")
  set ambiwidth=auto
endif
