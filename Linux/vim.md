# Direction

`h, j, k, l`       : left, down, up, right

# Arranging text

`gqip / gwip / gq}`: hard wrap paragraph (set tw=80)

`xp / XP`          : switch characters forward / backward
`ddp / ddkP`       : switch lines forward / backward
`dawbP`            : switch words with previous ones


# Find magic

`/\<\d\,\d\>`      : find numbers

# Copy

`Y$`               : copy from the cursor position to the end of the line
`v then Y/d`       : visual mode 

# Uper / Lower Case

`gUU`              : change the current line to uppercase (same as VU).
`gUiw`             : change current word to uppercase.
`guu`              : change the current line to lowercase (same as Vu).
`u / U`            : lower / upper case current letter

# misc
`set nowrap`         : disable line wrap
`set number`         :  " Show line numbers (remove with set nu! / set nonu)                                       
`set relativenumber` :  " Show relative line numbers (remove with set nornu

`:noh`             : cancel current search highlight
`set listchars=trail:-,nbsp:_` : diplay trailing space and nbsp with `set list`

# Splits & Windows & tabs

## vim cmds

`vim -p *.py`

## Commands

`:sp`              : split horizontally
`:vsp`             : split vertical

`:tabedit {file}`  : edit specified file in a new tab (:tabe)
`:tabfind {file}`  : open a new tab with filename given, searching the 'path' to 
                   find it. path can be set with `:set path=.,,**`
`:tabclose`        : close current tab
`:tabclose {i}`    : close i-th tab
`:tabonly`         : close all other tabs (show only the current tab)

`:tabs`            : list all tabs including their displayed windows
`:tabm 0`          : move current tab to first
`:tabm`            : move current tab to last
`:tabm {i}`        : move current tab to position i+1

`:tabn`            : go to next tab
`:tabp`            : go to previous tab
`:tabfirst`        : go to first tab
`:tablast`         : go to last tab
`:tab sp`          : split current file to tab

## Keys

Ctrl-w h j k l   : move to the window in the selected direction

Ctrl-w H J K L   : switch from vertical to horizontal split
Ctrl-wt Ctrl-K   : change from vertical split to horizontal
Ctrl-wt Ctrl-H   : change from horizontal split to vertical

Ctrl-w =         : resize to equal size
Ctrl-w _         : decrease size
Ctrl-w |         : increase size

Ctrl-w r         : Swap top/bottom or left/right split
Ctrl-w T         : Break out current window into a new tabview
Ctrl-w o         : close all windows except for the current one

gt / gT          : go to next / previous tab
{i}gt            : go to the ith tab

## Configuration

`set splitbelow`
`set splitright`

## Remaps

`nnoremap <C-J> <C-W><C-J>` : remap Ctrl w-j to Ctrl j
`nnoremap <C-K> <C-W><C-K>` : remap Ctrl w-j to Ctrl k
`nnoremap <C-L> <C-W><C-L>` : remap Ctrl w-j to Ctrl l
`nnoremap <C-H> <C-W><C-H>` : remap Ctrl w-j to Ctrl h
