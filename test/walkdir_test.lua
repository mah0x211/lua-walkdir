require('luacov')
local random = math.random
local testcase = require('testcase')
local assert = require('assert')
local mkdir = require('mkdir')
local walkdir = require('walkdir')

local FIRST_ENTRY
local ENTRIES = {}

local function copy_entries()
    local copy = {}
    for i = 1, #ENTRIES do
        copy[ENTRIES[i]] = ENTRIES[ENTRIES[i]]
    end
    return copy
end

function testcase.before_all()
    local paths = {
        '.',
    }
    local nfile = 1
    for _, entry in ipairs({
        'testdir',
        'foo',
        'bar',
        'baz',
        'qux',
    }) do
        -- create diretory
        paths[#paths + 1] = entry
        entry = table.concat(paths, '/')
        assert(mkdir(table.concat(paths, '/')))
        ENTRIES[#ENTRIES + 1] = entry
        ENTRIES[entry] = true

        -- create files
        local n = random(nfile, nfile + 10)
        for i = nfile, n do
            local filename = entry .. '/' .. i .. '.txt'
            local f = assert(io.open(filename, 'w'))
            f:write(filename .. '\n')
            f:close()
            ENTRIES[#ENTRIES + 1] = filename
            ENTRIES[filename] = false
        end
        nfile = n
    end

    FIRST_ENTRY = table.remove(ENTRIES, 1)
end

function testcase.after_all()
    for i = #ENTRIES, 1, -1 do
        local pathname = ENTRIES[i]
        -- remove files and directories
        assert(os.remove(pathname))
    end

    if FIRST_ENTRY then
        assert(os.remove(FIRST_ENTRY))
    end
end

function testcase.call_iterator_function()
    -- test that walkdir returns an iterator function and context
    local iter, ctx, initval = walkdir('./testdir')
    assert.is_func(iter)
    assert.is_table(ctx, {
        pathname = nil,
        follow_symlink = true,
        dirs = {
            './testdir',
        },
        dir = nil,
        error = nil,
    })
    assert.is_nil(initval)

    -- test that the iterator function returns entries in the directory
    local entries = copy_entries()
    local pathname, err, entry, is_dir = iter(ctx)
    while pathname do
        assert.is_string(pathname)
        assert.is_string(entry)
        assert.is_boolean(is_dir)
        assert.is_nil(err)
        -- confirm that the entry is last part of pathname
        assert.equal(pathname:match('([^/]+)$'), entry)

        -- confirm that the entry is in the expected entries
        assert.equal(entries[pathname], is_dir)
        entries[pathname] = nil

        -- get next entry
        pathname, err, entry, is_dir = iter(ctx)
    end

    -- confirm that there is no error
    assert.is_nil(err)
    assert.is_nil(is_dir)
    assert.is_nil(entry)

    -- confirm that all entries are returned
    assert.empty(entries)

end

function testcase.with_generic_for_loop()
    local entries = copy_entries()

    -- test that call walkdir with generic for loop
    for pathname, err, entry, is_dir in walkdir('./testdir') do
        assert.is_string(pathname)
        assert.is_nil(err)
        assert.is_string(entry)
        assert.is_boolean(is_dir)
        -- confirm that the entry is last part of pathname
        assert.equal(pathname:match('([^/]+)$'), entry)

        -- confirm that the entry is in the expected entries
        assert.equal(entries[pathname], is_dir)
        entries[pathname] = nil
    end

    -- assert that all entries are returned
    assert.empty(entries)
end

function testcase.with_walkerfn()
    local entries = copy_entries()

    -- test that walkdir with walker function
    local skipdir = './testdir/foo/bar/baz/qux'
    local err = walkdir('./testdir', true, function(pathname, entry, is_dir)
        assert.is_string(pathname)
        assert.is_string(entry)
        assert.is_boolean(is_dir)
        if pathname == skipdir then
            return true -- skip skipdir
        end
        -- remove pathname
        entries[pathname] = nil
    end)
    assert.is_nil(err)
    -- confirm that the skipped directory is exists
    for pathname in pairs(entries) do
        local basedir = string.sub(pathname, 1, #skipdir)
        assert.equal(basedir, skipdir)
    end

    -- test that the walkerfn returns an error
    err = walkdir('./testdir', true, function()
        return nil, 'error in walkerfn'
    end)
    assert.match(err, 'error in walkerfn')

    -- test that throws error when walkerfn is not a function
    err = assert.throws(walkdir, './testdir', true, 123)
    assert.match(err, 'walkerfn must be a function, got number')
end

function testcase.double_slashes_converted_to_single_slash()
    -- test that walkdir normalizes double slashes in pathname
    local iter, ctx = walkdir('./testdir//foo//bar')
    local pathname = iter(ctx)
    assert.re_match(pathname, '^./testdir/foo/bar/.+$')
end

function testcase.remove_last_slash_in_pathname()
    -- test that walkdir normalizes double slashes in pathname
    local iter, ctx = walkdir('./testdir/foo/bar/')
    local pathname = iter(ctx)
    assert.re_match(pathname, '^./testdir/foo/bar/[^/]+')
end

function testcase.pathname_that_does_not_exist()
    -- test that iterator returns nil when pathname does not exist
    local iter, ctx = walkdir('./unknown_dir')
    local pathname, err, entry, is_dir = iter(ctx)
    assert.is_nil(pathname)
    assert.is_nil(err)
    assert.is_nil(entry)
    assert.is_nil(is_dir)
end

function testcase.pathname_that_is_not_a_directory()
    -- test that iterator returns error when pathname is not a directory
    local iter, ctx = walkdir('./testdir/1.txt')
    local pathname, err, entry, is_dir = iter(ctx)
    assert.equal(pathname, '')
    assert.match(err, 'ENOTDIR')
    assert.is_nil(entry)
    assert.is_nil(is_dir)

    -- test that iterator returns only same error on subsequent calls
    for _ = 1, 3 do
        local err2
        pathname, err2, entry, is_dir = iter(ctx)
        assert.is_nil(pathname)
        assert.equal(err, err2)
        assert.is_nil(entry)
        assert.is_nil(is_dir)
    end
end

function testcase.throw_error_on_invalid_argument()
    -- test that throws error with no pathname argument
    local err = assert.throws(walkdir)
    assert.match(err, 'pathname must be a non-empty string, got nil')

    -- test that throws error with non-string pathname argument
    err = assert.throws(walkdir, 123)
    assert.match(err, 'pathname must be a non-empty string, got number')

    -- test that throws error with empty pathname argument
    err = assert.throws(walkdir, '')
    assert.match(err, 'pathname must be a non-empty string, got string')

    -- test that throws error with non-boolean follow_symlink argument
    err = assert.throws(walkdir, './testdir', 123)
    assert.match(err, 'follow_symlink must be a boolean, got number')
end
