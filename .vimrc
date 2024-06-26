set encoding=utf-8
set fileencodings=utf-8,cp932,sjis,euc-jp
scriptencoding utf-8

"設定 {{{
set ttyfast
"色
set t_Co=256
if $COLORTERM ==# 'truecolor' || $COLORTERM ==# '24bit'
  set termguicolors
endif
set iminsert=0
"ステータスバー
set laststatus=2
"不可視文字の表示
set list
set listchars=tab:->,eol:$,trail:-
"行番号
set number
"行番号のみカーソル位置表示 8.1.2019
set cursorline
set cursorlineopt=number
"@
set display=lastline
"閉じ括弧入力時に対応する開括弧に一瞬移動しない
set noshowmatch
"検索結果ハイライト
set hlsearch
"Sugoiインクリメンタル検索
set incsearch
"backspaceで文字を消す
set backspace=start
"スクロール時の上下マージン
set scrolloff=5
"マウス
set mouse=nv
"スクリプト動作中に描画しない
set lazyredraw
"タイトルを表示しない
set notitle
" vim-go
set completeopt=menu
"省略メッセージ設定
set shortmess=aoOT
set formatoptions& formatoptions-=r
"8進数除外
set nrformats-=octal
"タブ関連
set showtabline=2
"メニュー非ロード
let g:did_install_default_menus = 1
let g:did_install_syntax_menu = 1
"コマンドライン補完
set wildmenu
"検索ループ
set wrapscan
"インデント
set autoindent
set smartindent
set expandtab
set smarttab
set shiftwidth=2
let &tabstop = &shiftwidth
"マイナス値でshiftwidthの値を使用
set softtabstop=-1
"画面内改行時インデント
set breakindent
"負荷低減
set synmaxcol=500
"バックアップ関連
set history=16
set updatetime=10000
set updatecount=500
set nobackup
set viminfo=
" neovimでもminpacを使う
if has("nvim")
  set packpath^=~/.vim
endif
"ファイルの場所
if has("win32") || has("unix")
  set undodir=~/.cache/undo
  set directory=~/.cache/swp
else
  set undodir=
  set directory=
endif
"{{{
"折りたたみ設定
set foldmethod=marker
"}}}
"クリップボード連携
set clipboard& clipboard+=unnamed,unnamedplus,autoselect
"}}}

"キーマッピング {{{

if has("win32") || has("unix")
  let g:dotfiles_dir = $HOME."/dotfiles"
endif

"Yを行末までヤンクに変更
nnoremap Y y$
"Leader変更
let g:mapleader = "\<Space>"
"バッファのマッピング
nnoremap [b :bprevious<CR>
nnoremap ]b :bnext<CR>
"gTが入力しづらいので
nnoremap [t gT
nnoremap ]t gt
":wよりずっとﾊﾔｲ!
nnoremap <Leader>w :w<CR>
":qよりずっとﾎｧｲ!
nnoremap <Leader>q :q<CR>
"<Ctrl-w>がめんどくさいので
nnoremap <Leader>sh <C-w>h
nnoremap <Leader>sj <C-w>j
nnoremap <Leader>sk <C-w>k
nnoremap <Leader>sl <C-w>l

function! ToggleHlsearch() abort
  let &hlsearch = v:hlsearch ? 0 : 1
endfunction

nnoremap <Leader>hl :<C-u>call ToggleHlsearch()<CR>
"Exモード使わない
"以前はこうだったらしい(helpより)
nnoremap Q gq
".vimrcを開く
"$MYVIMRCはシンボリックリンクなので
nnoremap <expr> <Leader>v ":<C-u>e ".g:dotfiles_dir."/.vimrc<CR>"
"メモ代わりに
nnoremap <Leader>m :<C-u>tabnew `=tempname()`<CR>
"Tabで補完メニュー移動
inoremap <expr><TAB>  pumvisible() ? "\<C-n>" : "\<TAB>"
inoremap <expr><S-TAB>  pumvisible() ? "\<C-p>" : "\<S-TAB>"
"トレーニング
vnoremap <Up> <Nop>
vnoremap <Right> <Nop>
vnoremap <Down> <Nop>
vnoremap <Left> <Nop>
nnoremap <Up> <Nop>
nnoremap <Right> <Nop>
nnoremap <Down> <Nop>
nnoremap <Left> <Nop>
noremap <Home> <Nop>
noremap <End> <Nop>
"kaoriyaプラグインから移植
command! -nargs=0 CdCurrent cd %:p:h
"}}}

"minpac {{{
packadd minpac
if exists("g:loaded_minpac")

  call minpac#init()

  call minpac#add("k-takata/minpac", {
        \ "type": "opt"
        \})

  call minpac#add("w0ng/vim-hybrid", {
        \ "frozen": 1
        \})

  " Language Protocol Server
  call minpac#add("prabirshrestha/vim-lsp")
  call minpac#add("mattn/vim-lsp-settings")
  " LSP for TypeScript
  call minpac#add("ryanolsonx/vim-lsp-typescript")

  "括弧補完
  call minpac#add("mattn/vim-lexiv")
  "pugのシンタックス
  call minpac#add("digitaltoad/vim-pug")
  "CSS
  call minpac#add("hail2u/vim-css3-syntax")
  "JavaScript用シンタックス
  call minpac#add("pangloss/vim-javascript")
  call minpac#add("leafgarland/typescript-vim")
  "Go
  call minpac#add("mattn/vim-goimports")
  "TOML
  call minpac#add("cespare/vim-toml")
  call minpac#add("guileen/vim-node-dict", {
        \ "type": "opt",
        \ "frozen": 1
        \})
  "かっこいいバー
  call minpac#add("itchyny/lightline.vim")
  "editorconfig
  call minpac#add("sgur/vim-editorconfig")
  "コメントを楽にする
  call minpac#add("tyru/caw.vim")
  "標準プラグインより速いらしいので
  call minpac#add("itchyny/vim-parenmatch")
  "git
  call minpac#add("airblade/vim-gitgutter")
  "不要な空白
  call minpac#add("bronson/vim-trailing-whitespace")
  " tree viewer
  call minpac#add("lambdalisue/fern.vim")
