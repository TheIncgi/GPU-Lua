# Indexing
All indexing is starting at 0 unless you're looking at the section that handles the actual byte code or in lua type code
Example: Array is 0 indexed
         Table can have an array, table is responsible for turning the heap value indexed at 1 into the array index (@ 0)

# Types
T_INT's value is signed
Unless a type *needs* to be signed I've opted for the unsigned version for variables

# TODO
freeHeap should probably skip chunk merging now that it occurs in allocateHeap

strings table should be treated as weak keys

strings table can be a hash set since the value we look up is the reference to the string based on hash (currently duplicate as key = key)

if sweep region covers return values, mark the object