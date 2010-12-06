" vim:foldmethod=marker:fen:sw=4:sts=4
scriptencoding utf-8


" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}


let g:eskk#version = str2nr(printf('%02d%02d%03d', 0, 5, 121))


function! s:SID() "{{{
    return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
endfunction "}}}
let s:SID_PREFIX = s:SID()
delfunc s:SID



" Variables {{{

" mode:
"   Current mode.
" buftable:
"   Buffer strings for inserted, filtered and so on.
" is_locked_old_str:
"   Lock current diff old string?
" temp_event_hook_fn:
"   Temporary event handler functions/arguments.
" enabled:
"   True if s:eskk.enable() is called.
" enabled_mode:
"   Vim's mode() return value when calling eskk#enable().
" has_started_completion:
"   completion has been started from eskk.
let s:eskk = {
\   'mode': '',
\   'buftable': {},
\   'is_locked_old_str': 0,
\   'temp_event_hook_fn': {},
\   'enabled': 0,
\   'has_started_completion': 0,
\   'prev_im_options': {},
\   'prev_normal_keys': {},
\   'completion_selected': 0,
\   'completion_inserted': 0,
\   'bv': {},
\}



" NOTE: Following variables are non-local (global) between instances.

" s:Eskk instances.
let s:eskk_instances = []
" Index number for current instance.
let s:eskk_instance_id = 0
" Supported modes and their structures.
let s:available_modes = {}
" Event handler functions/arguments.
let s:event_hook_fn = {}
" Global values of &iminsert, &imsearch.
let s:saved_im_options = []
" Global values of &backspace.
let s:saved_backspace = -1
" Flag for `eskk#_initialize()`.
let s:is_initialized = 0
" SKK Dictionary (singleton)
let s:skk_dict = {}
" Mode and its table.
let s:mode_vs_table = {}
" All tables structures.
let s:table_defs = {}
" `eskk#mappings#map_all_keys()`
" and `eskk#mappings#unmap_all_keys()`
" toggle this value.
let s:mapped_bufnr = {}
" All special mappings eskk knows.
" `special` means "they don't have something to do with mappings Vim knows."
let s:eskk_mappings = {
\   'general': {},
\   'sticky': {},
\   'backspace-key': {},
\   'escape-key': {},
\   'enter-key': {},
\   'undo-key': {},
\   'tab': {},
\   'phase:henkan:henkan-key': {},
\   'phase:okuri:henkan-key': {},
\   'phase:henkan-select:choose-next': {},
\   'phase:henkan-select:choose-prev': {},
\   'phase:henkan-select:next-page': {},
\   'phase:henkan-select:prev-page': {},
\   'phase:henkan-select:escape': {},
\   'phase:henkan-select:delete-from-dict': {},
\   'mode:hira:toggle-hankata': {'fn': 's:handle_toggle_hankata'},
\   'mode:hira:ctrl-q-key': {'fn': 's:handle_ctrl_q_key'},
\   'mode:hira:toggle-kata': {'fn': 's:handle_toggle_kata'},
\   'mode:hira:q-key': {'fn': 's:handle_q_key'},
\   'mode:hira:l-key': {'fn': 's:handle_l_key'},
\   'mode:hira:to-ascii': {'fn': 's:handle_to_ascii'},
\   'mode:hira:to-zenei': {'fn': 's:handle_to_zenei'},
\   'mode:hira:to-abbrev': {'fn': 's:handle_to_abbrev'},
\   'mode:kata:toggle-hankata': {'fn': 's:handle_toggle_hankata'},
\   'mode:kata:ctrl-q-key': {'fn': 's:handle_ctrl_q_key'},
\   'mode:kata:toggle-kata': {'fn': 's:handle_toggle_kata'},
\   'mode:kata:q-key': {'fn': 's:handle_q_key'},
\   'mode:kata:l-key': {'fn': 's:handle_l_key'},
\   'mode:kata:to-ascii': {'fn': 's:handle_to_ascii'},
\   'mode:kata:to-zenei': {'fn': 's:handle_to_zenei'},
\   'mode:kata:to-abbrev': {'fn': 's:handle_to_abbrev'},
\   'mode:hankata:toggle-hankata': {'fn': 's:handle_toggle_hankata'},
\   'mode:hankata:ctrl-q-key': {'fn': 's:handle_ctrl_q_key'},
\   'mode:hankata:toggle-kata': {'fn': 's:handle_toggle_kata'},
\   'mode:hankata:q-key': {'fn': 's:handle_q_key'},
\   'mode:hankata:l-key': {'fn': 's:handle_l_key'},
\   'mode:hankata:to-ascii': {'fn': 's:handle_to_ascii'},
\   'mode:hankata:to-zenei': {'fn': 's:handle_to_zenei'},
\   'mode:hankata:to-abbrev': {'fn': 's:handle_to_abbrev'},
\   'mode:ascii:to-hira': {'fn': 's:handle_toggle_hankata'},
\   'mode:zenei:to-hira': {'fn': 's:handle_toggle_hankata'},
\   'mode:abbrev:henkan-key': {},
\}
" }}}



function! eskk#load() "{{{
    runtime! plugin/eskk.vim
endfunction "}}}



" Instance
function! s:eskk_new() "{{{
    return deepcopy(s:eskk, 1)
endfunction "}}}
function! eskk#get_current_instance() "{{{
    return s:eskk_instances[s:eskk_instance_id]
endfunction "}}}
function! eskk#initialize_instance() "{{{
    let s:eskk_instances = [s:eskk_new()]
    let s:eskk_instance_id = 0
endfunction "}}}
function! eskk#create_new_instance() "{{{
    " TODO: CoW

    " Create and push the instance.
    call add(s:eskk_instances, s:eskk_new())
    let s:eskk_instance_id += 1

    " Initialize instance.
    call eskk#enable(0)
endfunction "}}}
function! eskk#destroy_current_instance() "{{{
    if s:eskk_instance_id == 0
        throw eskk#internal_error(['eskk'], "No more instances.")
    endif

    " Destroy current instance.
    call remove(s:eskk_instances, s:eskk_instance_id)
    let s:eskk_instance_id -= 1
endfunction "}}}

" buffer-local value.
function! eskk#buffer_value_has(name) "{{{
    let bv = eskk#get_current_instance().bv
    return eskk#util#has_key_f(bv, [bufnr('%'), a:name])
endfunction "}}}
function! eskk#buffer_value_remove(name) "{{{
    let bv = eskk#get_current_instance().bv
    let nr = bufnr('%')
    if has_key(bv, nr) && has_key(bv[nr], a:name)
        unlet bv[nr][a:name]
    endif
endfunction "}}}
function! eskk#buffer_value_get(name) "{{{
    let bv = eskk#get_current_instance().bv
    return bv[bufnr('%')][a:name]
endfunction "}}}
function! eskk#buffer_value_put(name, Value) "{{{
    let bv = eskk#get_current_instance().bv
    call eskk#util#let_f(bv, [bufnr('%'), a:name], a:Value)
endfunction "}}}

" Filter
" s:asym_filter {{{
let s:asym_filter = {'table': {}}

function! eskk#create_asym_filter(table) "{{{
    let obj = deepcopy(s:asym_filter)
    let obj.table = a:table
    return obj
endfunction "}}}

