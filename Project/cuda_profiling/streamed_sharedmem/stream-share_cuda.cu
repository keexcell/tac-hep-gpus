#include <stdio.h>
#include <algorithm>


using namespace std;

#define RADIUS 3
#define N 512
#define BLOCK_SIZE 32
#define A_val 2
#define B_val 3

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
	temp[lindex_x][lindex_y] = in[gindex_x*size + gindex_y];

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

// Square matrix multiplication on GPU : C = A * B
__global__ void matrix_mult(const int *A, const int *B, int *C, int size) {
	__shared__ int tempA[BLOCK_SIZE][BLOCK_SIZE];     
	__shared__ int tempB[BLOCK_SIZE][BLOCK_SIZE];
	int temp_sum = 0;

	// create thread x and y variables
    int row = blockIdx.y * BLOCK_SIZE + threadIdx.y;
    int col = blockIdx.x * BLOCK_SIZE + threadIdx.x;
	int t_row = threadIdx.y;
	int t_col = threadIdx.x;
    // split our big matrices up into smaller ones that are a blocksize x blocksize
    for (int i = 0; i < (size+BLOCK_SIZE-1)/BLOCK_SIZE; i++){
		// iterate through how many blocks there are
		if (i*BLOCK_SIZE + t_col < size && row < size){
        	tempA[t_row][t_col] = A[row*size + (i*BLOCK_SIZE+t_col)];
		}
		else{
			tempA[t_row][t_col] = 0;
		}
		if (i*BLOCK_SIZE + t_row < size && col < size){
        	tempB[t_row][t_col] = B[(i*BLOCK_SIZE+t_row)*size + col];
		}
		else{
			tempB[t_row][t_col] = 0;
		}
		__syncthreads();

		// then with one block, compute the element                
		for (int k = 0; k < BLOCK_SIZE; k++){
			temp_sum += tempA[t_row][k]*tempB[k][t_col];
			//atomicAdd(C[row*size + col], tempC[k]);
		}
		__syncthreads();
	}
	if (row<size && col<size){
		C[(blockIdx.y*blockDim.y+threadIdx.y)*size+(blockIdx.x*blockDim.x)+threadIdx.x] = temp_sum;
	}
}

int stencil_checker(const int *out, int value){
	for (int i = 0; i < N + 2 * RADIUS; ++i) {
		for (int j = 0; j < N + 2 * RADIUS; ++j) {

			if (i < RADIUS || i >= N + RADIUS) {
				if (out[j+i*(N + 2 * RADIUS)] != value) {
					printf("Mismatch at index [%d,%d], was: %d, should be: %d\n", i,j, out[j+i*(N + 2 * RADIUS)], value);
					return -1;
				}
			}
			else if (j < RADIUS || j >= N + RADIUS) {
				if (out[j+i*(N + 2 * RADIUS)] != value) {
					printf("Mismatch at index [%d,%d], was: %d, should be: %d\n", i,j, out[j+i*(N + 2 * RADIUS)], value);
					return -1;
				}
			}		 
			else {
				if (out[j+i*(N + 2 * RADIUS)] != value + value * 4 * RADIUS) {
					printf("Mismatch at index [%d,%d], was: %d, should be: %d\n", i,j, out[j+i*(N + 2 * RADIUS)], value + value * 4 * RADIUS);
					return -1;
				}
			}
		}
	}
    return 0;
}

int mult_checker(const int *A, const int *B, const int *C){
	int A_stenc_val = A_val + A_val*4*RADIUS;
	int B_stenc_val = B_val + B_val*4*RADIUS;
	int DSIZE = N + 2*RADIUS;
	for (int i = 0; i < N + 2 * RADIUS; ++i) {
		for (int j = 0; j < N + 2 * RADIUS; ++j) {
			if ((i < RADIUS || i >= N + RADIUS) && (j < RADIUS || j >= N + RADIUS)){
				if (C[j+i*DSIZE] != A_val*B_val*DSIZE){
					printf("1 Mismatch at index [%d,%d], was: %d, should be: %d\n", i,j, C[j+i*DSIZE], A_val*B_val*DSIZE);
					return -1;
				}
			}
			else if ((i < RADIUS || i >= N + RADIUS) && (j >= RADIUS && j < N + RADIUS)){
				if (C[j+i*DSIZE] != A_val*B_val*2*RADIUS + A_val*B_stenc_val*N){
					printf("2 Mismatch at index [%d,%d], was: %d, should be: %d\n", i,j, C[j+i*DSIZE], A_val*B_val*2*RADIUS + A_val*B_stenc_val*N);
					return -1;
				}
			}
			else if ((i >= RADIUS && i < N + RADIUS) && (j >= RADIUS && j < N + RADIUS)){
				if (C[j+i*DSIZE] != A_val*B_val*2*RADIUS + A_stenc_val*B_stenc_val*N){
					printf("3 Mismatch at index [%d,%d], was: %d, should be: %d\n", i,j, C[j+i*DSIZE], A_val*B_val*2*RADIUS + A_stenc_val*B_stenc_val*N);
					return -1;
				}
			}
			else{
				if (C[j+i*DSIZE] != A_val*B_val*2*RADIUS + A_stenc_val*B_val*N){
					printf("4 Mismatch at index [%d,%d], was: %d, should be: %d\n", i,j, C[j+i*DSIZE], A_val*B_val*2*RADIUS + A_stenc_val*B_val*N);
					return -1;
				}
			}
		}
	}
	return 0;
}

