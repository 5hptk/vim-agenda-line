" =============================================================================
" vim-agenda-line — your next calendar event, in the statusline.
" autoload/agendaline.vim  (core logic)
" =============================================================================
" Data source priority:
"   1. icalBuddy (real macOS Calendar)             if available
"   2. a plain-text agenda file  g:agendaline_file  (fallback / any OS)
"
" Public API:
"   agendaline#refresh()          -> re-read the source, update the cache
"   agendaline#text()             -> formatted string for the statusline
"   agendaline#is_live()          -> 1 if the cached event is in progress now
"   agendaline#event()            -> the cached event dict
"   agendaline#enable()           -> start timers + first refresh
"   agendaline#disable()          -> stop timers
" =============================================================================

let s:event = {'start': '', 'end': '', 'title': '', 'ppl': 0}
let s:timers = []

" --- small time helpers ------------------------------------------------------
function! s:mins(hhmm) abort
  return str2nr(a:hhmm[0:1]) * 60 + str2nr(a:hhmm[3:4])
endfunction

function! s:hhmm(mins) abort
  return printf('%02d:%02d', a:mins / 60, a:mins % 60)
endfunction

function! s:now() abort
  return s:mins(strftime('%H:%M'))
endfunction

" Compact human duration: 30 -> "30m", 60 -> "1h", 90 -> "1h30m".
function! s:dur(mins) abort
  if a:mins <= 0 | return '' | endif
  if a:mins < 60 | return a:mins . 'm' | endif
  let l:h = a:mins / 60
  let l:m = a:mins % 60
  return l:m == 0 ? l:h . 'h' : l:h . 'h' . l:m . 'm'
endfunction

let s:none = {'start': '', 'end': '', 'title': '', 'ppl': 0}

" --- source 1: icalBuddy -----------------------------------------------------
function! s:from_icalbuddy() abort
  if !executable('icalBuddy')
    return {}
  endif
  " One line per event, ':::' between properties (emails contain '@', so '@'
  " is unsafe as a separator):
  "   "HH:MM - HH:MM:::Title:::attendees: a@x, b@y, ..."
  let l:cmd = "icalBuddy -nc -nrd -b '' -ps '|:::|' "
        \ . "-iep 'datetime,title,attendees' -po 'datetime,title,attendees' "
        \ . "-df '' -tf '%H:%M' " . g:agendaline_icalbuddy_args . " 2>/dev/null"
  let l:raw = systemlist(l:cmd)
  if v:shell_error != 0 || empty(l:raw)
    return {}
  endif
  " Guard against misconfiguration: a bad subcommand makes icalBuddy print its
  " USAGE banner to stdout with exit 0. Don't treat that as "no events" —
  " fall through so the file fallback still works.
  if join(l:raw[0:2], ' ') =~# 'USAGE:\s*icalBuddy\|error:\s*No calendars'
    return {}
  endif
  let l:now = s:now()
  let l:matched_any = 0
  for l:line in l:raw
    let l:m = matchlist(l:line,
          \ '\(\d\{2}:\d\{2}\)\s*-\s*\(\d\{2}:\d\{2}\):::\(.\{-}\)\%(:::\(.*\)\)\?$')
    if empty(l:m) | continue | endif
    let l:matched_any = 1
    if s:mins(l:m[2]) <= l:now | continue | endif   " already ended
    let l:att = substitute(get(l:m, 4, ''), '^\s*attendees:\s*', '', '')
    let l:ppl = empty(trim(l:att)) ? 0 : len(split(l:att, ','))
    return {'start': l:m[1], 'end': l:m[2], 'title': trim(l:m[3]), 'ppl': l:ppl}
  endfor
  " Real event lines existed but all are in the past -> authoritative "none".
  " No event lines at all (e.g. only all-day items) -> fall through to file.
  return l:matched_any ? s:none : {}
endfunction

