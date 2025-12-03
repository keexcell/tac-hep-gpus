#include <stdio.h>
#include <algorithm>

using namespace std;

#define RADIUS 3
#define BLOCK_SIZE 32
const int DSIZE = 512;
#define N (DSIZE - 2*RADIUS)
const int A_val = 2;
const int B_val = 3;


// error checking macro
#define cudaCheckErrors(msg)                                   \
   do {                                                        \
       cudaError_t __err = cudaGetLastError();                 \
       if (__err != cudaSuccess) {                             \
           fprintf(stderr, "Fatal error: %s (%s at %s:%d)\n",  \
                   msg, cudaGetErrorString(__err),             \
                   __FILE__, __LINE__);                        \
           fprintf(stderr, "*** FAILED - ABORTING\n");         \
           exit(1);                                            \
       }                                                       \
   } while (0)

__global__ void stencil_2d(int *in, int *out) {

	__shared__ int temp[BLOCK_SIZE + 2 * RADIUS][BLOCK_SIZE + 2 * RADIUS];
	int gindex_x = threadIdx.x + blockIdx.x * blockDim.x;
	int lindex_x = threadIdx.x + RADIUS;
	int gindex_y = threadIdx.y + blockIdx.y * blockDim.y;
	int lindex_y = threadIdx.y + RADIUS;

	// Read input elements into shared memory
	int size = N + 2 * RADIUS;
	//size is our dimensions so to collapse in and out to 1D rep do i*size + j
	temp[lindex_x][lindex_y] = in[gindex_x*DSIZE + gindex_y];

	if (threadIdx.x < RADIUS) {
		temp[lindex_x - RADIUS][lindex_y] = in[(gindex_x - RADIUS)*size + gindex_y];
		temp[lindex_x + BLOCK_SIZE][lindex_y] = in[(gindex_x + BLOCK_SIZE)*size + gindex_y];
	}

	if (threadIdx.y < RADIUS ) {
		temp[lindex_x][lindex_y - RADIUS] = in[gindex_x*size + (gindex_y - RADIUS)];
        temp[lindex_x][lindex_y + BLOCK_SIZE] = in[gindex_x*size + (gindex_y + BLOCK_SIZE)];
	}
	
	__syncthreads();

	// Apply the stencil
	int result = 0;
	for (int offset = -RADIUS; offset <= RADIUS; offset++){
		//to avoid double counting, only have the 2 lines if offset is not 0
		//if offset is 0 you just want one line of [lindex_x][lindex_y]
		if (offset == 0)
			result += temp[lindex_x][lindex_y];
		else{
			result += temp[lindex_x + offset][lindex_y];
			result += temp[lindex_x][lindex_y + offset];
		}
	}
	
	// Store the result
	out[gindex_x*size + gindex_y] = result;
}

int stencil_checker(const int *A_out, const int *B_out){
	for (int i = 0; i < N + 2 * RADIUS; ++i) {
		for (int j = 0; j < N + 2 * RADIUS; ++j) {
			if (i < RADIUS || i >= N + RADIUS) {
				if (A_out[j+i*(N + 2 * RADIUS)] != A_val) {
					printf("A1: Mismatch at index [%d,%d], was: %d, should be: %d\n", i,j, A_out[j+i*(N + 2 * RADIUS)], A_val);
					return -1;
				}
				if (B_out[j+i*(N + 2 * RADIUS)] != B_val) {
					printf("B1: Mismatch at index [%d,%d], was: %d, should be: %d\n", i,j, B_out[j+i*(N + 2 * RADIUS)], B_val);
					return -1;
				}
			}
			else if (j < RADIUS || j >= N + RADIUS) {
				if (A_out[j+i*(N + 2 * RADIUS)] != A_val) {
					printf("A2: Mismatch at index [%d,%d], was: %d, should be: %d\n", i,j, A_out[j+i*(N + 2 * RADIUS)], A_val);
					return -1;
				}
				if (B_out[j+i*(N + 2 * RADIUS)] != B_val) {
					printf("B2: Mismatch at index [%d,%d], was: %d, should be: %d\n", i,j, B_out[j+i*(N + 2 * RADIUS)], B_val);
					return -1;
				}
			}		 
			else {
				if (A_out[j+i*(N + 2 * RADIUS)] != A_val + A_val*4 * RADIUS) {
					printf("A3: Mismatch at index [%d,%d], was: %d, should be: %d\n", i,j, A_out[j+i*(N + 2 * RADIUS)], A_val + A_val*4*RADIUS);
					return -1;
				}
				if (B_out[j+i*(N + 2 * RADIUS)] != B_val + B_val*4 * RADIUS) {
					printf("B3: Mismatch at index [%d,%d], was: %d, should be: %d\n", i,j, B_out[j+i*(N + 2 * RADIUS)], B_val + B_val*4*RADIUS);
					return -1;
				}
			}
		}
	}
	return 0;
}

// Square matrix multiplication on GPU : C = A * B
__global__ void matrix_mult(const int *A, const int *B, int *C, int size) {
    // create thread x index (calling it column like lecture)
    // create thread y index (calling it row like lecture)
    int row = threadIdx.y + blockDim.y*blockIdx.y;
    int col = threadIdx.x + blockDim.x*blockIdx.x;
    // Make sure we are not out of range
    if ((row < size) && (col < size)) {
        float temp_sum = 0;
        for (int i = 0; i < size; i++){
            //Add dot product of row and column
	    	temp_sum += A[row*size + i]*B[i*size + col];
        }
        C[row*size+col] = temp_sum;
    }

}

