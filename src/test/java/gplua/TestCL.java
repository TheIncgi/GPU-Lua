package gplua;


import org.bridj.Pointer;

import com.android.dx.rop.type.Type;
import com.nativelibs4java.opencl.CLBuffer;
import com.nativelibs4java.opencl.CLContext;
import com.nativelibs4java.opencl.CLEvent;
import com.nativelibs4java.opencl.CLKernel;
import com.nativelibs4java.opencl.CLProgram;
import com.nativelibs4java.opencl.JavaCL;
import com.nativelibs4java.opencl.CLMem.Usage;

public class TestCL {
	
	
	public static void main(String[] args) {
        // Initialize OpenCL context
        CLContext context = JavaCL.createBestContext();

        // Load and compile the OpenCL program
        String source = "__kernel void add(__global const float* a, __global const float* b, __global float* result, int n) {" +
                        "    int i = get_global_id(0);" +
                        "    if (i==0) { " + 
                        "      float* test = new float[5]; " + 
                        "      delete test; "+
                        "    }" +
                        "    if (i < n) {" +
                        "        result[i] = a[i] + b[i];" +
                        "    }" +
                        "}";
        CLProgram program = context.createProgram(source).build();

        // Create input arrays
        int n = 10;
        float[] a = new float[n];
        float[] b = new float[n];
        for (int i = 0; i < n; i++) {
            a[i] = i;
            b[i] = 2 * i;
        }

        // Allocate OpenCL buffers for input and output arrays
        CLBuffer<Float> aBuffer = context.createFloatBuffer(Usage.Input, n);
        CLBuffer<Float> bBuffer = context.createFloatBuffer(Usage.Input, n);
        CLBuffer<Float> resultBuffer = context.createFloatBuffer(Usage.Output, n);
        
        
        var queue = context.createDefaultOutOfOrderQueue();
        
        // Write data to input buffers
        Pointer<Float> aPtr = Pointer.pointerToArray(a);
        Pointer<Float> bPtr = Pointer.pointerToArray(b);
//        Pointer<Float> rPtr = Pointer.pointerToArray(resultBuffer)
        aBuffer.write(queue, aPtr, true);
        bBuffer.write(queue, bPtr, true);

        // Get a reference to the kernel
        CLKernel kernel = program.createKernel("add");

        // Set kernel arguments
        kernel.setArgs(aBuffer, bBuffer, resultBuffer, n);

        // Execute the kernel
        CLEvent event = kernel.enqueueNDRange(queue, new int[]{n});
        
        

        // Read the result from the output buffer
//        float[] result = new float[n];
        // Read the result from the output buffer
        var rPtr = resultBuffer.read(queue, event);
        resultBuffer.read(queue, rPtr, true);

        // Print the result
        System.out.println("Result:");
        for (int i = 0; i < n; i++) {
            System.out.println(rPtr.get(i));
        }
    }	
	
	
//	public static void main(String[] args) {
//		
//		var inputBuffer = IntBuffer.allocate(1);
//		var resultBuffer = FloatBuffer.allocate(1);
//		
//		CLContext context = JavaCL.createBestContext();
//		CLProgram program = context.createProgram("").build();
//		CLBuffer<Integer> input = context.createIntBuffer(Usage.Input, inputBuffer, true);
//		CLBuffer<Float> output = context.createFloatBuffer(Usage.Output, resultBuffer, false);
//		CLKernel kernel = program.createKernel("example", new float[] {u, v}, input, output);
//		
//	}
	
}