function! s:asym_filter.filter(stash) "{{{
    let char = a:stash.char
    let buftable = a:stash.buftable
    let phase = a:stash.phase


    " Handle special mode-local mapping.
    let cur_mode = eskk#get_mode()
    let toggle_hankata = printf('mode:%s:toggle-hankata', cur_mode)
    let ctrl_q_key = printf('mode:%s:ctrl-q-key', cur_mode)
    let toggle_kata = printf('mode:%s:toggle-kata', cur_mode)
    let q_key = printf('mode:%s:q-key', cur_mode)
    let l_key = printf('mode:%s:l-key', cur_mode)
    let to_ascii = printf('mode:%s:to-ascii', cur_mode)
    let to_zenei = printf('mode:%s:to-zenei', cur_mode)
    let to_abbrev = printf('mode:%s:to-abbrev', cur_mode)

    for key in [
    \   toggle_hankata,
    \   ctrl_q_key,
    \   toggle_kata,
    \   q_key,
    \   l_key,
    \   to_ascii,
    \   to_zenei,
    \   to_abbrev
    \]
        if eskk#mappings#handle_special_lhs(char, key, a:stash)
            " Handled.
            return
        endif
    endfor


    " In order not to change current buftable old string.
    call eskk#lock_old_str()
    try
        " Handle special characters.
        " These characters are handled regardless of current phase.
        if eskk#mappings#is_special_lhs(char, 'backspace-key')
            call buftable.do_backspace(a:stash)
            return
        elseif eskk#mappings#is_special_lhs(char, 'enter-key')
            call buftable.do_enter(a:stash)
            return
        elseif eskk#mappings#is_special_lhs(char, 'sticky')
            call buftable.do_sticky(a:stash)
            return
        elseif char =~# '^[A-Z]$'
            if !eskk#mappings#is_special_lhs(
            \   char, 'phase:henkan-select:delete-from-dict'
            \)
                call buftable.do_sticky(a:stash)
                call eskk#register_temp_event(
                \   'filter-redispatch-post',
                \   'eskk#mappings#key2char',
                \   [eskk#mappings#get_filter_map(tolower(char))]
                \)
                return
            endif
        elseif eskk#mappings#is_special_lhs(char, 'escape-key')
            call buftable.do_escape(a:stash)
            return
        elseif eskk#mappings#is_special_lhs(char, 'tab')
            call buftable.do_tab(a:stash)
            return
        else
            " Fall through.
        endif
    finally
        call eskk#unlock_old_str()
    endtry


    " Handle other characters.
    if phase ==# g:eskk#buftable#HENKAN_PHASE_NORMAL
        return s:filter_rom(a:stash, self.table)
    elseif phase ==# g:eskk#buftable#HENKAN_PHASE_HENKAN
        if eskk#mappings#is_special_lhs(char, 'phase:henkan:henkan-key')
            call buftable.do_henkan(a:stash)
        else
            return s:filter_rom(a:stash, self.table)
        endif
    elseif phase ==# g:eskk#buftable#HENKAN_PHASE_OKURI
        if eskk#mappings#is_special_lhs(char, 'phase:okuri:henkan-key')
            call buftable.do_henkan(a:stash)
        else
            return s:filter_rom(a:stash, self.table)
        endif
    elseif phase ==# g:eskk#buftable#HENKAN_PHASE_HENKAN_SELECT
        if eskk#mappings#is_special_lhs(
        \   char, 'phase:henkan-select:choose-next'
        \)
            call buftable.choose_next_candidate(a:stash)
            return
        elseif eskk#mappings#is_special_lhs(
        \   char, 'phase:henkan-select:choose-prev'
        \)
            call buftable.choose_prev_candidate(a:stash)
            return
        elseif eskk#mappings#is_special_lhs(
        \   char, 'phase:henkan-select:delete-from-dict'
        \)
            let henkan_result = eskk#get_skk_dict().get_henkan_result()
            if !empty(henkan_result)
                call henkan_result.delete_from_dict()

                call buftable.push_kakutei_str(buftable.get_display_str(0))
                call buftable.set_henkan_phase(
                \   g:eskk#buftable#HENKAN_PHASE_NORMAL
                \)
            endif
        else
            call buftable.do_enter(a:stash)
            call eskk#register_temp_event(
            \   'filter-redispatch-post',
            \   'eskk#mappings#key2char',
            \   [eskk#mappings#get_filter_map(a:stash.char)]
            \)
        endif
    else
        throw eskk#internal_error(
        \   ['eskk'],
        \   "s:asym_filter.filter() does not support phase " . phase . "."
        \)
    endif
endfunction "}}}

function! s:filter_rom(stash, table) "{{{
    let char = a:stash.char
    let buftable = a:stash.buftable
    let buf_str = a:stash.buf_str
    let rom_str = buf_str.rom_str.get() . char
    let match_exactly  = a:table.has_map(rom_str)
    let candidates     = a:table.get_candidates(rom_str, 2, [])

    if match_exactly
        call eskk#error#assert(!empty(candidates))
    endif

    if match_exactly && len(candidates) == 1
        " Match!
        return s:filter_rom_exact_match(a:stash, a:table)

    elseif !empty(candidates)
        " Has candidates but not match.
        return s:filter_rom_has_candidates(a:stash)

    else
        " No candidates.
        return s:filter_rom_no_match(a:stash, a:table)
    endif
endfunction "}}}
function! s:filter_rom_exact_match(stash, table) "{{{
    let char = a:stash.char
    let buftable = a:stash.buftable
    let buf_str = a:stash.buf_str
    let rom_str = buf_str.rom_str.get() . char
    let phase = a:stash.phase

    if phase ==# g:eskk#buftable#HENKAN_PHASE_NORMAL
    \   || phase ==# g:eskk#buftable#HENKAN_PHASE_HENKAN
        " Set filtered string.
        call buf_str.rom_pairs.push_one_pair(rom_str, a:table.get_map(rom_str))
        call buf_str.rom_str.clear()


        " Set rest string.
        "
        " NOTE:
        " rest must not have multibyte string.
        " rest is for rom string.
        let rest = a:table.get_rest(rom_str, -1)
        " Assumption: 'a:table.has_map(rest)' returns false here.
        if rest !=# -1
            " XXX:
            "     eskk#mappings#get_filter_map(char)
            " should
            "     eskk#mappings#get_filter_map(eskk#util#uneval_key(char))
            for rest_char in split(rest, '\zs')
                call eskk#register_temp_event(
                \   'filter-redispatch-post',
                \   'eskk#mappings#key2char',
                \   [eskk#mappings#get_filter_map(rest_char)]
                \)
            endfor
        endif


        call eskk#register_temp_event(
        \   'filter-begin',
        \   eskk#util#get_local_func('clear_buffer_string', s:SID_PREFIX),
        \   [g:eskk#buftable#HENKAN_PHASE_NORMAL]
        \)

        if g:eskk#convert_at_exact_match
        \   && phase ==# g:eskk#buftable#HENKAN_PHASE_HENKAN
            let st = eskk#get_current_mode_structure()
            let henkan_buf_str = buftable.get_buf_str(
            \   g:eskk#buftable#HENKAN_PHASE_HENKAN
            \)
            if has_key(st.sandbox, 'real_matched_pairs')
                " Restore previous hiragana & push current to the tail.
                let p = henkan_buf_str.rom_pairs.pop()
                call henkan_buf_str.rom_pairs.set(
                \   st.sandbox.real_matched_pairs + [p]
                \)
            endif
            let st.sandbox.real_matched_pairs = henkan_buf_str.rom_pairs.get()

            call buftable.do_henkan(a:stash, 1)
        endif
    elseif phase ==# g:eskk#buftable#HENKAN_PHASE_OKURI
        " Enter phase henkan select with henkan.

        " XXX Write test and refactoring.
        "
        " Input: "SesSi"
        " Convert from:
        "   henkan buf str:
        "     filter str: "せ"
        "     rom str   : "s"
        "   okuri buf str:
        "     filter str: "し"
        "     rom str   : "si"
        " to:
        "   henkan buf str:
        "     filter str: "せっ"
        "     rom str   : ""
        "   okuri buf str:
        "     filter str: "し"
        "     rom str   : "si"
        " (http://d.hatena.ne.jp/tyru/20100320/eskk_rom_to_hira)
        let henkan_buf_str = buftable.get_buf_str(
        \   g:eskk#buftable#HENKAN_PHASE_HENKAN
        \)
        let okuri_buf_str = buftable.get_buf_str(
        \   g:eskk#buftable#HENKAN_PHASE_OKURI
        \)
        let henkan_select_buf_str = buftable.get_buf_str(
        \   g:eskk#buftable#HENKAN_PHASE_HENKAN_SELECT
        \)
        let henkan_rom = henkan_buf_str.rom_str.get()
        let okuri_rom  = okuri_buf_str.rom_str.get()
        if henkan_rom != '' && a:table.has_map(henkan_rom . okuri_rom[0])
            " Push "っ".
            let match_rom = henkan_rom . okuri_rom[0]
            call henkan_buf_str.rom_pairs.push_one_pair(
            \   match_rom,
            \   a:table.get_map(match_rom)
            \)
            " Push "s" to rom str.
            let rest = a:table.get_rest(henkan_rom . okuri_rom[0], -1)
            if rest !=# -1
                call okuri_buf_str.rom_str.set(
                \   rest . okuri_rom[1:]
                \)
            endif
        endif

        call eskk#error#assert(char != '')
        call okuri_buf_str.rom_str.append(char)

        let has_rest = 0
        if a:table.has_map(okuri_buf_str.rom_str.get())
            call okuri_buf_str.rom_pairs.push_one_pair(
            \   okuri_buf_str.rom_str.get(),
            \   a:table.get_map(okuri_buf_str.rom_str.get())
            \)
            let rest = a:table.get_rest(okuri_buf_str.rom_str.get(), -1)
            if rest !=# -1
                " XXX:
                "     eskk#mappings#get_filter_map(char)
                " should
                "     eskk#mappings#get_filter_map(eskk#util#uneval_key(char))
                for rest_char in split(rest, '\zs')
                    call eskk#register_temp_event(
                    \   'filter-redispatch-post',
                    \   'eskk#mappings#key2char',
                    \   [eskk#mappings#get_filter_map(rest_char)]
                    \)
                endfor
                let has_rest = 1
            endif
        endif

        call okuri_buf_str.rom_str.clear()

        let matched = okuri_buf_str.rom_pairs.get()
        call eskk#error#assert(!empty(matched))
        " TODO `len(matched) == 1`: Do henkan at only the first time.

        if !has_rest && g:eskk#auto_henkan_at_okuri_match
            call buftable.do_henkan(a:stash)
        endif
    endif
