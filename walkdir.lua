--
-- Copyright (C) 2025 Masatoshi Fukunaga
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--
-- modules
local find = string.find
local gsub = string.gsub
local type = type
local fstat = require('fstat')
local opendir = require('opendir')
local fatalf = require('error.fatalf')
local errorf = require('error').format
local ENOENT = require('errno').ENOENT

--- check if a directory exists and is a directory
--- @param pathname string
--- @param follow_symlink boolean
--- @return boolean isdir
local function isdir(pathname, follow_symlink)
    -- check type of entry
    local stat = fstat(pathname, follow_symlink)
    return stat and stat.type == 'directory' or false
end

--- @class dir
--- @field readdir fun(self:dir):(entry:string?, err:any)
--- @field closedir fun(self:dir):(ok:boolean, err:any)

--- @class walkdir.context
--- @field dirs string[]
--- @field follow_symlink boolean
--- @field pathname string?
--- @field dir dir?
--- @field error any

--- open next directory
--- @param ctx walkdir.context
--- @return dir? dir
--- @return any err
local function open_next_dir(ctx)
    if ctx.dir then
        -- if the current directory is still open, return it
        return ctx.dir
    end

    -- get the next directory to walk
    ctx.pathname = ctx.dirs[#ctx.dirs]
    if not ctx.pathname then
        -- no more directories to walk
        return
    end
    ctx.dirs[#ctx.dirs] = nil

    -- open the directory
    local dir, err = opendir(ctx.pathname, ctx.follow_symlink)
    if dir then
        ctx.dir = dir
        return dir
    elseif err.type == ENOENT then
        -- if the directory does not exist, open next directory
        return open_next_dir(ctx)
    end
    -- if the directory cannot be opened with error other than ENOENT,
    -- store the error and return nil
    ctx.error = errorf('failed to opendir(%q)', ctx.pathname, err)
    return nil, ctx.error
end

local DOT_ENTRIES = {
    ['.'] = true,
    ['..'] = true,
}

--- read next entry from the current directory.
--- if an error occurs during traversal, the iterator returns an empty string
--- `''`, `nil`, `nil`, and the error object.
--- On subsequent calls, it consistently returns `nil`, `nil`, `nil`, and the
--- same error object.
--- @param ctx walkdir.context
--- @return string? pathname
--- @return string? entry
--- @return boolean? is_dir
--- @return any err
local function read_next_entry(ctx)
    if ctx.error then
        -- just return the error if it exists
        return nil, nil, nil, ctx.error
    end

    local dir, err = open_next_dir(ctx)
    if err then
        return '', nil, nil, err
    elseif not dir then
        return
    end

    local entry
    entry, err = dir:readdir()
    while entry do
        if not DOT_ENTRIES[entry] then
            local pathname = ctx.pathname .. '/' .. entry
            local is_dir = isdir(pathname, ctx.follow_symlink)
            if is_dir then
                ctx.dirs[#ctx.dirs + 1] = pathname
            end
            return pathname, entry, is_dir
        end
        entry, err = dir:readdir()
    end

    if err then
        -- if readdir failed with error
        ctx.error = errorf('failed to readdir(%s)', ctx.pathname, err)
        return '', nil, nil, ctx.error
    end

    -- close it and open next directory
    dir:closedir()
    ctx.dir = nil
    return read_next_entry(ctx)
end

--- walk directory recursively
--- @param pathname string
--- @param follow_symlink boolean?
--- @return fun(ctx:walkdir.context):(string?, any)
--- @return walkdir.context
local function walkdir(pathname, follow_symlink)
    if type(pathname) ~= 'string' or find(pathname, '^%s*$') then
        fatalf(2, 'pathname must be a non-empty string, got %s', type(pathname))
    elseif follow_symlink ~= nil and type(follow_symlink) ~= 'boolean' then
        fatalf(2, 'follow_symlink must be a boolean, got %s',
               type(follow_symlink))
    end

    -- remove double slashes and trailing slashes
    pathname = gsub(pathname, '/+', '/')
    if #pathname > 1 and pathname:sub(-1) == '/' then
        pathname = pathname:sub(1, -2)
    end

    -- return iterator function and context
    return read_next_entry, {
        dirs = {
            pathname,
        },
        follow_symlink = follow_symlink == true,
    }
end

return walkdir
