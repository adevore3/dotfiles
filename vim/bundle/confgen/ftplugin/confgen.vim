" Vim ftplugin file
" Language:     confgen
" Maintainer:   Ivan Heffner <iheffner@marchex.com
" Last Change:
" Filenames:    *.confgen

" Quit when a this has already been loaded
if exists("g:loaded_confgen_plugin")
    finish
endif
let g:loaded_confgen_plugin = 1

set iskeyword+=.,-

fun! s:UpdateTags()
    let l:filename=shellescape(expand('%'))
    let l:grepResults=system("grep -E 'Include|AddTemplate' " . l:filename)
    let l:tagMatches=split(l:grepResults,'\n')
    let l:path=expand('%:p:h')

    let l:pattern='^.*\([I]nclude\|[A]ddTemplate\)\s\+\(.*\)'
    let l:replacement='\2\t' . l:path . '/\2\t:0'

    let l:seen = {}
    for l:source in l:tagMatches
        let l:value = substitute(l:source,l:pattern,l:replacement,'')
        let l:seen[l:source] = l:value
    endfor

    let l:tempfile=tempname()

    let l:tagLines=sort( values( l:seen ) )

    call writefile(l:tagLines,l:tempfile)

    let &tags=l:tempfile

    augroup confgen
    au confgen BufDelete,BufWipeout,BufUnload % call delete(l:tempfile)
endfun

au confgen BufEnter,BufRead,BufNewFile *.confgen call s:UpdateTags()
