"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Author:           Anton DeVore
"
" Thanks to anyone who's vim settings I took. Thanks to the internet and all
" useful webpages. I wish I could reference and thank everyone specifically but
" I added this section long after I built up my vimrc
"
" Thanks to Gene Zhang, Gene Hsu, Jeff Lowdermilk

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function Definitions
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" toggle fold state
fun! ToggleFold()
  if foldlevel('.') == 0
  normal! l
  else
  if foldclosed('.') < 0
  . foldclose
  else
  . foldopen
  endif
  endif
  " Clear status line
  echo
endfun

" Move current line down/up one line
fun! MoveCurLineDown()
  " not on last line
  if line("$")!=line(".")
    m+1<CR>
    " clear the line
  endif
  echo
endfun

fun! MoveCurLineUp()
  if line(".") != 1
    " clear the line
    m-2<CR>
  endif
  echo
endfun

" set vim to fold by braces (instead of, say, by indentation)
fun! FoldBraces()
  set foldmethod=marker
  set foldmarker={,}
  set foldtext=getline(v:foldstart)
endfun


" Use Vim settings, rather then Vi settings (much better!).
" This must be first, because it changes other options as a side effect.
set nocompatible

" TODO: this may not be in the correct place. It is intended to allow overriding <Leader>.
" source ~/.vimrc.before if it exists.
if filereadable(expand("~/.vimrc.before"))
  source ~/.vimrc.before
endif

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Pathogen Initialization
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" This loads all the plugins in ~/.vim/bundle
" Use tpope's pathogen plugin to manage all other plugins

"  runtime bundle/tpope-vim-pathogen/autoload/pathogen.vim
filetype off
call pathogen#incubate()
call pathogen#helptags()
" execute pathogen#infect()
call pathogen#infect('runtimes/{}')

filetype plugin indent on

set modelines=0

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Nerdtree
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
if has('autocmd')
  "autocmd vimenter * NERDTree " automatically starts up Nerdtree
  autocmd vimenter * wincmd p
  autocmd vimenter * if !argc() | NERDTree | endif
  autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTreeType") && b:NERDTreeType == "primary") | q | endif
endif

map <C-n> :NERDTreeToggle<CR>

" Quit on opening files from the tree
let NERDTreeQuitOnOpen=1

" Highlight the selected entry in the tree
let NERDTreeHighlightCursorline=1

" Use a single click to fold/unfold directories and a double click to open
" files
let NERDTreeMouseMode=2

" Don't display these kinds of files
let NERDTreeIgnore=[ '\.pyc$', '\.pyo$', '\.py\$class$', '\.obj$',
            \ '\.o$', '\.so$', '\.egg$', '^\.git$' ]

