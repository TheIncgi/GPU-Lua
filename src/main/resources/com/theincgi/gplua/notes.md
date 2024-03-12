# Indexing
All indexing is starting at 0 unless you're looking at the section that handles the actual byte code or in lua type code
Example: Array is 0 indexed
         Table can have an array, table is responsible for turning the heap value indexed at 1 into the array index (@ 0)

# Types
T_INT's value is signed
Unless a type *needs* to be signed I've opted for the unsigned version for variables

# TODO
array grow in place
freeHeap should probably skip chunk merging now that it occurs in allocateHeap

# Heap bugs
Used to visualize the heap as a timeline for different bugs that have occurred
https://docs.google.com/spreadsheets/d/1gIW6N9aL-yJWyhZuJXCdp0qSnRiO8rpFif-tY023TTE/edit#gid=182770226