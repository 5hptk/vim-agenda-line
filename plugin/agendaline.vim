" =============================================================================
" vim-agenda-line — your next calendar event, in the statusline.
" plugin/agendaline.vim  (bootstrap, config, commands)
" =============================================================================
if exists('g:loaded_agendaline') || &compatible
  finish
endif
let g:loaded_agendaline = 1

" --- configuration (override in your vimrc BEFORE the plugin loads, or just
"     set them any time and call :AgendaLineRefresh) ---------------------------

" Plain-text fallback agenda file (used when icalBuddy is unavailable).
let g:agendaline_file = get(g:, 'agendaline_file', '~/.vim_calendar')

" Extra args passed to icalBuddy (e.g. limit to some calendars).
let g:agendaline_icalbuddy_args =
      \ get(g:, 'agendaline_icalbuddy_args', 'eventsToday')

" Default event length (minutes) when the file omits an end time.
let g:agendaline_default_len = get(g:, 'agendaline_default_len', 30)

" Responsive threshold: below this many columns, show only the start time.
let g:agendaline_wide_cols = get(g:, 'agendaline_wide_cols', 100)

" Truncate the title to N chars (0 = never).
let g:agendaline_max_title = get(g:, 'agendaline_max_title', 34)

" String prefixed to the component (icon / spacing).
let g:agendaline_prefix = get(g:, 'agendaline_prefix', '  ')

" Refresh cadence (ms) and the lighter live/paint tick (ms).
let g:agendaline_refresh_ms = get(g:, 'agendaline_refresh_ms', 60000)
let g:agendaline_tick_ms    = get(g:, 'agendaline_tick_ms', 30000)

" Highlight definitions (args to :highlight). Upcoming vs in-progress.
let g:agendaline_hl_next = get(g:, 'agendaline_hl_next',
      \ 'guifg=#ffb454 guibg=#2a2a2a ctermfg=215 ctermbg=236')
let g:agendaline_hl_live = get(g:, 'agendaline_hl_live',
      \ 'guifg=#000000 guibg=#3fbf5f ctermfg=16 ctermbg=41 cterm=bold gui=bold')

" lightline segment group to recolor when live (empty = don't touch lightline).
let g:agendaline_lightline_group = get(g:, 'agendaline_lightline_group', '')

" Repaint automatically on refresh / relevant events.
let g:agendaline_auto_paint = get(g:, 'agendaline_auto_paint', 1)

" Start automatically on load.
let g:agendaline_autostart = get(g:, 'agendaline_autostart', 1)

" --- commands ----------------------------------------------------------------
command! AgendaLineRefresh call agendaline#refresh()
command! AgendaLineEnable  call agendaline#enable()
command! AgendaLineDisable call agendaline#disable()
command! AgendaLineEcho    echo agendaline#text()

" define highlight groups now so they always exist (even before enable())
call agendaline#define_highlights()

" --- keep highlights + paint alive ------------------------------------------
augroup agendaline
  autocmd!
  autocmd ColorScheme * call agendaline#define_highlights()
  if g:agendaline_auto_paint
    autocmd ColorScheme,BufEnter,WinEnter,InsertEnter,InsertLeave,CursorHold *
          \ call agendaline#paint()
  endif
augroup END

if g:agendaline_autostart
  " defer until fully started so lightline groups already exist
  if has('vim_starting')
    autocmd agendaline VimEnter * call agendaline#enable()
  else
    call agendaline#enable()
  endif
endif
