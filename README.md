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
for pathname, entry, isdir in walkdir('/tmp', true) do
    print(pathname, entry, isdir)
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
    pathname:string, entry:string, isdir:boolean, err:any = iter(ctx:table)

    * pathname: the entry's pathname.
    * entry: the entry's name.
    * isdir: whether the entry is a directory.
    * err: an error object if an error occurred during traversal.
    ```
    - **NOTE:** if an error occurs during traversal, the iterator returns an empty string `''`, `nil`, `nil`, and the error object. On subsequent calls, it consistently returns `nil`, `nil`, `nil`, and the same error object.
- `ctx:table`: a context table that contains the following fields:
    - `pathname:string`: the current pathname of the directory being traversed.
    - `follow_symlink:boolean`: whether symbolic links are followed.
    - `error:any`: an error object if an error occurred during traversal.
    - `dirs:string[]`: a list of directories that will be traversed.
    - `dir:dir`: a directory object that created by `lua-opendir` module.
        - https://github.com/mah0x211/lua-opendir

**Example**

the following example shows how to use the `walkdir` function to traverse a directory and print each entry:

```lua
local walkdir = require('walkdir')

-- get an iterator function and context for traversing a /tmp directory
local iter, ctx = walkdir('/tmp', true)
local pathname, entry, isdir, err = iter(ctx)
while pathname do
    print(pathname, entry, isdir, err)
    if err then
        print('Error:', err)
    end
    -- read next entry
    pathname, entry, isdir, err = iter(ctx)
end

-- or using a generic for loop
for pathname, entry, isdir, err in walkdir('/tmp', true) do
    print(pathname, entry, isdir, err)
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
    walkerfn(pathname:string, entry:string, isdir:boolean):(skipdir:boolean, err:any)

    Parameters:
    * pathname: the entry's pathname.
    * entry: the entry's name.
    * isdir: whether the entry is a directory.

    Returns:
    * skipdir: If `true`, the directory will not be traversed further, otherwise it will be traversed.
    * err: an error object if an error occurred during traversal. If an error returned, the traversal will stop and the error will be returned by the `walkdir` function.
    ```

**Returns**

- `err:any`: an error object if an error occurred during traversal. If no error occurred, it returns `nil`.

**Example**

the following example shows how to use the `walkdir` function to traverse a directory and call a `walkerfn` for each entry:

```lua
local walkdir = require('walkdir')

-- traverse a /tmp directory and call the walker function for each entry
local err = walkdir('/tmp', true, function(pathname, entry, isdir)
    print(pathname, entry, isdir)
    -- if the entry is a directory, return true to traverse it further
    if isdir then
        return true
    end
    -- if the entry is a file, return false to not traverse it further
    return false
end)
if err then
    print('Error:', err)
end
```