endfunction "}}}
function! s:filter_rom_has_candidates(stash) "{{{
    " NOTE: This will be run in all phases.
    call a:stash.buf_str.rom_str.append(a:stash.char)
endfunction "}}}
function! s:filter_rom_no_match(stash, table) "{{{
    let char = a:stash.char
    let buftable = a:stash.buftable
    let buf_str = a:stash.buf_str
    let rom_str_without_char = buf_str.rom_str.get()
    let rom_str = rom_str_without_char . char

    let [matched_map_list, rest] =
    \   s:get_matched_and_rest(a:table, rom_str, 1)
    if empty(matched_map_list)
        if g:eskk#rom_input_style ==# 'skk'
            if rest ==# char
                let a:stash.return = char
            else
                let rest = strpart(rest, 0, strlen(rest) - 2) . char
                call buf_str.rom_str.set(rest)
            endif
        else
            let [matched_map_list, head_no_match] =
            \   s:get_matched_and_rest(a:table, rom_str, 0)
            if empty(matched_map_list)
                call buf_str.rom_str.set(head_no_match)
            else
                for char in split(head_no_match, '\zs')
                    call buf_str.rom_pairs.push_one_pair(char, char)
                endfor
                for matched in matched_map_list
                    if a:table.has_rest(matched)
                        call eskk#register_temp_event(
                        \   'filter-redispatch-post',
                        \   'eskk#mappings#key2char',
                        \   [eskk#mappings#get_filter_map(
                        \       a:table.get_rest(matched)
                        \   )]
                        \)
                    endif
                    call buf_str.rom_pairs.push_one_pair(
                    \   matched, a:table.get_map(matched)
                    \)
                endfor
                call buf_str.rom_str.clear()
            endif
        endif
    else
        for matched in matched_map_list
            call buf_str.rom_pairs.push_one_pair(matched, a:table.get_map(matched))
        endfor
        call buf_str.rom_str.set(rest)
    endif
endfunction "}}}

function! s:generate_map_list(str, tail, ...) "{{{
    let str = a:str
    let result = a:0 != 0 ? a:1 : []
    " NOTE: `str` must come to empty string.
    if str == ''
        return result
    else
        call add(result, str)
        " a:tail is true, Delete tail one character.
        " a:tail is false, Delete first one character.
        return s:generate_map_list(
        \   (a:tail ? strpart(str, 0, strlen(str) - 1) : strpart(str, 1)),
        \   a:tail,
        \   result
        \)
    endif
endfunction "}}}
function! s:get_matched_and_rest(table, rom_str, tail) "{{{
    " For e.g., if table has map "n" to "ん" and "j" to none.
    " rom_str(a:tail is true): "nj" => [["ん"], "j"]
    " rom_str(a:tail is false): "nj" => [[], "nj"]

    let matched = []
    let rest = a:rom_str
    while 1
        let counter = 0
        let has_map_str = -1
        let list = s:generate_map_list(rest, a:tail)
        for str in list
            let counter += 1
            if a:table.has_map(str)
                let has_map_str = str
                break
            endif
        endfor
        if has_map_str ==# -1
            return [matched, rest]
        endif
        call add(matched, has_map_str)
        if a:tail
            " Delete first `has_map_str` bytes.
            let rest = strpart(rest, strlen(has_map_str))
        else
            " Delete last `has_map_str` bytes.
            let rest = strpart(rest, 0, strlen(rest) - strlen(has_map_str))
        endif
    endwhile
endfunction "}}}
" Clear filtered string when eskk#filter()'s finalizing.
function! s:clear_buffer_string(phase) "{{{
    let buftable = eskk#get_buftable()
    if buftable.get_henkan_phase() ==# a:phase
        let buf_str = buftable.get_current_buf_str()
        call buf_str.rom_pairs.clear()
    endif
endfunction "}}}

" }}}

