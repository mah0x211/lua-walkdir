# lua-walkdir

[![test](https://github.com/mah0x211/lua-walkdir/actions/workflows/test.yml/badge.svg)](https://github.com/mah0x211/lua-walkdir/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/mah0x211/lua-walkdir/branch/master/graph/badge.svg)](https://codecov.io/gh/mah0x211/lua-walkdir)

walkdir is a Lua module for traversing directories.


## Installation

```
luarocks install walkdir
```

## Usage

```lua
local walkdir = require('walkdir')
-- traverse a /tmp directory and print each entry
for pathname, err, entry, isdir in walkdir('/tmp', true) do
    print(pathname, err, entry, isdir)
end
```

## Error Handling

the following functions return the `error` object created by https://github.com/mah0x211/lua-errno module.


## ... = walkdir( pathname [, follow_symlink [, walkerfn [, toctou]]] )

When `walkerfn` is provided, `walkdir` traverses immediately and uses callback style. When `walkerfn` is omitted, `walkdir` returns an iterator and context.

**Parameters**

- `pathname:string`: the directory to traverse.
- `follow_symlink:boolean`: follow symbolic links. (default: `false`)
- `walkerfn:function`: a function that will be called for each entry in the directory.
- `toctou:boolean`: if `true`, use `openat(2)` for each path segment to prevent TOCTOU (time-of-check/time-of-use) race conditions. When combined with `follow_symlink=false`, symbolic links at **any** position in the path (not just the final component) are rejected with `ENOTDIR`. (default: `false`)

**Returns**

- `...`: Return values depend on whether walkerfn is provided. See below for details.


### Callback style

```lua
err = walkdir(pathname [, follow_symlink], walkerfn [, toctou])
```

Use this form when you want `walkdir` to traverse immediately and call `walkerfn` for each entry.

`walkerfn:function`: a function that will be called for each entry in the directory.

```
walkerfn(pathname:string, entry:string, isdir:boolean, depth:integer, stat:table):(skipdir:boolean, err:any)

Parameters:
* pathname  : the entry's pathname.
* entry     : the entry's name.
* isdir     : whether the entry is a directory.
* depth     : the depth of the entry in the directory tree, starting from 1
                for the root directory and incrementing for each subdirectory.
* stat      : a table containing file status information (e.g., size,
                modification time). if fail to get the file stat, it contains
                an `error` field with the error object.

Returns:
* skipdir   : If `true`, the directory will not be traversed further,
                otherwise it will be traversed.
* err       : an error object if an error occurred during traversal. If an
                error returned, the traversal will stop and the error will be
                returned by the `walkdir` function.
```

**Returns**

- `err:any`: an error object if an error occurred during traversal. If no error occurred, it returns `nil`.

**Example**

```lua
local walkdir = require('walkdir')

local err = walkdir('/tmp', true, function(pathname, entry, isdir, depth, stat)
    print(pathname, entry, isdir, depth, stat)
    if isdir and depth == 2 then
        return true
    end
end, true)

if err then
    print('Error:', err)
end
```

### Iterator style

```lua
iter, ctx = walkdir(pathname [, follow_symlink])
iter, ctx = walkdir(pathname [, follow_symlink], nil, toctou)
```

Use this form when you want an iterator and context object.

> **Note:** To use `toctou` with the iterator form, pass `nil` as the `walkerfn` placeholder:
>
> ```lua
> local iter, ctx = walkdir('/tmp', false, nil, true)
> ```

**Returns**

- `iter:function`: an iterator function that returns the next entry in the directory.
    ```
    pathname:string, err:any, entry:string, isdir:boolean, depth:integer, stat:table = iter(ctx:table)

    * pathname  : the entry's pathname.
    * err       : an error object if an error occurred during traversal.
    * entry     : the entry's name.
    * isdir     : whether the entry is a directory.
    * depth     : the depth of the entry in the directory tree, starting from 1
                  for the root directory and incrementing for each subdirectory.
    * stat      : a table containing file status information (e.g., size,
                  modification time). if fail to get the file stat, it contains
                  an `error` field with the error object.
    ```
    - **NOTE:** if an error occurs during traversal, the iterator returns an
                empty string `''` and the error object. On subsequent calls,
                it consistently returns `nil` and the same error object.
- `ctx:table`: a context table that contains the following fields:
    - `pathname:string`: the current pathname of the directory being traversed.
    - `depth:integer`: the current depth in the directory tree, starting from 1 for the root directory and incrementing for each subdirectory.
    - `follow_symlink:boolean`: whether symbolic links are followed.
    - `toctou:boolean`: whether TOCTOU-safe traversal is enabled.
    - `error:any`: an error object if an error occurred during traversal.
    - `dirs:string[]`: a list of directories that will be traversed.
    - `depths:integer[]`: a list of depths corresponding to the directories in `dirs`.
    - `dir:dir`: a directory object that created by `lua-opendir` module.
        - https://github.com/mah0x211/lua-opendir

**Examples**

```lua
local walkdir = require('walkdir')

-- iterate manually
local iter, ctx = walkdir('/tmp', true)
local pathname, err, entry, isdir, depth, stat = iter(ctx)
while pathname do
    print(pathname, err, entry, isdir, depth, stat)
    pathname, err, entry, isdir, depth, stat = iter(ctx)
end

-- or use a generic for loop
for pathname, err, entry, isdir, depth, stat in walkdir('/tmp', true) do
    print(pathname, err, entry, isdir, depth, stat)
end

-- enable TOCTOU-safe traversal
for pathname, err, entry, isdir in walkdir('/tmp', false, nil, true) do
    print(pathname, err, entry, isdir)
end
```