endif
"}}}

filetype plugin indent on
syntax on

let g:javascript_plugin_flow = 1

if executable('typescript-language-server')
  au User lsp_setup call lsp#register_server({
    \ 'name': 'typescript-language-server',
    \ 'cmd': {server_info->[&shell, &shellcmdflag, 'typescript-language-server --stdio']},
    \ 'root_uri':{server_info->lsp#utils#path_to_uri(lsp#utils#find_nearest_parent_file_directory(lsp#utils#get_buffer_path(), 'tsconfig.json'))},
    \ 'whitelist': ['typescript', 'typescript.tsx'],
    \ })
  autocmd FileType typescript setlocal omnifunc=lsp#complete
endif

"lightline {{{
if exists("*minpac#init")
  let g:lightline = {
        \ "active": {
        \   "left": [
        \     ["my-mode", "paste"],
        \     ["my-git"],
        \     ["my-readonly", "my-path", "modified"] ,
        \   ],
        \   "right": [
        \     ["my-lineinfo"],
        \     ["my-bufinfo"],
        \     ["my-fileformat", "fileencoding", "my-filetype"],
        \   ]
        \ },
        \ "component_function": {
        \   "my-readonly": "LightLineReadOnly",
        \   "my-mode": "LightLineMode",
        \   "my-path": "LightLinePath",
        \   "my-filetype": "LightLineType",
        \   "my-fileformat": "LightLineFileformat",
        \   "my-bufinfo": "LightLineBufferInfo",
        \   "my-lineinfo": "LightLineLineInfo",
        \   "my-git": "LightLineGitGutter"
        \ },
        \ "tabline": {
        \   "right": []
        \ }
        \}
  let g:lightline.colorscheme = "wombat"

  function! LightLineReadOnly() abort
    if &readonly == 0
      return ""
    endif
    if winwidth(0) > 80
      return "Read Only"
    else
      return "RO"
    endif
  endfunction

  function! LightLinePath() abort
    if winwidth(0) <= 50
      return ""
    endif
    if expand("%:t") ==# ""
      return "[No Name]"
    endif
    return winwidth(0) > 70 && strlen(expand("%:p:~")) < 25 ? expand("%:p:~") : expand("%:t")
  endfunction

  function! LightLineMode() abort
    return &ft ==? "gitcommit" ? "Git" :
          \ lightline#mode()
  endfunction

  function! LightLineType() abort
    if winwidth(0) <= 70
      return ""
    endif
    return &filetype !=# "" ? &filetype : "no ft"
  endfunction

  function! LightLineEncoding() abort
    if winwidth(0) <= 70
      return ""
    endif
    return &fenc !=# "" ? &fenc : &enc
  endfunction

  function! LightLineFileformat() abort
    if winwidth(0) <= 70
      return ""
    endif
    return &fileformat !=# "" ? &fileformat : ""
  endfunction

  function! LightLineBufferInfo() abort
    let l:info = wordcount()
    return l:info.bytes
  endfunction

  function! LightLineLineInfo() abort
    if winwidth(0) > 60
      return printf("%3d/%d:%-2d", line("."), line("$"), col("."))
    else
      return printf("%3d:%-2d", line("."), col("."))
    endif
  endfunction

  function! LightLineGitGutter() abort
    if ! get(g:, "gitgutter_enabled", 0)
          \ || winwidth(0) <= 90
      return ""
    endif
    let l:symbols = [
          \ "+ ",
          \ "~ ",
          \ "- "
          \ ]
    let l:hunks = GitGutterGetHunkSummary()
    let l:ret = []
    for l:i in [0, 1, 2]
      if hunks[i] > 0
        call add(l:ret, l:symbols[i] . l:hunks[i])
      endif
    endfor
    return join(l:ret, " ")
  endfunction
endif
"}}}

colorscheme hybrid
"黒背景
set background=dark

"kaoriyaユーティリティの無効化 {{{
if has("kaoriya")
  let g:plugin_cmdex_disable = 1
  let g:plugin_autodate_disable = 1
  let g:plugin_dicwin_disable = 1
  let g:plugin_scrnmode_disable = 1
  let g:plugin_hz_ja_disable = 1
endif
"}}}

"デフォルトプラグインの無効化 {{{
let g:loaded_logipat = 1
let g:loaded_getscriptPlugin = 1
let g:loaded_2html_plugin = 1
let g:loaded_gzip = 1
let g:loaded_rrhelper = 1
let g:loaded_spellfile_plugin = 1
let g:loaded_tarPlugin = 1
let g:loaded_vimballPlugin = 1
let g:loaded_zipPlugin = 1
let g:loaded_netrwPlugin = 1
let g:loaded_matchparen = 1
"}}}

" defaults.vim 無効化 {{{
let g:skip_defaults_vim = 1
"}}}
