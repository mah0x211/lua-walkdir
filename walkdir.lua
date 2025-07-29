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

--- @alias fstat.stat table
--- @alias fstat fun(pathname:string, follow_symlink:boolean):(stat:fstat.stat, err:any)

--- check if a directory exists and is a directory
--- @param pathname string
--- @param follow_symlink boolean
--- @return boolean isdir
--- @return fstat.stat?
local function isdir(pathname, follow_symlink)
    -- check type of entry
    local stat, err = fstat(pathname, follow_symlink)
    if stat then
        return stat.type == 'directory', stat
    end
    return false, {
        error = err,
    }
end

--- @class dir
--- @field readdir fun(self:dir):(entry:string?, err:any)
--- @field closedir fun(self:dir):(ok:boolean, err:any)

--- @class walkdir.context
--- @field dirs string[]
--- @field depths integer[]
--- @field follow_symlink boolean
--- @field pathname string?
--- @field depth integer?
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
    ctx.depth = ctx.depths[#ctx.depths]
    ctx.pathname = ctx.dirs[#ctx.dirs]
    if not ctx.pathname then
        -- no more directories to walk
        return
    end
    ctx.dirs[#ctx.dirs] = nil
    ctx.depths[#ctx.depths] = nil

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
--- `''`, `nil`, `nil`, `nil` and the error object.
--- On subsequent calls, it consistently returns `nil`, `nil`, `nil`, `nil` and
--- the same error object.
--- @param ctx walkdir.context
--- @return string? pathname
--- @return any err
--- @return string? entry
--- @return boolean? is_dir
--- @return integer? depth
--- @return fstat.stat? stat
local function read_next_entry(ctx)
    if ctx.error then
        -- just return the error if it exists
        return nil, ctx.error
    end

    local dir, err = open_next_dir(ctx)
    if err then
        return '', err
    elseif not dir then
        return
    end

    local pathname = ctx.pathname
    local follow_symlink = ctx.follow_symlink
    local dirs = ctx.dirs
    local depths = ctx.depths
    local depth = ctx.depth
    local entry
    entry, err = dir:readdir()
    while entry do
        if not DOT_ENTRIES[entry] then
            local path = pathname .. '/' .. entry
            local is_dir, stat = isdir(path, follow_symlink)
            if is_dir then
                -- if the entry is a directory, add it to the stack
                dirs[#dirs + 1] = path
                depths[#depths + 1] = depth + 1
            end
            return path, nil, entry, is_dir, depth, stat
        end
        entry, err = dir:readdir()
    end

    if err then
        -- if readdir failed with error
        ctx.error = errorf('failed to readdir(%s)', ctx.pathname, err)
        return '', ctx.error
    end

    -- close it and open next directory
    dir:closedir()
    ctx.dir = nil
    return read_next_entry(ctx)
end

--- Callback function for each directory entry.
--- If the callback returns `false` when `isdir` is `true`, the directory
--- will not be traversed further.
--- @alias walkdir.walkerfn fun(pathname:string, entry:string, isdir:boolean, depth:integer, stat:fstat.stat?):(skipdir:boolean, err:any)

--- walk directory with a walker function
--- @param ctx walkdir.context
--- @param walkerfn walkdir.walkerfn
--- @return any err
local function walkdir_with_walkerfn(ctx, walkerfn)
    -- create a context with the walker
    local dirs = ctx.dirs
    local depths = ctx.depths
    local pathname, err, entry, is_dir, depth, stat = read_next_entry(ctx)
    while pathname do
        if err then
            -- if an error occurred, return it
            return err
        end

        -- call the walker function with the current entry
        local skipdir
        ---@diagnostic disable-next-line: param-type-mismatch
        skipdir, err = walkerfn(pathname, entry, is_dir, depth, stat)
        if err then
            -- if the walker function returns an error, return it
            return errorf('walkerfn failed for %s', pathname, err)
        end

        -- if the walker function returns false for a directory,
        -- do not traverse it further and remove it from the stack
        if is_dir and skipdir == true then
            dirs[#dirs] = nil
            depths[#depths] = nil
        end

        -- read next entry
        pathname, err, entry, is_dir, depth, stat = read_next_entry(ctx)
    end

    return err
end

--- @alias walkdir.iterator fun(ctx:walkdir.context):(pathname:string?, err:any, entry:string?, isdir:boolean?, depth:integer?, fstat:fstat.stat?)

--- walk directory recursively
--- @param pathname string
--- @param follow_symlink boolean?
--- @param walkerfn walkdir.walkerfn?
--- @return walkdir.iterator|any
--- @return walkdir.context?
local function walkdir(pathname, follow_symlink, walkerfn)
    if type(pathname) ~= 'string' or find(pathname, '^%s*$') then
        fatalf(2, 'pathname must be a non-empty string, got %s', type(pathname))
    elseif follow_symlink ~= nil and type(follow_symlink) ~= 'boolean' then
        fatalf(2, 'follow_symlink must be a boolean, got %s',
               type(follow_symlink))
    elseif walkerfn ~= nil and type(walkerfn) ~= 'function' then
        fatalf(2, 'walkerfn must be a function, got %s', type(walkerfn))
    end

    -- remove double slashes and trailing slashes
    pathname = gsub(pathname, '/+', '/')
    if #pathname > 1 and pathname:sub(-1) == '/' then
        pathname = pathname:sub(1, -2)
    end

    -- create context
    local ctx = {
        dirs = {
            pathname,
        },
        depths = {
            1,
        },
        follow_symlink = follow_symlink == true,
    }

    if walkerfn then
        -- if walkerfn is provided, use it to callback for each entry, and
        -- return the error of walkdir_with_walker function
        return walkdir_with_walkerfn(ctx, walkerfn)
    end
    -- return iterator function and context
    return read_next_entry, ctx
end

return walkdir