" Initialization
function! eskk#_initialize() "{{{
    if s:is_initialized
        return
    endif

    " Create the first eskk instance. {{{
    call eskk#initialize_instance()
    " }}}

    " Create eskk augroup. {{{
    augroup eskk
        autocmd!
    augroup END
    " }}}

    " Create "eskk-initialize-pre" autocmd event. {{{
    " If no "User eskk-initialize-pre" events,
    " Vim complains like "No matching autocommands".
    autocmd eskk User eskk-initialize-pre :

    " Throw eskk-initialize-pre event.
    doautocmd User eskk-initialize-pre
    " }}}

    " Global Variables {{{

    " Debug
    if !exists('g:eskk#debug')
        let g:eskk#debug = 0
    endif

    if !exists('g:eskk#debug_wait_ms')
        let g:eskk#debug_wait_ms = 0
    endif

    if !exists('g:eskk#debug_out')
        let g:eskk#debug_out = "file"
    endif

    if !exists('g:eskk#directory')
        let g:eskk#directory = '~/.eskk'
    endif

    " Dictionary
    for [s:varname, s:default] in [
    \   ['g:eskk#dictionary', {
    \       'path': "~/.skk-jisyo",
    \       'sorted': 0,
    \       'encoding': 'utf-8',
    \   }],
    \   ['g:eskk#large_dictionary', {
    \       'path': "/usr/local/share/skk/SKK-JISYO.L",
    \       'sorted': 1,
    \       'encoding': 'euc-jp',
    \   }],
    \]
        if exists(s:varname)
            if type({s:varname}) == type("")
                let s:default.path = {s:varname}
                unlet {s:varname}
                let {s:varname} = s:default
            elseif type({s:varname}) == type({})
                call extend({s:varname}, s:default, "keep")
            else
                call eskk#util#warn(
                \   s:varname . "'s type is either String or Dictionary."
                \)
            endif
        else
            let {s:varname} = s:default
        endif
    endfor
    unlet! s:varname s:default

    if !exists("g:eskk#backup_dictionary")
        let g:eskk#backup_dictionary = g:eskk#dictionary.path . ".BAK"
    endif

    if !exists("g:eskk#auto_save_dictionary_at_exit")
        let g:eskk#auto_save_dictionary_at_exit = 1
    endif

    " Henkan
    if !exists("g:eskk#select_cand_keys")
      let g:eskk#select_cand_keys = "asdfjkl"
    endif

    if !exists("g:eskk#show_candidates_count")
      let g:eskk#show_candidates_count = 4
    endif

    if !exists("g:eskk#kata_convert_to_hira_at_henkan")
      let g:eskk#kata_convert_to_hira_at_henkan = 1
    endif

    if !exists("g:eskk#kata_convert_to_hira_at_completion")
      let g:eskk#kata_convert_to_hira_at_completion = 1
    endif

    if !exists("g:eskk#show_annotation")
      let g:eskk#show_annotation = 0
    endif

    " Mappings
    if !exists('g:eskk#mapped_keys')
        let g:eskk#mapped_keys = eskk#get_default_mapped_keys()
    endif

    " Mode
    if !exists('g:eskk#initial_mode')
        let g:eskk#initial_mode = 'hira'
    endif

    if !exists('g:eskk#statusline_mode_strings')
        let g:eskk#statusline_mode_strings =  {'hira': 'あ', 'kata': 'ア', 'ascii': 'aA', 'zenei': 'ａ', 'hankata': 'ｧｱ', 'abbrev': 'aあ'}
    endif

    function! s:set_up_mode_use_tables() "{{{
        " NOTE: "hira_to_kata" and "kata_to_hira" are not used.
        let default = {
        \   'hira': eskk#table#new_from_file('rom_to_hira'),
        \   'kata': eskk#table#new_from_file('rom_to_kata'),
        \   'zenei': eskk#table#new_from_file('rom_to_zenei'),
        \   'hankata': eskk#table#new_from_file('rom_to_hankata'),
        \}
        call extend(s:mode_vs_table, default, 'keep')
    endfunction "}}}
    call s:set_up_mode_use_tables()

    " Table
    if !exists('g:eskk#cache_table_map')
        let g:eskk#cache_table_map = 1
    endif

    if !exists('g:eskk#cache_table_candidates')
        let g:eskk#cache_table_candidates = 1
    endif

    " Markers
    if !exists("g:eskk#marker_henkan")
        let g:eskk#marker_henkan = '▽'
    endif

    if !exists("g:eskk#marker_okuri")
        let g:eskk#marker_okuri = '*'
    endif

    if !exists("g:eskk#marker_henkan_select")
        let g:eskk#marker_henkan_select = '▼'
    endif

    if !exists("g:eskk#marker_jisyo_touroku")
        let g:eskk#marker_jisyo_touroku = '?'
    endif

    if !exists("g:eskk#marker_popup")
        let g:eskk#marker_popup = '#'
    endif

    " Completion
    if !exists('g:eskk#enable_completion')
        let g:eskk#enable_completion = 1
    endif

    if !exists('g:eskk#max_candidates')
        let g:eskk#max_candidates = 30
    endif

    " Cursor color
    if !exists('g:eskk#use_color_cursor')
        let g:eskk#use_color_cursor = 1
    endif

    if !exists('g:eskk#cursor_color')
        " ascii: ivory4:#8b8b83, gray:#bebebe
        " hira: coral4:#8b3e2f, pink:#ffc0cb
        " kata: forestgreen:#228b22, green:#00ff00
        " abbrev: royalblue:#4169e1
        " zenei: gold:#ffd700
        let g:eskk#cursor_color = {
        \   'ascii': ['#8b8b83', '#bebebe'],
        \   'hira': ['#8b3e2f', '#ffc0cb'],
        \   'kata': ['#228b22', '#00ff00'],
        \   'abbrev': '#4169e1',
        \   'zenei': '#ffd700',
        \}
    endif

    " Misc.
    if !exists("g:eskk#egg_like_newline")
        let g:eskk#egg_like_newline = 0
    endif

    if !exists("g:eskk#keep_state")
        let g:eskk#keep_state = 0
    endif

    if !exists('g:eskk#keep_state_beyond_buffer')
        let g:eskk#keep_state_beyond_buffer = 0
    endif

    if !exists("g:eskk#revert_henkan_style")
        let g:eskk#revert_henkan_style = 'okuri'
    endif

    if !exists("g:eskk#delete_implies_kakutei")
        let g:eskk#delete_implies_kakutei = 0
    endif

    if !exists("g:eskk#rom_input_style")
        let g:eskk#rom_input_style = 'skk'
    endif

    if !exists("g:eskk#auto_henkan_at_okuri_match")
        let g:eskk#auto_henkan_at_okuri_match = 1
    endif

    if !exists("g:eskk#set_undo_point")
        let g:eskk#set_undo_point = {
        \   'sticky': 1,
        \   'kakutei': 1,
        \}
    endif

    if !exists("g:eskk#fix_extra_okuri")
        let g:eskk#fix_extra_okuri = 1
    endif

    if !exists('g:eskk#ignore_continuous_sticky')
        let g:eskk#ignore_continuous_sticky = 1
    endif

    if !exists('g:eskk#convert_at_exact_match')
        let g:eskk#convert_at_exact_match = 0
    endif

    " }}}

    " Set up g:eskk#directory. {{{
    function! s:initialize_set_up_eskk_directory()
        let dir = expand(g:eskk#directory)
        for d in [dir, eskk#util#join_path(dir, 'log')]
            if !isdirectory(d) && !eskk#util#mkdir_nothrow(d)
                call eskk#error#logf("can't create directory '%s'.", d)
            endif
        endfor
    endfunction
    call s:initialize_set_up_eskk_directory()
    " }}}

    " Egg-like-newline {{{
    function! s:do_lmap_non_egg_like_newline(do_map) "{{{
        if a:do_map
            if !eskk#mappings#has_temp_key('<CR>')
                call eskk#mappings#set_up_temp_key(
                \   '<CR>',
                \   '<Plug>(eskk:filter:<CR>)<Plug>(eskk:filter:<CR>)'
                \)
            endif
        else
            call eskk#register_temp_event(
            \   'filter-begin',
            \   'eskk#mappings#set_up_temp_key_restore',
            \   ['<CR>']
            \)
        endif
    endfunction "}}}
    if !g:eskk#egg_like_newline
        " Default behavior is `egg like newline`.
        " Turns it to `Non egg like newline` during henkan phase.
        call eskk#register_event(
        \   [
        \       'enter-phase-henkan',
        \       'enter-phase-okuri',
        \       'enter-phase-henkan-select'
        \   ],
        \   eskk#util#get_local_func(
        \       'do_lmap_non_egg_like_newline',
        \       s:SID_PREFIX
        \   ),
        \   [1]
        \)
        call eskk#register_event(
        \   'enter-phase-normal',
        \   eskk#util#get_local_func(
        \       'do_lmap_non_egg_like_newline',
        \       s:SID_PREFIX
        \   ),
        \   [0]
        \)
    endif
    " }}}

    " g:eskk#keep_state {{{
    if g:eskk#keep_state
        autocmd eskk InsertEnter * call eskk#mappings#save_state()
        autocmd eskk InsertLeave * call eskk#mappings#restore_state()
    else
        autocmd eskk InsertLeave * call eskk#disable()
    endif
    " }}}

    " Default mappings - :EskkMap {{{
    call eskk#commands#define()

    silent! EskkMap -type=sticky -unique ;
    silent! EskkMap -type=backspace-key -unique <C-h>
    silent! EskkMap -type=enter-key -unique <CR>
    silent! EskkMap -type=escape-key -unique <Esc>
    silent! EskkMap -type=undo-key -unique <C-g>u
    silent! EskkMap -type=tab -unique <Tab>

    silent! EskkMap -type=phase:henkan:henkan-key -unique <Space>

    silent! EskkMap -type=phase:okuri:henkan-key -unique <Space>

    silent! EskkMap -type=phase:henkan-select:choose-next -unique <Space>
    silent! EskkMap -type=phase:henkan-select:choose-prev -unique x

    silent! EskkMap -type=phase:henkan-select:next-page -unique <Space>
    silent! EskkMap -type=phase:henkan-select:prev-page -unique x

    silent! EskkMap -type=phase:henkan-select:escape -unique <C-g>

    silent! EskkMap -type=phase:henkan-select:delete-from-dict -unique X

    silent! EskkMap -type=mode:hira:toggle-hankata -unique <C-q>
    silent! EskkMap -type=mode:hira:ctrl-q-key -unique <C-q>
    silent! EskkMap -type=mode:hira:toggle-kata -unique q
    silent! EskkMap -type=mode:hira:q-key -unique q
    silent! EskkMap -type=mode:hira:l-key -unique l
    silent! EskkMap -type=mode:hira:to-ascii -unique l
    silent! EskkMap -type=mode:hira:to-zenei -unique L
    silent! EskkMap -type=mode:hira:to-abbrev -unique /

    silent! EskkMap -type=mode:kata:toggle-hankata -unique <C-q>
    silent! EskkMap -type=mode:kata:ctrl-q-key -unique <C-q>
    silent! EskkMap -type=mode:kata:toggle-kata -unique q
    silent! EskkMap -type=mode:kata:q-key -unique q
    silent! EskkMap -type=mode:kata:l-key -unique l
    silent! EskkMap -type=mode:kata:to-ascii -unique l
    silent! EskkMap -type=mode:kata:to-zenei -unique L
    silent! EskkMap -type=mode:kata:to-abbrev -unique /

    silent! EskkMap -type=mode:hankata:toggle-hankata -unique <C-q>
    silent! EskkMap -type=mode:hankata:ctrl-q-key -unique <C-q>
    silent! EskkMap -type=mode:hankata:toggle-kata -unique q
    silent! EskkMap -type=mode:hankata:q-key -unique q
    silent! EskkMap -type=mode:hankata:l-key -unique l
    silent! EskkMap -type=mode:hankata:to-ascii -unique l
    silent! EskkMap -type=mode:hankata:to-zenei -unique L
    silent! EskkMap -type=mode:hankata:to-abbrev -unique /

    silent! EskkMap -type=mode:ascii:to-hira -unique <C-j>

    silent! EskkMap -type=mode:zenei:to-hira -unique <C-j>

    silent! EskkMap -type=mode:abbrev:henkan-key -unique <Space>

    silent! EskkMap -remap -unique <C-^> <Plug>(eskk:toggle)

    silent! EskkMap -remap <BS> <Plug>(eskk:filter:<C-h>)

    silent! EskkMap -map-if="mode() ==# 'i'" -unique <Esc>
    silent! EskkMap -map-if="mode() ==# 'i'" -unique <C-c>
    " }}}

    " Map temporary key to keys to use in that mode {{{
    call eskk#register_event(
    \   'enter-mode',
    \   'eskk#mappings#map_mode_local_keys',
    \   []
    \)
    " }}}

    " Save dictionary if modified {{{
    if g:eskk#auto_save_dictionary_at_exit
        autocmd eskk VimLeavePre * EskkUpdateDictionary
    endif
    " }}}

    " Register builtin-modes. {{{
    function! s:initialize_builtin_modes()
        function! s:set_current_to_begin_pos() "{{{
            call eskk#get_buftable().set_begin_pos('.')
        endfunction "}}}


        " 'ascii' mode {{{
        call eskk#register_mode('ascii')
        let dict = eskk#get_mode_structure('ascii')

        function! dict.filter(stash)
            let this = eskk#get_mode_structure('ascii')
            if eskk#mappings#is_special_lhs(
            \   a:stash.char, 'mode:ascii:to-hira'
            \)
                call eskk#set_mode('hira')
            else
                if a:stash.char !=# "\<BS>"
                \   && a:stash.char !=# "\<C-h>"
                    if a:stash.char =~# '\w'
                        if !has_key(
                        \   this.sandbox, 'already_set_for_this_word'
                        \)
                            " Set start col of word.
                            call s:set_current_to_begin_pos()
                            let this.sandbox.already_set_for_this_word = 1
                        endif
                    else
                        if has_key(
                        \   this.sandbox, 'already_set_for_this_word'
                        \)
                            unlet this.sandbox.already_set_for_this_word
                        endif
                    endif
                endif

                if eskk#has_mode_table('ascii')
                    if !has_key(this.sandbox, 'table')
                        let this.sandbox.table = eskk#get_mode_table('ascii')
                    endif
                    let a:stash.return = this.sandbox.table.get_map(
                    \   a:stash.char, a:stash.char
                    \)
                else
                    let a:stash.return = a:stash.char
                endif
            endif
        endfunction

        call eskk#validate_mode_structure('ascii')
        " }}}

        " 'zenei' mode {{{
        call eskk#register_mode('zenei')
        let dict = eskk#get_mode_structure('zenei')

        function! dict.filter(stash)
            let this = eskk#get_mode_structure('zenei')
            if eskk#mappings#is_special_lhs(
            \   a:stash.char, 'mode:zenei:to-hira'
            \)
                call eskk#set_mode('hira')
            else
                if !has_key(this.sandbox, 'table')
                    let this.sandbox.table = eskk#get_mode_table('zenei')
                endif
                let a:stash.return = this.sandbox.table.get_map(
                \   a:stash.char, a:stash.char
                \)
            endif
        endfunction

        call eskk#register_event(
        \   'enter-mode-abbrev',
        \   eskk#util#get_local_func(
        \       'set_current_to_begin_pos',
        \       s:SID_PREFIX
        \   ),
        \   []
        \)

        call eskk#validate_mode_structure('zenei')
        " }}}

        " 'hira' mode {{{
        call eskk#register_mode('hira')
        let dict = eskk#get_mode_structure('hira')

        call extend(
        \   dict,
        \   eskk#create_asym_filter(eskk#get_mode_table('hira'))
        \)

        call eskk#validate_mode_structure('hira')
        " }}}

        " 'kata' mode {{{
        call eskk#register_mode('kata')
        let dict = eskk#get_mode_structure('kata')

        call extend(
        \   dict,
        \   eskk#create_asym_filter(eskk#get_mode_table('kata'))
        \)

        call eskk#validate_mode_structure('kata')
        " }}}

        " 'hankata' mode {{{
        call eskk#register_mode('hankata')
        let dict = eskk#get_mode_structure('hankata')

        call extend(
        \   dict,
        \   eskk#create_asym_filter(eskk#get_mode_table('hankata'))
        \)

        call eskk#validate_mode_structure('hankata')
        " }}}

        " 'abbrev' mode {{{
        call eskk#register_mode('abbrev')
        let dict = eskk#get_mode_structure('abbrev')

        function! dict.filter(stash) "{{{
            let char = a:stash.char
            let buftable = eskk#get_buftable()
            let this = eskk#get_mode_structure('abbrev')
            let buf_str = buftable.get_current_buf_str()
            let phase = buftable.get_henkan_phase()

            " Handle special characters.
            " These characters are handled regardless of current phase.
            if eskk#mappings#is_special_lhs(char, 'backspace-key')
                if buf_str.rom_str.get() == ''
                    " If backspace-key was pressed at empty string,
                    " leave abbrev mode.
                    " TODO: Back to previous mode?
                    call eskk#set_mode('hira')
                else
                    call buftable.do_backspace(a:stash)
                endif
                return
            elseif eskk#mappings#is_special_lhs(char, 'enter-key')
                call buftable.do_enter(a:stash)
                call eskk#set_mode('hira')
                return
            else
                " Fall through.
            endif

            " Handle other characters.
            if phase ==# g:eskk#buftable#HENKAN_PHASE_HENKAN
                if eskk#mappings#is_special_lhs(
                \   char, 'phase:henkan:henkan-key'
                \)
                    call buftable.do_henkan(a:stash)
                else
                    call buf_str.rom_str.append(char)
                endif
            elseif phase ==# g:eskk#buftable#HENKAN_PHASE_HENKAN_SELECT
                if eskk#mappings#is_special_lhs(
                \   char, 'phase:henkan-select:choose-next'
                \)
                    call buftable.choose_next_candidate(a:stash)
                    return
                elseif eskk#mappings#is_special_lhs(
                \   char, 'phase:henkan-select:choose-prev'
                \)
                    call buftable.choose_prev_candidate(a:stash)
                    return
                else
                    call buftable.push_kakutei_str(
                    \   buftable.get_display_str(0)
                    \)
                    call buftable.clear_all()
                    call eskk#register_temp_event(
                    \   'filter-redispatch-post',
                    \   'eskk#mappings#key2char',
                    \   [eskk#mappings#get_filter_map(a:stash.char)]
                    \)

                    " Leave abbrev mode.
                    " TODO: Back to previous mode?
                    call eskk#set_mode('hira')
                endif
            else
                throw eskk#internal_error(
                \   ['eskk'],
                \   "'abbrev' mode does not support phase " . phase . "."
                \)
            endif
        endfunction "}}}
        function! dict.get_init_phase() "{{{
            return g:eskk#buftable#HENKAN_PHASE_HENKAN
        endfunction "}}}
        function! dict.get_supported_phases() "{{{
            return [
            \   g:eskk#buftable#HENKAN_PHASE_HENKAN,
            \   g:eskk#buftable#HENKAN_PHASE_HENKAN_SELECT,
            \]
        endfunction "}}}

        call eskk#register_event(
        \   'enter-mode-abbrev',
        \   eskk#util#get_local_func(
        \       'set_current_to_begin_pos',
        \       s:SID_PREFIX
        \   ),
        \   []
        \)

        call eskk#validate_mode_structure('abbrev')
        " }}}
    endfunction
    call s:initialize_builtin_modes()
    " }}}

    " BufEnter: Map keys if enabled. {{{
    function! s:initialize_map_all_keys_if_enabled()
        if eskk#is_enabled()
            call eskk#mappings#map_all_keys()
        endif
    endfunction
    autocmd eskk BufEnter * call s:initialize_map_all_keys_if_enabled()
    " }}}

    " BufEnter: Restore global option value of &iminsert, &imsearch {{{
    function! s:restore_im_options() "{{{
        if empty(s:saved_im_options)
            return
        endif
        let [&g:iminsert, &g:imsearch] = s:saved_im_options
    endfunction "}}}

    if !g:eskk#keep_state_beyond_buffer
        autocmd eskk BufLeave * call s:restore_im_options()
    endif
    " }}}

    " InsertEnter: Clear buftable. {{{
    autocmd eskk InsertEnter * call eskk#get_buftable().reset()
    " }}}

    " InsertLeave: g:eskk#convert_at_exact_match {{{
    function! s:clear_real_matched_pairs() "{{{
        if !eskk#is_enabled() || eskk#get_mode() == ''
            return
        endif

        let st = eskk#get_current_mode_structure()
        if has_key(st.sandbox, 'real_matched_pairs')
            unlet st.sandbox.real_matched_pairs
        endif
    endfunction "}}}
    autocmd eskk InsertLeave * call s:clear_real_matched_pairs()
    " }}}

    " s:saved_im_options {{{
    call eskk#error#assert(empty(s:saved_im_options))
    let s:saved_im_options = [&g:iminsert, &g:imsearch]
    " }}}

    " Event: enter-mode {{{
    call eskk#register_event(
    \   'enter-mode',
    \   'eskk#set_cursor_color',
    \   []
    \)

    function! s:initialize_clear_buftable()
        let buftable = eskk#get_buftable()
        call buftable.clear_all()
    endfunction
    call eskk#register_event(
    \   'enter-mode',
    \   eskk#util#get_local_func(
    \       'initialize_clear_buftable',
    \       s:SID_PREFIX
    \   ),
    \   []
    \)

    function! s:initialize_set_henkan_phase()
        let buftable = eskk#get_buftable()
        call buftable.set_henkan_phase(
        \   (eskk#has_mode_func('get_init_phase') ?
        \       eskk#call_mode_func('get_init_phase', [], 0)
        \       : g:eskk#buftable#HENKAN_PHASE_NORMAL)
        \)
    endfunction
    call eskk#register_event(
    \   'enter-mode',
    \   eskk#util#get_local_func(
    \       'initialize_set_henkan_phase',
    \       s:SID_PREFIX
    \   ),
    \   []
    \)
    " }}}

    " InsertLeave: Restore &backspace value {{{
    " FIXME: Due to current implementation,
    " s:buftable.rewrite() assumes that &backspace contains "eol".
    if &l:backspace !~# '\<eol\>'
        let s:saved_backspace = &l:backspace
        setlocal backspace+=eol
        autocmd eskk InsertEnter * setlocal backspace+=eol
        autocmd eskk InsertLeave * if type(s:saved_backspace) == type("")
        \                       |      let &l:backspace = s:saved_backspace
        \                       | endif
    endif
    " }}}

    " Check some variables values. {{{
    function! s:initialize_check_variables()
        if g:eskk#marker_henkan ==# g:eskk#marker_popup
            call eskk#util#warn(
            \   'g:eskk#marker_henkan and g:eskk#marker_popup'
            \       . ' must be different.'
            \)
        endif
    endfunction
    call s:initialize_check_variables()
    " }}}

    " neocomplcache {{{
    function! s:initialize_neocomplcache()
        function! s:initialize_neocomplcache_unlock()
            if eskk#is_neocomplcache_locked()
                NeoComplCacheUnlock
            endif
            return ''
        endfunction
        call eskk#mappings#map(
        \   'e',
        \   '<Plug>(eskk:_neocomplcache_unlock)',
        \   eskk#util#get_local_func(
        \       'initialize_neocomplcache_unlock',
        \       s:SID_PREFIX
        \   ) . '()',
        \   eskk#mappings#get_map_modes() . 'n'
        \)
    endfunction
    call s:initialize_neocomplcache()
    " }}}

    " Completion {{{
    function! s:initialize_completion()
        call eskk#mappings#map(
        \   'e',
        \   '<Plug>(eskk:_do_complete)',
        \   'pumvisible() ? "" : "\<C-x>\<C-o>\<C-p>"'
        \)
    endfunction
    call s:initialize_completion()
    " }}}

    " Logging event {{{
    if g:eskk#debug
        " Should I create autoload/eskk/log.vim ?
        autocmd eskk VimLeavePre * call eskk#error#write_debug_log_file()
    endif
    " }}}

    " Create "eskk-initialize-post" autocmd event. {{{
    " If no "User eskk-initialize-post" events,
    " Vim complains like "No matching autocommands".
    autocmd eskk User eskk-initialize-post :

    " Throw eskk-initialize-post event.
    doautocmd User eskk-initialize-post
    " }}}

    let s:is_initialized = 1