void fill_ints(int *x, int size, int n) {
   // Store the result
   // https://en.cppreference.com/w/cpp/algorithm/fill_n
   fill_n(x, size, n);
}


int main(void) {

	int *d_A, *d_Astenc, *d_B, *d_Bstenc, *d_C; // device copies of a, b, c
	int size = (N + 2*RADIUS)*(N + 2*RADIUS) * sizeof(int);
    int DSIZE = N + 2*RADIUS;

	//create streams
    cudaStream_t streamA, streamB;
    cudaStreamCreate(&streamA);
    cudaStreamCreate(&streamB);

	// Alloc space for device copies
	cudaMallocManaged((void **)&d_A, size);
	cudaStreamAttachMemAsync(streamA, d_A, size);
	cudaMallocManaged((void **)&d_B, size);
	cudaStreamAttachMemAsync(streamB, d_B, size);
    cudaMallocManaged((void **)&d_Astenc, size);
    cudaStreamAttachMemAsync(streamA, d_Astenc, size, cudaMemAttachGlobal);
	cudaMallocManaged((void **)&d_Bstenc, size);
    cudaStreamAttachMemAsync(streamB, d_Bstenc, size, cudaMemAttachGlobal);
	cudaMallocManaged((void **)&d_C, size);

	//filling in with ints
	fill_ints(d_A, (N + 2*RADIUS)*(N + 2*RADIUS), A_val);
	fill_ints(d_B, (N + 2*RADIUS)*(N + 2*RADIUS), B_val);
    fill_ints(d_Astenc, (N + 2*RADIUS)*(N + 2*RADIUS), A_val);
    fill_ints(d_Bstenc, (N + 2*RADIUS)*(N + 2*RADIUS), B_val);
    fill_ints(d_C, (N + 2*RADIUS)*(N + 2*RADIUS), 0);

	// Launch stencil_2d() kernel on GPU
	int gridSize = (N + BLOCK_SIZE-1)/BLOCK_SIZE;
	dim3 grid(gridSize, gridSize);
	dim3 block(BLOCK_SIZE, BLOCK_SIZE);
	// Launch the kernel 
	// Properly set memory address for first element on which the stencil will be applied
	stencil_2d<<<grid,block,0,streamA>>>(d_A + RADIUS*(N + 2*RADIUS) + RADIUS , d_Astenc + RADIUS*(N + 2*RADIUS) + RADIUS);
	stencil_2d<<<grid,block,0,streamB>>>(d_B + RADIUS*(N + 2*RADIUS) + RADIUS , d_Bstenc + RADIUS*(N + 2*RADIUS) + RADIUS);
    cudaCheckErrors("Error with stencil kernel");

	cudaStreamSynchronize(streamA);
    cudaStreamSynchronize(streamB);

    //Launch matrix_mult kernel
    int gridSize2 = (DSIZE+BLOCK_SIZE-1)/BLOCK_SIZE;
    dim3 grid2(gridSize2, gridSize2);
    dim3 block2(BLOCK_SIZE, BLOCK_SIZE);
    matrix_mult<<<grid2, block2>>>(d_Astenc, d_Bstenc, d_C, DSIZE);
    cudaCheckErrors("Error with multiplication kernel");

	cudaDeviceSynchronize();

	// Error Checking
    stencil_checker(d_Astenc, A_val);
    stencil_checker(d_Bstenc, B_val);
    mult_checker(d_Astenc, d_Bstenc, d_C);

	// Cleanup
	cudaFree(d_A);
	cudaFree(d_B);
	cudaFree(d_Astenc);
	cudaFree(d_Bstenc);
	cudaFree(d_C);
	printf("Success!\n");

	return 0;
}