" Vim ftdetect file
" Language:     confgen
" Maintainer:   Ivan Heffner <iheffner@marchex.com
" Last Change:
" Filenames:    *.confgen

augroup confgen
au confgen BufRead,BufNewFile *.confgen  set filetype=confgen
au confgen BufRead,BufNewFile */conf/pulley/*.conf set filetype=confgen
filetype plugin on