endfunction "}}}
function! eskk#is_initialized() "{{{
    return s:is_initialized
endfunction "}}}

" Global variable function
function! eskk#get_default_mapped_keys() "{{{
    return split(
    \   'abcdefghijklmnopqrstuvwxyz'
    \  .'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    \  .'1234567890'
    \  .'!"#$%&''()'
    \  .',./;:]@[-^\'
    \  .'>?_+*}`{=~'
    \   ,
    \   '\zs'
    \) + [
    \   "<lt>",
    \   "<Bar>",
    \   "<Tab>",
    \   "<BS>",
    \   "<C-h>",
    \   "<CR>",
    \   "<Space>",
    \   "<C-q>",
    \   "<C-y>",
    \   "<C-e>",
    \   "<PageUp>",
    \   "<PageDown>",
    \   "<Up>",
    \   "<Down>",
    \   "<C-n>",
    \   "<C-p>",
    \]
endfunction "}}}

" Enable/Disable IM
function! eskk#is_enabled() "{{{
    return eskk#get_current_instance().enabled
endfunction "}}}
function! eskk#enable(...) "{{{
    let self = eskk#get_current_instance()
    let do_map = a:0 != 0 ? a:1 : 1

    if eskk#is_enabled()
        return ''
    endif

    if mode() ==# 'c'
        let &l:iminsert = 1
    endif

    call eskk#throw_event('enable-im')

    " Clear current variable states.
    let self.mode = ''
    call eskk#get_buftable().reset()

    " Set up Mappings.
    if do_map
        call eskk#mappings#map_all_keys()
    endif

    call eskk#set_mode(g:eskk#initial_mode)

    " If skk.vim exists and enabled, disable it.
    let disable_skk_vim = ''
    if exists('g:skk_version') && exists('b:skk_on') && b:skk_on
        let disable_skk_vim = substitute(SkkDisable(), "\<C-^>", '', '')
    endif

    if g:eskk#enable_completion
        let self.omnifunc_save = &l:omnifunc
        let &l:omnifunc = 'eskk#complete#eskkcomplete'
    endif

    let self.enabled = 1
    let self.enabled_mode = mode()

    if self.enabled_mode =~# '^[ic]$'
        return disable_skk_vim . "\<C-^>"
    else
        return s:enable_im()
    endif
