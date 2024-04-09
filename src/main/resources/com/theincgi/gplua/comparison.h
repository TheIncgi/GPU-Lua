#ifndef COMPARISON_H
#define COMPARISON_H

#include"vm.h"
#include"common.cl"

bool heapEquals( struct WorkerEnv* env, uchar* dataSourceA, href indexA, uchar* dataSourceB, href indexB );
bool compareLessThan( struct WorkerEnv* env, uchar* dataSourceA, uint indexA, uchar* dataSourceB, uint indexB );
bool compareLessThanOrEqual( struct WorkerEnv* env, uchar* dataSourceA, uint indexA, uchar* dataSourceB, uint indexB );

#endif