-- Luacheck configuration for lua-resty-ngxstats

-- Allow up to 140 character lines (from default 120)
std = "max+busted"

-- Define ngx as a global provided by OpenResty (not read-only)
globals = {
    "ngx",
}

-- Ignore unused argument warnings for function parameters starting with underscore
unused_args = false

-- Maximum line length
max_line_length = 140

-- Maximum code complexity
max_cyclomatic_complexity = 25
