if exists('g:ncm2_vim_lsp')
    finish
endif
let g:ncm2_vim_lsp = 1

let s:servers = {} " { server_name: 1 }

au User lsp_server_init call s:register_source()
au User lsp_server_exit call s:unregister_source()

func! s:get_source_name(server_name) abort
    return 'ncm2_vim_lsp_' . a:server_name
endfunc

func! s:register_source() abort
    let server_names = lsp#get_server_names()
    for server_name in server_names
        if !has_key(s:servers, server_name)
            let init_capabilities = lsp#get_server_capabilities(server_name)
            if has_key(init_capabilities, 'completionProvider')
                " TODO: support triggerCharacters
                let name = s:get_source_name(server_name)
                let source_opt = {
                    \ 'name': name,
                    \ 'priority': 9,
                    \ 'mark': 'lsp',
                    \ 'on_complete': function('s:on_complete', [server_name]),
                    \ 'complete_pattern': ['.'],
                    \ }
                let server = lsp#get_server_info(server_name)
                if has_key(server, 'whitelist')
                    let source_opt['scope'] = server['whitelist']
                endif
                call ncm2#register_source(source_opt)
                let s:servers[server_name] = 1
            else
                let s:servers[server_name] = 0
            endif
        endif
    endfor
endfunc

func! s:unregister_source() abort
    let l:server_names = lsp#get_server_names()
    for l:server_name in l:server_names
        if has_key(s:servers, l:server_name)
            let l:name = s:get_source_name(l:server_name)
            if s:servers[l:server_name]
                call ncm2#unregister_source(l:name)
            endif
            unlet s:servers[l:server_name]
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

    let result = a:data['response']['result']

    if type(result) == type([])
        let items = result
        let incomplete = 0
    else
        let items = result['items']
        let incomplete = result['isIncomplete']
    endif

    " fill user_data
    let lspitems = deepcopy(items)
    call map(items, 'lsp#omni#get_vim_completion_item(v:val)')
    let i = 0
    while l:i < len(items)
        let ud = {}
        let ud['lspitem'] = lspitems[i]
        let ud['vim_lsp'] = {'server_name': a:server_name}
        let items[i].user_data = ud
        let i += 1
    endwhile

    call ncm2#complete(a:ctx, a:ctx.startccol, items, incomplete)
endfunc

func! ncm2_vim_lsp#completionitem_resolve(user_data, item) abort
    let result = {}
    call lsp#send_request(a:user_data.vim_lsp.server_name, {
        \ 'method': 'completionItem/resolve',
        \ 'params': a:item,
        \ 'on_notification': function('s:on_resolve_result', [result]),
        \ })
    let i = 0
    " FIXME sync call should be implemented in vim-lsp
    while l:i < 40
        sleep 25m
        if !empty(result)
            break
        endif
        let i += 1
    endwhile
    let ret = get(result, 'data', {})
    echom 'ret: ' . json_encode(ret)
    return ret
endfunc

func! s:on_resolve_result(result, data)
    let a:result.data = get(get(a:data, 'response', {}), 'result', {})
endfunc