endfunction "}}}
function! eskk#disable() "{{{
    let self = eskk#get_current_instance()
    let do_unmap = a:0 != 0 ? a:1 : 0

    if !eskk#is_enabled()
        return ''
    endif

    if mode() ==# 'c'
        return "\<C-^>"
    endif

    call eskk#throw_event('disable-im')

    if do_unmap
        call eskk#mappings#unmap_all_keys()
    endif

    if g:eskk#enable_completion && has_key(self, 'omnifunc_save')
        let &l:omnifunc = self.omnifunc_save
    endif

    if eskk#is_neocomplcache_locked()
        NeoComplCacheUnlock
    endif

    let self.enabled = 0

    if mode() =~# '^[ic]$'
        let buftable = eskk#get_buftable()
        return buftable.generate_kakutei_str() . "\<C-^>"
    else
        return s:disable_im()
    endif
endfunction "}}}
function! eskk#toggle() "{{{
    return eskk#{eskk#is_enabled() ? 'disable' : 'enable'}()
endfunction "}}}
function! s:enable_im() "{{{
    let &l:iminsert = eskk#mappings#map_exists('l') ? 1 : 2
    let &l:imsearch = &l:iminsert
    
    return ''
endfunction "}}}
function! s:disable_im() "{{{
    let &l:iminsert = 0
    let &l:imsearch = 0
    
    return ''