" --- source 2: plain-text agenda file ----------------------------------------
" Format per line:  HH:MM[-HH:MM]  Title [(N ppl)]
function! s:from_file() abort
  let l:path = expand(g:agendaline_file)
  if !filereadable(l:path)
    return s:none
  endif
  let l:now = s:now()
  for l:line in readfile(l:path)
    let l:m = matchlist(l:line,
          \ '^\s*\(\d\{2}:\d\{2}\)\%(\s*-\s*\(\d\{2}:\d\{2}\)\)\?\s\+\(.\{-}\)\s*$')
    if empty(l:m) | continue | endif
    let l:start = l:m[1]
    let l:end   = l:m[2]
    let l:rest  = l:m[3]
    let l:endmins = empty(l:end) ? s:mins(l:start) + g:agendaline_default_len
          \ : s:mins(l:end)
    if l:endmins <= l:now | continue | endif
    if empty(l:end) | let l:end = s:hhmm(l:endmins) | endif
    let l:ppl = 0
    let l:pm = matchlist(l:rest,
          \ '(\s*\(\d\+\)\s*\%(ppl\|people\|attendees\)\?\s*)\s*$')
    if !empty(l:pm)
      let l:ppl = str2nr(l:pm[1])
      let l:rest = substitute(l:rest, '\s*(\s*\d\+.\{-})\s*$', '', '')
    endif
    return {'start': l:start, 'end': l:end, 'title': trim(l:rest), 'ppl': l:ppl}
  endfor
  return s:none
endfunction

" --- refresh / accessors -----------------------------------------------------
function! agendaline#refresh(...) abort
  let l:e = s:from_icalbuddy()
  if empty(l:e)               " source unavailable -> fall back to file
    let l:e = s:from_file()
  endif
  let s:event = l:e
  if g:agendaline_auto_paint
    call agendaline#paint()
  endif
  return s:event
endfunction

function! agendaline#event() abort
  return s:event
endfunction

function! agendaline#is_live() abort
  if empty(s:event.start) | return 0 | endif
  let l:now = s:now()
  return s:mins(s:event.start) <= l:now && l:now < s:mins(s:event.end)
endfunction

" Formatted text for the statusline. Same string whether live or not — the
" caller distinguishes state via highlight (agendaline#is_live()).
"   START  <duration>  Title (N ppl)
" On narrow viewports (< g:agendaline_wide_cols) collapses to just START.
function! agendaline#text() abort
  let l:e = s:event
  if empty(l:e.start)
    return ''
  endif
  let l:pre = g:agendaline_prefix
  if &columns < g:agendaline_wide_cols
    return l:pre . l:e.start
  endif
  let l:title = l:e.title
  let l:max = g:agendaline_max_title
  if l:max > 0 && strchars(l:title) > l:max
    let l:title = strcharpart(l:title, 0, l:max - 1) . '…'
  endif
  let l:out = l:pre . l:e.start . ' ' . s:dur(s:mins(l:e.end) - s:mins(l:e.start))
        \ . ' ' . l:title
  if l:e.ppl > 0
    let l:out .= ' (' . l:e.ppl . ' ppl)'
  endif
  return l:out
endfunction

" --- highlighting ------------------------------------------------------------
" Define the two base groups (used by native statusline via %#Group#).
function! agendaline#define_highlights() abort
  execute 'highlight default AgendaLineNext ' . g:agendaline_hl_next
  execute 'highlight default AgendaLineLive ' . g:agendaline_hl_live
endfunction

" For lightline: re-link the segment's own highlight group to the live/next
" colors. g:agendaline_lightline_group must name the segment group, e.g.
" 'LightlineRight_active_2'. No-op if unset.
function! agendaline#paint(...) abort
  if empty(g:agendaline_lightline_group)
    return
  endif
  let l:src = agendaline#is_live() ? 'AgendaLineLive' : 'AgendaLineNext'
  execute 'highlight! link ' . g:agendaline_lightline_group . ' ' . l:src
endfunction

" Native-statusline component: text wrapped in its own %#..# highlight.
function! agendaline#statusline() abort
  let l:txt = agendaline#text()
  if empty(l:txt)
    return ''
  endif
  let l:grp = agendaline#is_live() ? 'AgendaLineLive' : 'AgendaLineNext'
  return '%#' . l:grp . '#' . l:txt . '%*'
endfunction

" --- timers ------------------------------------------------------------------
function! agendaline#enable() abort
  call agendaline#define_highlights()
  call agendaline#refresh()
  if has('timers')
    call add(s:timers, timer_start(g:agendaline_refresh_ms,
          \ function('agendaline#refresh'), {'repeat': -1}))
    " lighter tick to re-evaluate live-state + repaint + redraw
    call add(s:timers, timer_start(g:agendaline_tick_ms,
          \ {-> [agendaline#paint(), execute('redrawstatus!', 'silent!')]},
          \ {'repeat': -1}))
  endif
endfunction

function! agendaline#disable() abort
  for l:t in s:timers
    silent! call timer_stop(l:t)
  endfor
  let s:timers = []
endfunction
