
## Introduction

This plugin connect the completion support between
[prabirshrestha/vim-lsp](https://github.com/prabirshrestha/vim-lsp) and
[ncm2/ncm2](https://github.com/ncm2/ncm2).

## Installation

```vim
Plug 'prabirshrestha/vim-lsp'
Plug 'ncm2/ncm2-vim-lsp'
```

## Config

For registering language servers, please read the documentation of
[vim-lsp](https://github.com/prabirshrestha/vim-lsp#registering-servers).

Particular servers can be excluded by including their name (as configured
in vim-lsp) in the list `g:ncm2_vim_lsp_blocklist`. e.g.
```vim
let g:ncm2_vim_lsp_blocklist = ['jedi-language-server','efm-language-server']
```