endfunction "}}}

" Mode
function! eskk#set_mode(next_mode) "{{{
    let self = eskk#get_current_instance()
    if !eskk#is_supported_mode(a:next_mode)
        call eskk#error#log(
        \   "mode '" . a:next_mode . "' is not supported."
        \)
        call eskk#error#log(
        \   's:available_modes = ' . string(s:available_modes)
        \)
        return
    endif

    call eskk#throw_event('leave-mode-' . self.mode)
    call eskk#throw_event('leave-mode')

    " Change mode.
    let prev_mode = self.mode
    let self.mode = a:next_mode

    call eskk#throw_event('enter-mode-' . self.mode)
    call eskk#throw_event('enter-mode')

    " For &statusline.
    redrawstatus
endfunction "}}}
function! eskk#get_mode() "{{{
    let self = eskk#get_current_instance()
    return self.mode
endfunction "}}}
function! eskk#is_supported_mode(mode) "{{{
    return has_key(s:available_modes, a:mode)
endfunction "}}}
function! eskk#register_mode(mode) "{{{
    let s:available_modes[a:mode] = extend(
    \   (a:0 ? a:1 : {}),
    \   {'sandbox': {}},
    \   'keep'
    \)
endfunction "}}}
function! eskk#validate_mode_structure(mode) "{{{
    " It should be recommended to call
    " this function at the end of mode register.

    let self = eskk#get_current_instance()
    let st = eskk#get_mode_structure(a:mode)

    for key in ['filter', 'sandbox']
        if !has_key(st, key)
            call eskk#util#warn(
            \   "eskk#register_mode(" . string(a:mode) . "): "
            \       . string(key) . " is not present in structure"
            \)
        endif
    endfor
endfunction "}}}
function! eskk#get_current_mode_structure() "{{{
    return eskk#get_mode_structure(eskk#get_mode())
endfunction "}}}
function! eskk#get_mode_structure(mode) "{{{
    let self = eskk#get_current_instance()
    if !eskk#is_supported_mode(a:mode)
        call eskk#util#warn(
        \   "mode '" . a:mode . "' is not available."
        \)
    endif
    return s:available_modes[a:mode]
endfunction "}}}
function! eskk#has_mode_func(func_key) "{{{
    let self = eskk#get_current_instance()
    let st = eskk#get_mode_structure(self.mode)
    return has_key(st, a:func_key)
endfunction "}}}
function! eskk#call_mode_func(func_key, args, required) "{{{
    let self = eskk#get_current_instance()
    let st = eskk#get_mode_structure(self.mode)
    if !has_key(st, a:func_key)
        if a:required
            let msg = printf()
            throw eskk#internal_error(
            \   ['eskk'],
            \   "Mode '" . self.mode . "' does not have"
            \       . " required function key"
            \)
        endif
        return
    endif
    return call(st[a:func_key], a:args, st)
endfunction "}}}

" Mode/Table
function! eskk#has_current_mode_table() "{{{
    return eskk#has_mode_table(eskk#get_mode())
endfunction "}}}
function! eskk#has_mode_table(mode) "{{{
    return has_key(s:mode_vs_table, a:mode)
endfunction "}}}
function! eskk#get_current_mode_table() "{{{
    return eskk#get_mode_table(eskk#get_mode())
endfunction "}}}
function! eskk#get_mode_table(mode) "{{{
    return s:mode_vs_table[a:mode]
endfunction "}}}

" Table
function! eskk#create_table(...) "{{{
    if has_key(s:cached_tables, a:table_name)
        return s:cached_tables[a:table_name]
    endif

    " Cache under s:cached_tables.
    let s:cached_tables[a:table_name] = call('eskk#table#new', a:000)
    return s:cached_tables[a:table_name]
endfunction "}}}
function! eskk#has_table(table_name) "{{{
    return has_key(s:table_defs, a:table_name)
endfunction "}}}
function! eskk#get_all_registered_tables() "{{{
    return keys(s:table_defs)
endfunction "}}}
function! eskk#get_table(name) "{{{
    return s:table_defs[a:name]
endfunction "}}}
function! eskk#register_table(table) "{{{
    for base in a:table.get_base_tables()
        call eskk#register_table(base)
    endfor
    " eskk#register_table() MUST NOT allow to overwrite
    " already registered tables.
    " because it is harmful to be able to
    " rewrite base (derived) tables. (what will happen? I don't know)
    let name = a:table.get_name()
    if !has_key(s:table_defs, name)
        let s:table_defs[name] = a:table
    endif
endfunction "}}}
function! eskk#register_mode_table(mode, table) "{{{
    call eskk#register_table(a:table)
    let s:mode_vs_table[a:mode] = a:table
endfunction "}}}

