# Frequently Asked Questions

## Lua Circular Dependency Issue

For example:

main.lua

```lua
print("main.lua");
local AFunc = require("./A");
AFunc();

```

A.lua

```lua
print("A.lua");
local BFunc = require("./B");

function AFunc() 
	print("A");
	BFunc();
end

return AFunc;
```

B.lua

```lua
print("B.lua");
local CFunc = require("./C");

function BFunc() 
	print("B");
	CFunc();
end

return BFunc;
```

C.lua

```lua
print("C.lua");
local AFunc = require("./A");

function CFunc() 
	print("C");
	AFunc();
end

return CFunc;
```

Running the program:

```bash
$ lua main.lua
A.lua B.lua C.lua A.lua B.lua C.lua A.lua B.lua C.lua A.lua B.lua C.lua A.lua B.lua lua: error loading module './C' from file './//C.lua': C stack overflow stack traceback: [C]: in ? [C]: in function 'require' .///B.lua:2: in main chunk [C]: in function 'require' .///A.lua:2: in main chunk [C]: in function 'require' .///C.lua:2: in main chunk [C]: in function 'require' .///B.lua:2: in main chunk [C]: in function 'require' ... (skipping 370 levels) [C]: in function 'require' .///A.lua:2: in main chunk [C]: in function 'require' .///C.lua:2: in main chunk [C]: in function 'require' .///B.lua:2: in main chunk [C]: in function 'require' .///A.lua:2: in main chunk [C]: in function 'require' main.lua:2: in main chunk [C]: in ? stack traceback: [C]: in ? [C]: in function 'require' .///B.lua:2: in main chunk [C]: in function 'require' .///A.lua:2: in main chunk [C]: in function 'require' .///C.lua:2: in main chunk [C]: in function 'require' .///B.lua:2: in main chunk [C]: in function 'require' ... (skipping 370 levels) [C]: in function 'require' .///A.lua:2: in main chunk [C]: in function 'require' .///C.lua:2: in main chunk [C]: in function 'require' .///B.lua:2: in main chunk [C]: in function 'require' .///A.lua:2: in main chunk [C]: in function 'require' main.lua:2: in main chunk [C]: in ?
```

The three files above form a perfect circular require chain:

* A.lua require B.lua
* B.lua require C.lua
* C.lua require A.lua

### Why This Happens

Lua’s `require()` mechanism works as follows:

1. When a module is required, Lua first creates an empty module entry and places it into `package.loaded`.
2. Lua then executes the module file.
3. If, during execution, the module requires another module that eventually leads back to itself, Lua will recursively execute module chunks again.

Because each module has not yet returned when the next `require()` happens, the corresponding entry in `package.loaded` remains in a `"loading..."` state.

When `C.lua` calls `require("./A")` again, Lua sees that `A` exists in `package.loaded`, but since the module is still loading, Lua __does not stop execution__. Instead, it executes `A.lua`’s chunk again, leading to infinite recursion and eventually a __C stack overflow__.

### How This Appears in Real Projects

In real-world business code, especially in complex systems where modules depend on each other, this kind of circular `require` issue is common.

Don’t panic — check the logs, identify the dependency cycle, and refactor slightly to break it.

For example, modifying `C.lua` like this:

```lua
print("C.lua");

function CFunc() 
    local AFunc = require("./A");
    print("C");
	AFunc();
end

return CFunc;
```

### Key Takeaway

When loading a module, Lua checks `package.loaded[name]`:

- If the value exists and is __not nil__, Lua returns it directly.
- If the value is `true` (indicating the module is currently loading), Lua __does not return immediately__.
- Instead, Lua continues executing the loader’s returned chunk (i.e., the module file).

In other words, `true` in `package.loaded` is only a __loading marker__, not a guard against re-executing the module file. This is why circular `require` chains can still cause infinite recursion.