" Show hidden files
"let NERDTreeShowHidden=1

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Information bar
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
hi User1 term=underline cterm=bold ctermfg=Cyan ctermbg=Blue guifg=#40ffff guibg=#0000aa
set laststatus=2
"set statusline=%F%m%r%h%w\ [FORMAT=%{&ff}]\ [TYPE=%Y]\ [ASCII=\%03.3b]\ [HEX=\%02.2B]\ [POS=%04l,%04v][%p%%]\ [LEN=%L]
"set statusline=%<[%02n]\ %F%(\ %m%h%w%y%r%)\ %a%=\ %8l,%c%V/%L\ (%P)\ [%08O:%02B]
set statusline=%1*%F%m%r%h%w%=%(%c%V\ %l/%L\ %P%)
set title titlestring=...%{strpart(expand(\"%:p:h\"),stridx(expand(\"%:p:h\"),\"/\",strlen(expand(\"%:p:h\"))-12))}%=%n.\ \ %{expand(\"%:t:r\")}\ %m\ %Y\ \ \ \ %l\ of\ %L

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" General
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let mapleader=","

set autoread                    " reload files changed outside vim
set backspace=indent,eol,start  " allow backspace over everything in insert mode
"set colorcolumn=85              " so you can see when writing a line that is too long
set fileformats="unix,dos,mac"
set formatoptions=qrn1          " when wrapping paragraphs, don't end lines
                                "   with 1-letter words (not sure about qrn)
set gcr=a:blinkon0              " disable cursor blink
set history=1000                " store lots of :cmdline history
set mouse=a                     " enable using the mouse if terminal emulator supports it
set number                      " line numbers are good
set pastetoggle=<F2>            " when in insert mode, press <F2> to go to
                                "   paste mode, where you can paste mass data
                                "   that won't be autoindented
set shortmess+=I                " hide the launch screen
set showcmd                     " show incomplete cmds down the bottom
set showmatch                   " set show matching parenthesis
set showmode                    " show current mode down the bottom
set smartcase                   " ignore case if search pattern is all lowercase,
                                "   case-sensitive otherwise
"set textwidth=79                " formats long lines somehow
set nrformats=                  " make <C-a> and <C-x> play well with zero
                                "   padded numbers (i.e. don't consider
                                "   them octal or hex)
set enc=utf8                    " set character encoding to utf8


" have Vim always cd to the current file's directory.
"if version>=640  | set autochdir | endif

" Toggle show/hide invisible chars
nnoremap <leader>i :set list!<cr>

" Toggle line numbers
nnoremap <leader>N :setlocal number!<cr>

" inserts \v before any string you search for which turns off Vim's crazy
" default regex characters and makes searches use normal regexes
"nnoremap / /\v
"vnoremap / /\v

" Speed up scrolling of the viewport slightly
nnoremap <C-e> 2<C-e>
nnoremap <C-y> 2<C-y>

" Disable use of arrow keys in both normal and insert mode
nnoremap <up> <nop>
nnoremap <down> <nop>
nnoremap <left> <nop>
nnoremap <right> <nop>
inoremap <up> <nop>
inoremap <down> <nop>
inoremap <left> <nop>
inoremap <right> <nop>

" 'Movement by file line instead of screen line'
nnoremap j gj
nnoremap k gk

" Use of zz, which centers your current line, made easier
nmap <space> zz
nmap n nzz
nmap N Nzz

" F1 key brings up help menu, map it to escape key
inoremap <F1> <ESC>
nnoremap <F1> <ESC>
vnoremap <F1> <ESC>

" Write all files when focus of Vim is lost
au FocusLost * :wa

" Quickly strip all trailing whitespace in the current file
nnoremap <leader>rw :%s/\s\+$//<cr>:let @/=''<CR>

" Quickly replace all tabs with spaces
nnoremap <leader>rt :%s/\t/  /g<Enter>

" Search and replace selected text
vnoremap <C-r> "hy:%s/<C-r>h//g<left><left>

" Quickly escape from insert mode
inoremap jj <ESC>

" reselect the text that was just pasted
nnoremap <leader>v V`]

" Sudo write a file when inside it
cmap w!! w !sudo tee % > /dev/null %

" This makes vim act like all other editors, buffers can
" exist in the background without being in a window.
" http://items.sjbach.com/319/configuring-vim-right
set hidden

" do not redraw while running macros (much faster) (LazyRedraw)
set lazyredraw

" Quickly edit/reload the vimrc file
nmap <silent> <leader>ev <C-w><C-v><C-l>:e $MYVIMRC<CR>
nmap <silent> <leader>sv :so $MYVIMRC<CR>

" Compile your perl or ruby file
nmap <leader>pl :w<CR>:!perl -cw %<CR>
nmap <leader>rb :w<CR>:!ruby -c %<CR>

" should work but hasn't
autocmd FileType gitcommit setlocal spell textwidth=72

" set filetype and syntax of certain file extensions
autocmd BufRead,BufNewFile *.xpl set filetype=perl syntax=perl
autocmd BufRead,BufNewFile *.tap set filetype=perl syntax=perl
autocmd BufRead,BufNewFile *.psgi set filetype=perl syntax=perl
autocmd BufRead,BufNewFile *.ddl set filetype=sql  syntax=sql
autocmd BufRead,BufNewFile *.func set filetype=sh  syntax=sh


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Taglist
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Turn tags on
map <leader>t :TlistToggle<CR>

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Editing/Navigation
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" inserting a new-line w/o entering insert mode
map <C-Enter> i<Enter><Up><ESC>$
map <S-Enter> O<ESC>
map <Enter> o<ESC>

" navigate between splits
map <C-J> <C-W>j
map <C-K> <C-W>k
map <C-H> <C-W>h
map <C-L> <C-W>l

" split vertically/horizontally and switch over
" not sure what a good mapping is
"nmap <C-i> <C-w>v<C-l>:e .<CR>
"nmap <C-o> <C-w>s<C-j>:e .<CR>

" Open split screen and switch over
nnoremap <leader>w <C-w>v<C-w>l

" Handles swapping one window with another
function! MarkWindowSwap()
  let g:markedWinNum = winnr()
endfunction

function! DoWindowSwap()
  "Mark destination
  let curNum = winnr()
  let curBuf = bufnr( "%" )
  exe g:markedWinNum . "wincmd w"
  "Switch to source and shuffle dest->source
  let markedBuf = bufnr( "%" )
  "Hide and open so that we aren't prompted and keep history
  exe 'hide buf' curBuf
  "Switch to dest and shuffle source->dest
  exe curNum . "wincmd w"
  "Hide and open so that we aren't prompted and keep history
  exe 'hide buf' markedBuf
endfunction

nmap <silent> <leader>mw :call MarkWindowSwap()<CR>
nmap <silent> <leader>pw :call DoWindowSwap()<CR>


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Theme/Colors
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Have syntax highligting in terminals which can display colors:
if has('syntax') && (&t_Co > 2)
  syntax on
endif

" Set color scheme
"if &t_Co >= 256 || has("gui_running")
"   "colorscheme molokai
"   colorscheme desert
"endif

colorscheme desert
"colorscheme molokai
"colorscheme jellybeans

autocmd FileType perl colorscheme ansi_blows

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Folding
"
" Enable folding, but by default make it act like folding is off, because
" folding is annoying in anything but a few rare cases
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Map toggle folding Space key.
" noremap <space> :call ToggleFold()<CR>

" Turn on folding
set foldenable

" Make folding indent sensitive
set foldmethod=indent

" Don't autofold anything (but I can still fold manually)
set foldlevel=100

" don't open folds when you search into them
set foldopen-=search

" don't open folds when you undo stuff
set foldopen-=undo

"
" Fold on braces instead of indentation
autocmd BufRead *.php* call FoldBraces()
autocmd BufRead *.php call FoldBraces()
autocmd BufRead *.inc call FoldBraces()
autocmd BufRead *.c call FoldBraces()
autocmd BufRead *.cpp call FoldBraces()
autocmd BufRead *.em call FoldBraces()  // source insight
autocmd BufRead *.idl call FoldBraces()
autocmd BufRead *.cc call FoldBraces()
autocmd BufRead *.java call FoldBraces()
autocmd BufRead *.h call FoldBraces()
autocmd BufRead *.pl call FoldBraces()
autocmd BufRead *.pm call FoldBraces()
autocmd BufRead *.scala call FoldBraces()
"autocmd BufRead *.uccapilog call FoldUccApiLog()

" - counts is not word delimiter in xml
autocmd BufRead *.xml set iskeyword+=-
autocmd BufRead *.xsd set iskeyword+=- " |set tabstop=2 | set softtabstop=2 | set shiftwidth=2 |
autocmd BufRead *.xsd set tabstop=2 | set softtabstop=2 | set shiftwidth=2
autocmd BufRead *.xml set tabstop=2 | set softtabstop=2 | set shiftwidth=2
autocmd BufRead *.sls set iskeyword-=$

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" (Weird) Mappings
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" right arrow (normal mode) switches buffers  (excluding minibuf)
" map <right> <ESC>:MBEbn<RETURN>

" left arrow (normal mode) switches buffers (excluding minibuf)
" map <left> <ESC>:MBEbp<RETURN>

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Search Settings
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

set ignorecase        " ignore case when searching
set incsearch         " find the next match as we type the search
set hlsearch          " highlight searches by default
set viminfo='100,f1   " save up to 100 marks, enable capital marks
set matchpairs+=<:>   " allow % to bounce between angles too

" makes tab key match bracket pairs, currently doesn't work because tab is
" over-written somewhere
"nnoremap <tab> %
"vnoremap <tab> %

" Search for selected text, forwards or backwards.
vnoremap <silent> * :<C-U>
  \let old_reg=getreg('"')<Bar>let old_regtype=getregtype('"')<CR>
  \gvy/<C-R><C-R>=substitute(
  \escape(@", '/\.*$^~['), '\_s\+', '\\_s\\+', 'g')<CR><CR>
  \gV:call setreg('"', old_reg, old_regtype)<CR>
vnoremap <silent> # :<C-U>
  \let old_reg=getreg('"')<Bar>let old_regtype=getregtype('"')<CR>
  \gvy?<C-R><C-R>=substitute(
  \escape(@", '?\.*$^~['), '\_s\+', '\\_s\\+', 'g')<CR><CR>
  \gV:call setreg('"', old_reg, old_regtype)<CR>


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Turn Off Swap Files
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

set nobackup
set noswapfile
set nowb
set nowritebackup

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Persistent Undo
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Keep undo history across sessions, by storing in file.
" Only works in MacVim (gui) mode.

"if has('gui_running')
"  set undodir=~/.vim/backups
"  set undofile
"endif

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Indentation
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

set autoindent    " always set autoindenting on
set copyindent    " copy the previous indentation on autoindenting
set expandtab     " expand tabs by default (overloadable per file type)
set shiftround    " use multiple of shiftwidth when indenting with '<' and '>'
set shiftwidth=2  " number of spaces to use for autoindenting
set smartindent
set smarttab      " insert tabs on the start of a line according to shiftwidth, not tabstop
set softtabstop=2 " when hitting <BS>, pretend like a tab is removed, even if spaces
set tabstop=2     " tabs are n spaces

autocmd FileType perl setlocal sw=4 ts=2 sts=2
autocmd FileType *.tap setlocal sw=4 ts=2 sts=2
autocmd FileType *.xpl setlocal sw=4 ts=2 sts=2
autocmd FileType *.psgi setlocal sw=4 ts=4 sts=4
autocmd FileType javascript setlocal sw=4 ts=2 sts=2
autocmd FileType java setlocal sw=4 ts=2 sts=2

"Display tabs and trailing spaces visually
"set list listchars=tab:\ \ ,trail:·
set list listchars=tab:>-,trail:•,extends:#,nbsp:.

"set nowrap    "Don't wrap lines
set linebreak  "Wrap lines at convenient points

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Comments
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" CommentBlock -- highlight a block and comment it out; or uncomment it

" This will allow language-specific comment markers
" By setting up some auto commands, you can change this
" based on the on the file type of your current buffer and
" it will work for multiple languages
"
" Use by:
"   highlight the block to comment/uncomment
"       * press ## to comment or
"       * press !# to uncomment

"hi Comment ctermfg=green
let g:comment_char = "\""

function! Comment()
    let l:line = g:comment_char.getline(".")
    call setline(".",l:line)
endfunction

function! UnComment()
    let l:line = getline(".")
    let l:pos  = stridx(l:line,g:comment_char)
    if  l:pos > -1
        let l:line = strpart(l:line,0,l:pos).strpart(l:line,l:pos+strlen(g:comment_char))
    endif
    call setline(".",l:line)
endfunction

map ## :call Comment()<cr>
map !# :call UnComment()<cr>

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Completion
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

set wildmode=list:longest
set wildmenu                  "enable ctrl-n and ctrl-p to scroll thru matches
set wildignore=*.o,*.obj,*~,*.swp,*.bak,*.pyc,*.class "stuff to ignore when tab completing
set wildignore+=*vim/backups*

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Scrolling
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

set scrolloff=8     "Start scrolling when we're 8 lines away from margins
"set sidescrolloff=15
set sidescroll=4
set virtualedit=all " allow the cursor to go into invalid places

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Highlighting
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

hi CursorLine cterm=underline
hi CursorColumn cterm=NONE ctermbg=cyan ctermfg=white guibg=darkred guifg=white
nnoremap <leader>l :set cursorline! <CR>
nnoremap <leader>c :set cursorcolumn! <CR>
nnoremap <leader><space> :noh<cr>

set cursorline

"highlight RedundantSpaces term=standout ctermbg=red guibg=red
"match RedundantSpaces /\s\+$\| \+\ze\t/