" Statusline
function! eskk#statusline(...) "{{{
    return eskk#is_enabled()
    \      ? printf(get(a:000, 0, '[eskk:%s]'),
    \               get(g:eskk#statusline_mode_strings,
    \                   eskk#get_current_instance().mode, '??'))
    \      : get(a:000, 1, '')
endfunction "}}}

" Dictionary
function! eskk#get_skk_dict() "{{{
    if empty(s:skk_dict)
        let s:skk_dict = eskk#dictionary#new(
        \   g:eskk#dictionary, g:eskk#large_dictionary
        \)
    endif
    return s:skk_dict
endfunction "}}}

" Buftable
function! eskk#get_buftable() "{{{
    let self = eskk#get_current_instance()
    if empty(self.buftable)
        let self.buftable = eskk#buftable#new()
    endif
    return self.buftable
endfunction "}}}
function! eskk#set_buftable(buftable) "{{{
    let self = eskk#get_current_instance()
    call a:buftable.set_old_str(
    \   empty(self.buftable) ? '' : self.buftable.get_old_str()
    \)
    let self.buftable = a:buftable
endfunction "}}}

" Event
function! eskk#register_event(event_names, Fn, head_args, ...) "{{{
    return s:register_event(
    \   s:event_hook_fn,
    \   a:event_names,
    \   a:Fn,
    \   a:head_args,
    \   (a:0 ? a:1 : -1)
    \)
endfunction "}}}
function! eskk#register_temp_event(event_names, Fn, head_args, ...) "{{{
    let self = eskk#get_current_instance()
    return s:register_event(
    \   self.temp_event_hook_fn,
    \   a:event_names,
    \   a:Fn,
    \   a:head_args,
    \   (a:0 ? a:1 : -1)
    \)
endfunction "}}}
function! s:register_event(st, event_names, Fn, head_args, self) "{{{
    let event_names = type(a:event_names) == type([]) ?
    \                   a:event_names : [a:event_names]
    for name in event_names
        if !has_key(a:st, name)
            let a:st[name] = []
        endif
        call add(
        \   a:st[name],
        \   [a:Fn, a:head_args]
        \       + (type(a:self) == type({}) ? [a:self] : [])
        \)
    endfor
endfunction "}}}
function! eskk#throw_event(event_name) "{{{
    let self = eskk#get_current_instance()
    let ret        = []
    let event      = get(s:event_hook_fn, a:event_name, [])
    let temp_event = get(self.temp_event_hook_fn, a:event_name, [])
    let all_events = event + temp_event
    if empty(all_events)
        return []
    endif

    while !empty(all_events)
        call add(ret, call('call', remove(all_events, 0)))
    endwhile

    " Clear temporary hooks.
    let self.temp_event_hook_fn[a:event_name] = []

    return ret
endfunction "}}}
function! eskk#has_event(event_name) "{{{
    let self = eskk#get_current_instance()
    return
    \   !empty(get(s:event_hook_fn, a:event_name, []))
    \   || !empty(get(self.temp_event_hook_fn, a:event_name, []))
endfunction "}}}

" Locking diff old string
function! eskk#lock_old_str() "{{{
    let self = eskk#get_current_instance()
    let self.is_locked_old_str = 1
endfunction "}}}
function! eskk#unlock_old_str() "{{{
    let self = eskk#get_current_instance()
    let self.is_locked_old_str = 0
endfunction "}}}

" Filter
function! eskk#filter(char) "{{{
    let self = eskk#get_current_instance()

    " Check irregular circumstance.
    if !eskk#is_supported_mode(self.mode)
        call eskk#error#write_error_log_file(
        \   a:char,
        \   eskk#error#build_error(
        \       ['eskk'],
        \       ['current mode is not supported: '
        \           . string(self.mode)]
        \   )
        \)
        return a:char
    endif


    call eskk#throw_event('filter-begin')

    let buftable = eskk#get_buftable()
    let stash = {
    \   'char': a:char,
    \   'return': 0,
    \
    \   'buftable': buftable,
    \   'phase': buftable.get_henkan_phase(),
    \   'buf_str': buftable.get_current_buf_str(),
    \   'mode': eskk#get_mode(),
    \}

    if !self.is_locked_old_str
        call buftable.set_old_str(buftable.get_display_str())
    endif

    try
        let do_filter = 1
        if eskk#complete#completing()
            try
                let do_filter = eskk#complete#handle_special_key(stash)
            catch
                call eskk#error#log_exception(
                \   'eskk#complete#handle_special_key()'
                \)
            endtry
        else
            let self.has_started_completion = 0
        endif

        if do_filter
            call eskk#call_mode_func('filter', [stash], 1)
        endif
        return s:rewrite_string(stash.return)

    catch
        call eskk#error#write_error_log_file(a:char)
        return a:char

    finally
        call eskk#throw_event('filter-finalize')
    endtry
endfunction "}}}
function! s:rewrite_string(return_string) "{{{
    let redispatch_pre = ''
    if eskk#has_event('filter-redispatch-pre')
        call eskk#mappings#map(
        \   'rbe',
        \   '<Plug>(eskk:_filter_redispatch_pre)',
        \   'join(eskk#throw_event("filter-redispatch-pre"), "")'
        \)
        let redispatch_pre =
        \   "\<Plug>(eskk:_filter_redispatch_pre)"
    endif

    let redispatch_post = ''
    if eskk#has_event('filter-redispatch-post')
        call eskk#mappings#map(
        \   'rbe',
        \   '<Plug>(eskk:_filter_redispatch_post)',
        \   'join(eskk#throw_event("filter-redispatch-post"), "")'
        \)
        let redispatch_post =
        \   "\<Plug>(eskk:_filter_redispatch_post)"
    endif

    let completion_enabled =
    \   g:eskk#enable_completion
    \   && exists('g:loaded_neocomplcache')
    \   && !neocomplcache#is_locked()
    if completion_enabled
        NeoComplCacheLock
    endif

    if type(a:return_string) == type("")
        call eskk#mappings#map(
        \   'be',
        \   '<Plug>(eskk:expr:_return_string)',
        \   eskk#util#make_ascii_expr(a:return_string)
        \)
        let string = "\<Plug>(eskk:expr:_return_string)"
    else
        let string = eskk#get_buftable().rewrite()
    endif
    return
    \   redispatch_pre
    \   . string
    \   . redispatch_post
    \   . (completion_enabled ?
    \       "\<Plug>(eskk:_neocomplcache_unlock)" .
    \           (eskk#complete#can_find_start() ?
    \               "\<Plug>(eskk:_do_complete)" :
    \               '') :
    \       '')
endfunction "}}}

" g:eskk#use_color_cursor
function! eskk#set_cursor_color() "{{{
    " From s:SkkSetCursorColor() of skk.vim

    if !has('gui_running') || !g:eskk#use_color_cursor
        return
    endif

    let eskk_mode = eskk#get_mode()
    if !has_key(g:eskk#cursor_color, eskk_mode)
        return
    endif

    let color = g:eskk#cursor_color[eskk_mode]
    if type(color) == type([]) && len(color) >= 2
        execute 'highlight lCursor guibg=' . color[&background ==# 'light' ? 0 : 1]
    elseif type(color) == type("") && color != ''
        execute 'highlight lCursor guibg=' . color
    endif
endfunction "}}}

" Mapping
function! eskk#_get_mapped_bufnr() "{{{
    return s:mapped_bufnr
endfunction "}}}
function! eskk#_get_eskk_mappings() "{{{
    return s:eskk_mappings
endfunction "}}}

" Misc.
function! eskk#is_neocomplcache_locked() "{{{
    return
    \   g:eskk#enable_completion
    \   && exists('g:loaded_neocomplcache')
    \   && exists(':NeoComplCacheUnlock')
    \   && neocomplcache#is_locked()
endfunction "}}}

" Exceptions
function! eskk#internal_error(from, ...) "{{{
    return eskk#error#build_error(a:from, ['internal error'] + a:000)
endfunction "}}}

call eskk#_initialize()



" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
