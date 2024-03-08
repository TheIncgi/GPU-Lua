package gplua;

import java.util.Arrays;

import com.nativelibs4java.opencl.JavaCL;

public class DeviceStats {
	public static void main(String[] args) {
		var device = JavaCL.getBestDevice();
		
		
		System.out.println(device.getName());
		System.out.println("==========================================================");
		System.out.println("CL Version:          " + device.getVersion());
		System.out.println("Vendor:              " + device.getVendor());
		System.out.println("Driver version:      " + device.getDriverVersion());
		System.out.println("Global Mem Size:     " + device.getGlobalMemSize());
		System.out.println("Local mem size:      " + device.getLocalMemSize());
		System.out.println("Max Work Group Size: " + device.getMaxWorkGroupSize());
		System.out.println("Max Work Item Sizes: " + Arrays.toString(device.getMaxWorkItemSizes()));
		System.out.println("Max work dimensions: " + device.getMaxWorkItemDimensions());
		System.out.println("Max compute units:   " + device.getMaxComputeUnits());
	}
}
