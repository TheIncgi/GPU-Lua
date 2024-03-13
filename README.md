# GPU-Lua
 Running Lua on the GPU with help from Java & OpenCL

# Heap
Uses boundary tags for assigning blocks of memory and uses mark and sweep garbage collection.<br>
Resize operations instantly free the old array(s) and do not require garbage collection.

Each tag is 4 bytes

`0x80_00_00_00` is the used/free flag

`0x30_00_00_00` is for marking

`0x03_FF_FF_FF` is the largest chunk size


<a href="https://raw.githubusercontent.com/TheIncgi/GPU-Lua/main/debug.png?token=GHSAT0AAAAAACHZ6JMQQ4IW4OEKUUCYNC3GZPRGGSA"> <img src=debug.png alt="heap visualization" width= 850></a> <br>
[Table's hashmap portion being resized as more strings and functions are added to it. Click for full size]
