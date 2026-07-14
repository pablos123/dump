-- wezterm_to_st_colors.lua
-- Export the 16 ANSI colors (0–15) for a set of popular WezTerm color schemes
-- into C arrays compatible with the st color table format you showed.
--
-- Usage:
--   wezterm start --config-file /path/to/wezterm_to_st_colors.lua
--
-- This will create a file named "wezterm_ansi_50.h" in your home directory
-- with one C array per scheme.

local wezterm = require 'wezterm'

-- 50 widely used/beloved schemes across Dracula, Catppuccin, Tokyo Night,
-- Solarized, Nord, Monokai/Material, Nightfox, Ayu, etc.
-- Names are matched flexibly (exact first, then case-insensitive contains).
local requested = {
  'Dracula (Official)', 'Dracula',
  'Catppuccin Mocha', 'Catppuccin Frappe', 'Catppuccin Macchiato', 'Catppuccin Latte',
  'Tokyo Night', 'Tokyo Night Day', 'Tokyo Night Storm',
  'One Dark', 'Nord',
  'Solarized Dark', 'Solarized Light',
  'Monokai Pro', 'Monokai Soda', 'Monokai',
  'Palenight', 'Oceanic Next',
  'Ayu Dark', 'Ayu Mirage', 'Ayu Light',
  'nightfox', 'duskfox', 'dawnfox', 'dayfox', 'nordfox', 'terafox', 'carbonfox',
  'Everforest Dark', 'Everforest Light',
  'Gruvbox Dark', 'Gruvbox Light',
  'Rosé Pine', 'Rosé Pine Moon', 'Rosé Pine Dawn',
  'Kanagawa', 'Kanagawa Dragon', 'Kanagawa Wave',
  'Material', 'Material Darker', 'Material Palenight',
  'Horizon Dark', 'Edge Dark', 'Edge Light',
  'Tomorrow Night', 'Tomorrow', 'PaperColor',
  '3024 Night', '3024 Day',
  'OneHalfDark', 'OneHalfLight', 'Cobalt2',
}

-- Resolve scheme names from builtin list with fuzzy matching.
local function build_index(schemes)
  local idx = {}
  for name, _ in pairs(schemes) do
    table.insert(idx, name)
  end
  table.sort(idx)
  return idx
end

local function lowercase(s)
  return (string.lower(s or ''))
end

local function find_scheme_name(preferred, available)
  -- exact first
  if available[preferred] then
    return preferred
  end
  -- case-insensitive exact
  for name, _ in pairs(available) do
    if lowercase(name) == lowercase(preferred) then
      return name
    end
  end
  -- contains-match (case-insensitive)
  local needle = lowercase(preferred)
  for name, _ in pairs(available) do
    if string.find(lowercase(name), needle, 1, true) then
      return name
    end
  end
  return nil
end

local function sanitize_hex(c)
  if not c then return '#000000' end
  if c:sub(1,1) ~= '#' then return '#' .. c end
  return c
end

local function to_identifier(name)
  local id = name:gsub('[^%w]+','_')
  id = id:gsub('_+', '_')
  id = id:gsub('^_', ''):gsub('_$', '')
  return id
end

local function compose_ansi16(scheme)
  -- builtin schemes tend to be either a table with top-level ansi/brights
  -- OR nested under a .colors table. Support both.
  local colors = scheme.colors or scheme
  local ansi = colors.ansi or {}
  local brights = colors.brights or {}

  -- Some schemes may have 16 in ansi; if so, prefer first 8 as normal and
  -- last 8 as brights. Otherwise, combine ansi (8) + brights (8).
  local out = {}
  if #ansi >= 16 and #brights == 0 then
    for i = 1, 8 do out[i] = sanitize_hex(ansi[i]) end
    for i = 9, 16 do out[i] = sanitize_hex(ansi[i]) end
  else
    for i = 1, 8 do out[i] = sanitize_hex(ansi[i]) end
    for i = 1, 8 do out[8+i] = sanitize_hex(brights[i]) end
  end

  -- Fallback fill if anything missing
  for i = 1, 16 do
    out[i] = sanitize_hex(out[i] or '#000000')
  end

  return out
end

local function render_c_array(name, ansi16)
  local id = to_identifier(name)
  local lines = {}
  table.insert(lines, string.format('/* %s */', name))
  table.insert(lines, 'static const char *colorname[] = {')
  table.insert(lines, '    /* 8 normal colors */')
  for i = 1, 8 do
    local comments = {
      [1] = ' /* black   */',
      [2] = ' /* red     */',
      [3] = ' /* green   */',
      [4] = ' /* yellow  */',
      [5] = ' /* blue    */',
      [6] = ' /* magenta */',
      [7] = ' /* cyan    */',
      [8] = ' /* white   */',
    }
    table.insert(lines, string.format('    [%d] = "%s",%s', i-1, ansi16[i], comments[i]))
  end
  table.insert(lines, '')
  table.insert(lines, '    /* 8 bright colors */')
  local comments_b = {
    [1] = ' /* black   */',
    [2] = ' /* red     */',
    [3] = ' /* green   */',
    [4] = ' /* yellow  */',
    [5] = ' /* blue    */',
    [6] = ' /* magenta */',
    [7] = ' /* cyan    */',
    [8] = ' /* white   */',
  }
  for i = 9, 16 do
    table.insert(lines, string.format('    [%d] = "%s",%s', i-1, ansi16[i], comments_b[i-8]))
  end
  table.insert(lines, '};\n')
  return table.concat(lines, '\n')
end

-- Main
local builtin = wezterm.get_builtin_color_schemes()
local available_index = build_index(builtin)

local out = {}
local count = 0
for _, want in ipairs(requested) do
  local resolved = find_scheme_name(want, builtin)
  if resolved then
    local scheme = builtin[resolved]
    local ansi16 = compose_ansi16(scheme)
    table.insert(out, render_c_array(resolved, ansi16))
    count = count + 1
  else
    table.insert(out, string.format('/* Skipped: %s (not found in this WezTerm build) */\n', want))
  end
end

local content = table.concat(out, '\n')

-- Write file to home dir
local target = (wezterm.home_dir or function() return os.getenv('HOME') or os.getenv('USERPROFILE') or '.' end)()
local path = target .. '/wezterm_ansi_50.h'
local f, err = io.open(path, 'w')
if not f then
  wezterm.log_error('Failed to write ' .. path .. ': ' .. tostring(err))
else
  f:write('/* Generated by wezterm_to_st_colors.lua */\n\n')
  f:write(content)
  f:close()
  wezterm.log_info('Wrote ' .. path .. ' with ' .. tostring(count) .. ' scheme(s).')
end

-- Auto-quit after writing (so it doesn't leave a window around)
if wezterm.gui then
  wezterm.on('gui-startup', function() wezterm.gui.quit() end)
end

-- Minimal config to keep wezterm happy if it needs a table return
local config = {}
return config
