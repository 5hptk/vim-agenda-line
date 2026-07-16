# vim-agenda-line

Your **next calendar event**, right in the statusline.

```
  19:00 30m Daily Standup (15 ppl)
```

- Reads real events from **macOS Calendar** via [`icalBuddy`](https://github.com/ali-rantakari/icalBuddy), or from a **plain-text agenda file** on any OS.
- Shows `START · duration · title · (N attendees)`.
- **Responsive:** collapses to just the start time on narrow windows.
- **Live events glow:** an in-progress event renders with a distinct highlight (green/black by default).
- Works with **[lightline](https://github.com/itchyny/lightline.vim)** or the **native `statusline`**.
- Refreshes on a timer; zero blocking on the UI.

## Requirements

- Vim 8+ (uses `+timers`; degrades gracefully without them).
- Optional: `icalBuddy` for real Calendar data — `brew install ical-buddy`.
  Without it, the plugin reads the fallback file (`g:agendaline_file`).

## Install

**vim-plug**

```vim
Plug '5hptk/vim-agenda-line'
```

**Manually**

```sh
git clone https://github.com/5hptk/vim-agenda-line \
  ~/.vim/pack/plugins/start/vim-agenda-line
```

## Usage

It autostarts. Add the component to your statusline:

### lightline

```vim
let g:lightline = {
  \ 'active': { 'right': [ ['lineinfo'], ['percent'], ['agenda'] ] },
  \ 'component_function': { 'agenda': 'agendaline#text' },
  \ }

" make in-progress events glow: point the plugin at the segment's hl group.
" (right-most group index 2 -> LightlineRight_active_2; adjust to your layout)
let g:agendaline_lightline_group = 'LightlineRight_active_2'
```

### native statusline

```vim
set statusline+=%{%agendaline#statusline()%}
```

`agendaline#statusline()` returns the text already wrapped in its own
highlight, so live events glow automatically.

## Plain-text agenda file

Used when `icalBuddy` is unavailable. Default: `~/.vim_calendar`.

```
# HH:MM[-HH:MM]  Title [(N ppl)]      end time & "(N ppl)" optional
09:30-09:45  Standup (8 ppl)
11:00-12:00  Design review (12 ppl)
17:00        Deploy window
```

## Configuration

| Variable | Default | Meaning |
|---|---|---|
| `g:agendaline_file` | `~/.vim_calendar` | fallback agenda file |
| `g:agendaline_icalbuddy_args` | `eventsToday` | args appended to `icalBuddy` |
| `g:agendaline_default_len` | `30` | assumed minutes when no end time |
| `g:agendaline_wide_cols` | `100` | below this width, show start time only |
| `g:agendaline_max_title` | `34` | truncate title to N chars (0 = never) |
| `g:agendaline_prefix` | `  ` | string prefixed to the component |
| `g:agendaline_refresh_ms` | `60000` | data refresh interval |
| `g:agendaline_tick_ms` | `30000` | live-state repaint interval |
| `g:agendaline_hl_next` | orange | `:highlight` args for upcoming events |
| `g:agendaline_hl_live` | green/black | `:highlight` args for in-progress events |
| `g:agendaline_lightline_group` | `''` | lightline segment hl group to recolor |
| `g:agendaline_autostart` | `1` | start timers on load |
| `g:agendaline_auto_paint` | `1` | repaint on refresh/events |

## Commands

- `:AgendaLineRefresh` — re-read the source now.
- `:AgendaLineEnable` / `:AgendaLineDisable` — start/stop the timers.
- `:AgendaLineEcho` — print the current component text.

## API

- `agendaline#text()` — formatted statusline string.
- `agendaline#statusline()` — text wrapped in its highlight (native).
- `agendaline#is_live()` — `1` if the cached event is in progress.
- `agendaline#event()` — the cached `{start,end,title,ppl}` dict.
- `agendaline#refresh()` — refresh the cache.

## License

MIT © 2026 5hptk
