" Vim syntax file
" Language:     confgen
" Maintainer:   Ivan Heffner <iheffner@marchex.com
" Last Change:
" Filenames:    *.confgen

" Quit when a syntax file was already loaded
if exists("b:current_syntax")
    finish
endif

set cpo&vim

syn match confgenTagStart   +^\s*<\zs[a-zA-Z]\+\>\ze\%(\s\+[a-zA-Z0-9.-]\+\)*>+
syn match confgenTagEnd     +^\s*</\zs[a-zA-Z]\+\ze>+

syn match confgenHost       +\%(^\s*<\%(magic\)\?host\s\+\)\@<=\zs\%([[:space:]a-zA-Z0-9._-]\+\)\ze>+

syn region confgenHereDoc    start=+<<\z([a-zA-Z]\+\)\>+ end=+^\s*\z1\>+ contains=confgenVariable keepend extend
syn region confgenString     start=+"+ end=+"+ contains=confgenVariable,confgenEscrowKey
syn region confgenString     start=+'+ end=+'+
syn region confgenComment    start=+#+ end=+$+
syn region confgenExecute    start=+!\@<!!!\@!+ end=+\\\@<!$+ contains=confgenVariable,confgenEscrowKey
syn region confgenExecute    start=+\(Command Exec \d\+ \d\+\)\@<=.+ end=+\\\@<!$+ contains=confgenVariable,confgenEscrowKey

syn match confgenVersion    +\%(<version \)\@<=\zs[0-9]\.[0-9]\ze>+
syn match confgenVariable   +\${[a-zA-Z][a-zA-Z0-9_]*}\|\$[a-zA-Z][a-zA-Z0-9_]*\>+
syn match confgenEscrowKey  +!!![a-zA-Z_][.0-9a-zA-Z0-9_]*!!!+
syn match confgenIdentifier +^\s*\zs[a-zA-Z_][.0-9a-zA-Z0-9_]*+

syn keyword confgenKeyword  Include AddTemplate

syn match   confgenInclude  +\%(Include\s\+\)\@<=.*+
syn match   confgenTemplate +\%(AddTemplate\s\+\)\@<=.*+

" Default highlight colors
hi def link confgenString     String
hi def link confgenVariable   Identifier
hi def link confgenComment    Comment
hi def link confgenKeyword    Keyword
hi def link confgenIdentifier Identifier
hi def link confgenValue      Normal
hi def link confgenExecute    Execute
hi def link confgenEscrowKey  Todo
hi def link confgenVersion    Constant
hi def link confgenTagStart   Function
hi def link confgenTagEnd     Function
hi def link confgenHost       Constant
hi def link confgenHereDoc    String
hi def link confgenTemplate   Special
hi def link confgenInclude    PreProc
