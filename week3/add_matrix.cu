#include <stdio.h>
#include <iostream>

const int DSIZE_X = 256;
const int DSIZE_Y = 256;

__global__ void add_matrix(float* A, float* B, float* C, int n, int m)
{
    // Express in terms of threads and blocks
    int idx = threadIdx.x + blockIdx.x * blockDim.x;
    int idy = threadIdx.y + blockIdx.y * blockDim.y;
    // Add the two matrices - make sure you are not out of range
    if ((idx <  n) && (idy < m) )
	//from slides, if sizeA = rows*columns, A(i,j) = i*columns+j
        C[idx*m+idy] =  A[idx*m+idy] + B[idx*m+idy];

}

int main()
{

    // Create and allocate memory for host and device pointers 
    float *h_A, *h_B, *h_C, *d_A, *d_B, *d_C;
    // Fill in the matrices, they'll be 1D of size n*m
    h_A = new float[DSIZE_X*DSIZE_Y];
    h_B = new float[DSIZE_X*DSIZE_Y];
    h_C = new float[DSIZE_X*DSIZE_Y];
    for (int i = 0; i < DSIZE_X; i++) {
        for (int j = 0; j < DSIZE_Y; j++) {
            h_A[i*DSIZE_Y+j] = rand()/(float)RAND_MAX;
            h_B[i*DSIZE_Y+j] = rand()/(float)RAND_MAX;
            h_C[i*DSIZE_Y+j] = 0;
        }
    }
    float size = DSIZE_X*DSIZE_Y*sizeof(float);
    cudaMalloc(&d_A, size);
    cudaMalloc(&d_B, size);
    cudaMalloc(&d_C, size);
    
    // Copy from host to device
    cudaMemcpy(d_A, h_A, size, cudaMemcpyHostToDevice);
    cudaMemcpy(d_B, h_B, size, cudaMemcpyHostToDevice);
    
    // Launch the kernel
    	// dim3 is a built in CUDA type that allows you to define the block 
    	// size and grid size in more than 1 dimentions
    	// Syntax : dim3(Nx,Ny,Nz)
    dim3 blockSize(32,32,1); //max block_dim = 1024, sqrt(1024)=32 so this is max square block
    dim3 gridSize(1,1,1); //just need one
    
    add_matrix<<<gridSize, blockSize>>>(d_A, d_B, d_C, DSIZE_X, DSIZE_Y);

    // Copy back to host 
    cudaMemcpy(h_C, d_C, size, cudaMemcpyDeviceToHost);
    
    // Print and check some elements to make the addition was succesfull
    for (int i = 0; i < 5; i++) {
        for (int j = 0; j < 5; j++) {
	    std::cout << "A[" << i << ", " << j << "] + B[" << i << ", " << j << "] = C[" << i << ", " << j << "]:" << std::endl;
	    std::cout << h_A[i*DSIZE_Y+j] << " + " << h_B[i*DSIZE_Y+j] << " = " << h_C[i*DSIZE_Y+j] << std::endl;
	    std::cout<<std::endl;
	}}

    // Free the memory     
    free(h_A);
    free(h_B);
    free(h_C);

    cudaFree(d_A);
    cudaFree(d_B);
    cudaFree(d_C);
    return 0;
}