int mult_checker(const int *A, const int *B, const int *C){
	int A_stenc_val = A_val + A_val*4*RADIUS;
	int B_stenc_val = B_val + B_val*4*RADIUS;
	int DSIZE_mid = DSIZE - 2*RADIUS;
	for (int i = 0; i < DSIZE; ++i) {
		for (int j = 0; j < DSIZE; ++j) {
			if ((i < RADIUS || i >= N + RADIUS) && (j < RADIUS || j >= N + RADIUS)){
				if (C[j+i*DSIZE] != A_val*B_val*DSIZE){
					printf("1 Mismatch at index [%d,%d], was: %d, should be: %d\n", i,j, C[j+i*DSIZE], A_val*B_val*DSIZE);
					return -1;
				}
			}
			else if ((i < RADIUS || i >= N + RADIUS) && (j >= RADIUS && j < N + RADIUS)){
				if (C[j+i*DSIZE] != A_val*B_val*2*RADIUS + A_val*B_stenc_val*DSIZE_mid){
					printf("2 Mismatch at index [%d,%d], was: %d, should be: %d\n", i,j, C[j+i*DSIZE], A_val*B_val*2*RADIUS + A_val*B_stenc_val*DSIZE_mid);
					return -1;
				}
			}
			else if ((i >= RADIUS && i < N + RADIUS) && (j >= RADIUS && j < N + RADIUS)){
				if (C[j+i*DSIZE] != A_val*B_val*2*RADIUS + A_stenc_val*B_stenc_val*DSIZE_mid){
					printf("3 Mismatch at index [%d,%d], was: %d, should be: %d\n", i,j, C[j+i*DSIZE], A_val*B_val*2*RADIUS + A_stenc_val*B_stenc_val*DSIZE_mid);
					return -1;
				}
			}
			else{
				if (C[j+i*DSIZE] != A_val*B_val*2*RADIUS + A_stenc_val*B_val*DSIZE_mid){
					printf("4 Mismatch at index [%d,%d], was: %d, should be: %d\n", i,j, C[j+i*DSIZE], A_val*B_val*2*RADIUS + A_stenc_val*B_val*DSIZE_mid);
					return -1;
				}
			}
		}
	}
	return 0;
}

int main(void) {

	int *h_A, *h_B, *h_Astenc, *h_Bstenc, *h_C; // host copies of a, b, c
	int *d_A, *d_B, *d_Astenc, *d_Bstenc, *d_C;; // device copies of a, b, c

	// Alloc space for host copies and setup values
	int size = (N + 2*RADIUS)*(N + 2*RADIUS) * sizeof(int);
	h_A = (int *)malloc(size); fill_n(h_A, (N + 2*RADIUS)*(N + 2*RADIUS), A_val);
	h_B = (int *)malloc(size); fill_n(h_B,(N + 2*RADIUS)*(N + 2*RADIUS), B_val);
	h_Astenc = (int *)malloc(size); fill_n(h_Astenc, (N + 2*RADIUS)*(N + 2*RADIUS), A_val);
    h_Bstenc = (int *)malloc(size); fill_n(h_Bstenc, (N + 2*RADIUS)*(N + 2*RADIUS), B_val);
	h_C = (int *)malloc(size); fill_n(h_C, (N + 2*RADIUS)*(N + 2*RADIUS), 0);

	// Alloc space for device copies
	cudaMalloc((void **)&d_A, size);
	cudaMalloc((void **)&d_Astenc, size);
	cudaMalloc((void **)&d_B, size);
    cudaMalloc((void **)&d_Bstenc, size);
	cudaMalloc((void **)&d_C, size);

	// Copy to device
	cudaMemcpy(d_A, h_A, size, cudaMemcpyHostToDevice);
	cudaMemcpy(d_Astenc, h_Astenc, size, cudaMemcpyHostToDevice);
	cudaMemcpy(d_B, h_B, size, cudaMemcpyHostToDevice);
    cudaMemcpy(d_Bstenc, h_Bstenc, size, cudaMemcpyHostToDevice);
	cudaMemcpy(d_C, h_C, size, cudaMemcpyHostToDevice);

	// Launch stencil_2d() kernel on GPU
	int gridSize = (N + BLOCK_SIZE-1)/BLOCK_SIZE;
	dim3 grid(gridSize, gridSize);
	dim3 block(BLOCK_SIZE, BLOCK_SIZE);
	// Launch the kernel 
	// Properly set memory address for first element on which the stencil will be applied
	stencil_2d<<<grid,block>>>(d_A + RADIUS*(N + 2*RADIUS) + RADIUS, d_Astenc + RADIUS*(N + 2*RADIUS) + RADIUS);
    stencil_2d<<<grid,block>>>(d_B + RADIUS*(N + 2*RADIUS) + RADIUS, d_Bstenc + RADIUS*(N + 2*RADIUS) + RADIUS);
	matrix_mult<<<grid,block>>>(d_Astenc, d_Bstenc, d_C, DSIZE);

	// Copy result back to host
	cudaMemcpy(h_A, d_A, size, cudaMemcpyDeviceToHost);
    cudaMemcpy(h_Astenc, d_Astenc, size, cudaMemcpyDeviceToHost);
	cudaMemcpy(h_B, d_B, size, cudaMemcpyDeviceToHost);
    cudaMemcpy(h_Bstenc, d_Bstenc, size, cudaMemcpyDeviceToHost);
	cudaMemcpy(h_C, d_C, size, cudaMemcpyDeviceToHost);

	stencil_checker(h_Astenc, h_Bstenc);
	mult_checker(h_Astenc, h_Bstenc, h_C);

	// Cleanup
	free(h_A);
	free(h_B);
	free(h_Astenc);
    free(h_Bstenc);
	free(h_C);
	cudaFree(d_A);
	cudaFree(d_B);
	cudaFree(d_Astenc);
    cudaFree(d_Bstenc);
	cudaFree(d_C);
	printf("Success!\n");

	return 0;
}
