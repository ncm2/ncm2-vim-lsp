if exists('g:ncm2_vim_lsp')
    finish
endif
let g:ncm2_vim_lsp = 1

let s:servers = {} " { server_name: 1 }

au User lsp_server_init call s:register_source()
au User lsp_server_exit call s:unregister_source()

func! s:register_source() abort
    let server_names = lsp#get_server_names()
    for svr_name in server_names
        if has_key(s:servers, svr_name)
            continue
        endif
        let capabilities = lsp#get_server_capabilities(svr_name)
        let s:servers[svr_name] = has_key(capabilities, 'completionProvider')
        if !s:servers[svr_name]
            continue
        endif
        let trigger_chars = get(capabilities.completionProvider,
                    \ 'triggerCharacters', [])
        let patterns = ncm2_vim_lsp#get_complete_pattern(trigger_chars)
        let source_name = svr_name
        let source_opt = {
            \ 'name': source_name,
            \ 'priority': 9,
            \ 'mark': svr_name,
            \ 'sorter': 'none',
            \ 'on_complete': function('s:on_complete', [svr_name]),
            \ 'complete_pattern': patterns,
            \ }
        let server = lsp#get_server_info(svr_name)
        if has_key(server, 'whitelist')
            let source_opt['scope'] = server['whitelist']
        endif
        call ncm2#register_source(source_opt)
    endfor
endfunc

func! ncm2_vim_lsp#get_complete_pattern(trigger_chars)
    if empty(a:trigger_chars)
        return []
    endif
    py3 << EOF
import vim, re
complete_pattern = []
chars = vim.eval('a:trigger_chars')
for c in chars:
    complete_pattern.append(re.escape(c))
EOF
    return py3eval('complete_pattern')
endfunc

func! s:unregister_source() abort
    let server_names = lsp#get_server_names()
    for server_name in server_names
        if has_key(s:servers, server_name)
            let name = server_name
            if s:servers[server_name]
                call ncm2#unregister_source(name)
            endif
            unlet s:servers[server_name]
        endif
    endfor
endfunc

func! s:on_complete(server_name, ctx) abort
    call lsp#send_request(a:server_name, {
        \ 'method': 'textDocument/completion',
        \ 'params': {
        \   'textDocument': lsp#get_text_document_identifier(),
        \   'position': lsp#get_position(),
        \ },
        \ 'on_notification': function('s:on_completion_result', [a:server_name, a:ctx]),
        \ })
endfunc

func! s:on_completion_result(server_name, ctx, data) abort
    if lsp#client#is_error(a:data) || !has_key(a:data, 'response') || !has_key(a:data['response'], 'result')
        return
    endif

    let options = {
    	\ 'server': lsp#get_server_info(a:server_name),
    	\ 'response': a:data['response'],
    	\ 'position': lsp#get_position()
		\ }
    let result = lsp#omni#get_vim_completion_items(options)

    call ncm2#complete(a:ctx, a:ctx.startccol, result['items'], result['incomplete'])
endfunc

func! ncm2_vim_lsp#completionitem_resolve(user_data, item) abort
    let result = {}
    call lsp#send_request(a:user_data.vim_lsp.server_name, {
        \ 'method': 'completionItem/resolve',
        \ 'params': a:item,
        \ 'sync': 1,
        \ 'on_notification': function('s:on_resolve_result', [result]),
        \ })
    let ret = get(result, 'data', {})
    echom 'ret: ' . json_encode(ret)
    return ret
endfunc

func! s:on_resolve_result(result, data)
    let a:result.data = get(get(a:data, 'response', {}), 'result', {})
endfunc

