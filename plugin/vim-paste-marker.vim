" if exists('g:loaded_paste_marker') || &cp || version < 700
    " finish
" endif
" let g:loaded_paste_marker = 1

if v:version < 700
	echoerr "PasteMarker: this plugin requires vim >= 7!"
	finish
endif

let PasteMarker_version = "0.1.1"

let s:old_cpo = &cpo
set cpo&vim

"========================================
" Methods:
"========================================
" Mark's instance methods
"----------------------------------------
let s:m = {}
fun! s:m.init()
  let self.sign_name = "PasteMarker_" . self.mark_text
  " execute "sign define ".self.sign_name." text=". self.mark_text ."  linehl=Underlined texthl=LineNr"
  execute "highlight! link " . self.sign_name . " PasteMarkerBase"
  execute "sign define ". self.sign_name ." text=++ texthl=".self.sign_name
endfun

fun! s:m.update(buff_num, line)
  if self.marked_buf != -1
    execute "sign unplace ".self.place_id." buffer=".self.marked_buf
  endif
  call self.set_mark(a:buff_num, a:line)
endfun

fun! s:m.set_mark(buff_num, line)
  let self.marked_buf = a:buff_num
  execute "sign place ".self.place_id." line=".a:line." name=".self.sign_name." buffer=".a:buff_num
endfun

fun! s:m.jump()
  if self.marked_buf != -1
    execute "sign jump ".self.place_id." buffer=".self.marked_buf
  endif
  return self
endfun

fun! s:m.clear()
  if self.marked_buf != -1
    execute "sign unplace ".self.place_id." buffer=".self.marked_buf
  endif
endfun

fun! s:m.mark()
  call self.update(bufnr("%"),line('.'))
endfun

fun! s:m.set_hl(hlname)
  execute "highlight!  link ". self.sign_name . " " . a:hlname
endfun

fun! s:Marker(mark_text)
  let obj = {
        \ 'place_id': 0,
        \ 'marked_buf': -1,
        \ 'mark_text': a:mark_text,
        \ 'sign_name': ""
        \  }
  call extend(obj, s:m, 'error')
  call obj.init()
  return obj
endfun

"==========================
" Include
"==========================
let s:MarkerManager = {}

fun! s:MarkerManager.init()
  let self.marks = {}
  let g:PasteMarkerSize = exists("g:PasteMarkerSize") ? g:PasteMarkerSize : 1
  let self.next_mark_index = 0
  let self.next_jump_index = 0

  fun! self.mark_store()
    return range(1, g:PasteMarkerSize)
  endfun

  fun! self.next_mark_sign()
    let mark_sign = self.mark_store()[self.next_mark_index]
    let self.next_mark_index += 1
    if self.next_mark_index == len(self.mark_store())
      let self.next_mark_index = 0
    endif
    return mark_sign
  endfun

  fun! self.put_mark()
    call self.get(self.next_mark_sign()).mark()
    call self.update_hl()
  endfun

  fun! self.update_hl()
    let target_list = self.target_list()
    let mark_text = target_list[self.next_jump_index]

    for [key, mark] in items(self.marks)
      let hl_suffix = (key == mark_text) ? "Target" : "Base"
      call mark.set_hl("PasteMarker".hl_suffix)
    endfor
  endfun

  fun! self.get_target()
    let target_list = self.target_list()
    let mark_text = target_list[self.next_jump_index]
    return self.marks[mark_text]
  endfun

  fun! self.is_mark_exist()
    return len(self.marks)
  endfun
  
  fun! self.next_target()
    if !(self.is_mark_exist())
      return
    endif

    let self.next_jump_index += 1
    if self.next_jump_index == len(self.target_list())
      let self.next_jump_index = 0
    endif

    call self.update_hl()

    let fun = { 'target': self.get_target() }
    fun! fun.call()
      call self.target.jump()
      redraw!
      sleep 300m
      echo getline('.')
      redraw!
    endfun
    call self.save_excursion(fun)
  endfun

  fun! self.target_list()
    return sort(keys(self.marks))
  endfun

  fun! self.jump_to_target()
    let mark = self.get_target().jump()
    if len(mark)
      call mark.jump()
      return 1
    else
      return 0
    endif
  endfun

  fun! self.create(mark_text)
    let marker = s:Marker(a:mark_text)
    let marker.place_id = len(self.marks) + 1
    let self.marks[a:mark_text] = marker
    return marker
  endfun

  fun! self.get(mark_text)
    if !has_key(self.marks, a:mark_text)
      call self.create(a:mark_text)
    end
    return self.marks[a:mark_text]
  endfun

  fun! self.clear(mark_text)
    call self.get(a:mark_text).clear()
  endfun

  fun! self.clear_all()
    for mark in values(self.marks)
      call mark.clear()
    endfor
    let self.marks = {}
    let self.next_mark_index = 0
    let self.next_jump_index = 0
  endfun

  fun! self.save_excursion(fun)
    normal mz
    " let win_saved = winsaveview()
    let org_win = winnr()
    let org_buf = bufnr('%')

    try
      let result = a:fun.call()
    finally
      if (winnr() != org_win)| execute org_win . "wincmd p"  | endif
      if (bufnr('%') != org_buf)| edit #| endif
      " call winrestview(win_saved)
      normal `z
    endtry

    return result
  endfun

  fun! self.paste_next(dont_return)
    if ! len(self.marks)
      return
    endif
    
    let fun = {}
    fun! fun.call()
      if g:Pm.jump_to_target()
        execute "normal o\<Esc>p`[V`]"
        redraw!
        sleep 200m
        execute "normal \<Esc>o\<Esc>"
      else
        return 0
      endif
    endfun

    if a:dont_return
      call fun.call()
    else
      call self.save_excursion(fun)
    endif
  endfun

  return self
endfun

"==========================
" Main:
"==========================
let  Pm = s:MarkerManager.init()
" fun! Pm(mark_text)
  " return g:Pm.get(a:mark_text)
" endfun

highlight! link PasteMarkerBase   None
highlight! link PasteMarkerTarget Todo

"==========================
" Test:
"==========================
fun! s:setup_default_keymap()
  " put mark
  nnoremap <D-p> :call Pm.put_mark()<CR>
  nnoremap <D-M> :call Pm.next_target()<CR>
  vnoremap <D-M> :<C-u>call Pm.next_target()<CR>gv

  " move target mark
  vnoremap <D-P> :<C-u>call Pm.next_target()<CR>gv

  " paste with jump
  vnoremap <D-p>   y:call Pm.paste_next(1)<CR>:call Pm.clear_all()<CR>

  " paste without jump
  vnoremap <D-P>  y:call Pm.paste_next(0)<CR>

  " clear all mark
  nnoremap <D-D> :call  Pm.clear_all()<CR>

  command! -nargs=0 PasteMarkerClearAll  :call Pm.clear_all()
  " command! -nargs=0 PasteMarkerPasteNext :call Pm.paste_next()
  " command! -nargs=0 PasteMarkerPutMark   :call Pm.put_mark()
  
  sign unplace *
endfun

call s:setup_default_keymap()

"reset &cpo back to users setting
let &cpo = s:old_cpo
