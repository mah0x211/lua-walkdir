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


## iter, ctx = walkdir( pathname [, follow_symlink]] )

Get an iterator function and context for traversing a specified directory.

**Parameters**

- `pathname:string`: the directory to traverse.
- `follow_symlink:boolean`: follow symbolic links. (default: `false`)

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
    - `error:any`: an error object if an error occurred during traversal.
    - `dirs:string[]`: a list of directories that will be traversed.
    - `depths:integer[]`: a list of depths corresponding to the directories in `dirs`.    
    - `dir:dir`: a directory object that created by `lua-opendir` module.
        - https://github.com/mah0x211/lua-opendir

**Example**

the following example shows how to use the `walkdir` function to traverse a directory and print each entry:

```lua
local walkdir = require('walkdir')

-- get an iterator function and context for traversing a /tmp directory
local iter, ctx = walkdir('/tmp', true)
local pathname, err, entry, isdir, depth, stat = iter(ctx)
while pathname do
    print(pathname, err, entry, isdir, depth, stat)
    if err then
        print('Error:', err)
    end
    -- read next entry
    pathname, err, entry, isdir, depth, stat = iter(ctx)
end

-- or using a generic for loop
for pathname, err, entry, isdir, depth, stat in walkdir('/tmp', true) do
    print(pathname, err, entry, isdir, depth, stat)
    if err then
        print('Error:', err)
    end
end
```

Also, you can pass a `walkerfn` function to the `walkdir` function to control the traversal behavior

### err = walkdir( pathname [, follow_symlink [, walkerfn]] )

If `walkerfn` is provided, the function will traverse the directory and call the `walkerfn` for each entry.

**Parameters**

- `walkerfn:function`: a function that will be called for each entry in the directory.
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

the following example shows how to use the `walkdir` function to traverse a directory and call a `walkerfn` for each entry:

```lua
local walkdir = require('walkdir')

-- traverse a /tmp directory and call the walker function for each entry
local err = walkdir('/tmp', true, function(pathname, entry, isdir, depth, stat)
    print(pathname, entry, isdir, depth, stat)
    -- if the entry is a directory and only want to traverse directories up to depth 2
    if isdir and depth == 2 then
        -- skip traversing this directory
        return true
    end
end)
if err then
    print('Error:', err)
end
```

