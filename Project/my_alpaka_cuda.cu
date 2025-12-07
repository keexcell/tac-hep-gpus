#include <stdio.h>
#include <algorithm>
#include <alpaka/alpaka.hpp>
#include "config.h"
#include "WorkDiv.hpp"


using namespace std;
using namespace alpaka;

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


struct stencil_2d {
	template <typename TAcc, typename T>
	ALPAKA_FN_ACC void operator()(TAcc const& acc,
								  T const* __restrict__ in,
								  T * __restrict__ out
								 ) const {
	auto globalThreadIdx = alpaka::getIdx<alpaka::Grid, alpaka::Threads>(acc);
	int threadIdxX = globalThreadIdx[0];
	int threadIdxY = globalThreadIdx[1];
	auto blocksize = alpaka::getWorkDiv<alpaka::Block, alpaka::Threads>(acc);
	int blockdimX = blocksize[0];
	int blockdimY = blocksize[1];
	auto blockId = alpaka::getWorkDiv<alpaka::Grid, alpaka::Blocks>(acc);
	int blockIdX = blockId[0];
	int blockIdY = blockId[1];

	int gindex_x = threadIdxX + blockIdX * blockdimX;
	int lindex_x = threadIdxX + RADIUS;
	int gindex_y = threadIdxY + blockIdY * blockdimY;
	int lindex_y = threadIdxY + RADIUS;
	auto& temp = alpaka::declareSharedVar<std::uint32_t, __COUNTER__>(acc);

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
	
	syncBlockThreads(acc);

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
};

// Square matrix multiplication on GPU : C = A * B
struct matrix_mult {
	template <typename TAcc, typename T>
	ALPAKA_FN_ACC void operator()(TAcc const& acc, 
								  T const* __restrict__ A,
								  T const* __restrict__ B,
								  T *__restrict__ C,
								  uint32_t size
								)const{
							
	auto& tempA = alpaka::declareSharedVar<std::uint32_t, __COUNTER__>(acc);   
	auto& tempB = alpaka::declareSharedVar<std::uint32_t, __COUNTER__>(acc);
	int temp_sum = 0;

	auto globalThreadIdx = alpaka::getIdx<alpaka::Grid, alpaka::Threads>(acc);
	int threadIdX = globalThreadIdx[0];
	int threadIdY = globalThreadIdx[1];
	auto blocksize = alpaka::getWorkDiv<alpaka::Block, alpaka::Threads>(acc);
	int blockdimX = blocksize[0];
	int blockdimY = blocksize[1];
	auto blockId = alpaka::getWorkDiv<alpaka::Grid, alpaka::Blocks>(acc);
	int blockIdX = blockId[0];
	int blockIdY = blockId[1];
	// create thread x and y variables
    int row = blockIdY * BLOCK_SIZE + threadIdY;
    int col = blockIdX * BLOCK_SIZE + threadIdX;
	int t_row = threadIdY;
	int t_col = threadIdX;
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
		syncBlockThreads(acc);

		// then with one block, compute the element                
		for (int k = 0; k < BLOCK_SIZE; k++){
			temp_sum += tempA[t_row][k]*tempB[k][t_col];
			//atomicAdd(C[row*size + col], tempC[k]);
		}
		syncBlockThreads(acc);
	}
	if (row<size && col<size){
		C[(blockIdx.y*blockDim.y+threadIdx.y)*size+(blockIdx.x*blockDim.x)+threadIdx.x] = temp_sum;
	}
}
};

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


int main() {
	//accelerator platform
	Platform platform;
	//host platform
	HostPlatform host_platform;
	Host host = alpaka::getDevByIdx(host_platform, 0u);
	//device
	Device device = alpaka::getDevByIdx(platform, 0u);

	constexpr uint32_t size = (N + 2*RADIUS)*(N + 2*RADIUS) * sizeof(int);
    constexpr uint32_t DSIZE = N + 2*RADIUS;

	// Alloc space for host device copies
	auto h_A = alpaka::allocMappedBuf<uint32_t, uint32_t>(host, platform, size);
	auto h_B = alpaka::allocMappedBuf<uint32_t, uint32_t>(host, platform, size);
	auto h_Astenc = alpaka::allocMappedBuf<uint32_t, uint32_t>(host, platform, size);
	auto h_Bstenc = alpaka::allocMappedBuf<uint32_t, uint32_t>(host, platform, size);
	auto h_C = alpaka::allocMappedBuf<uint32_t, uint32_t>(host, platform, size);
	
	//filling in with ints
	fill_ints(h_A, (N + 2*RADIUS)*(N + 2*RADIUS), A_val);
	fill_ints(h_B, (N + 2*RADIUS)*(N + 2*RADIUS), B_val);
    fill_ints(h_Astenc, (N + 2*RADIUS)*(N + 2*RADIUS), A_val);
    fill_ints(h_Bstenc, (N + 2*RADIUS)*(N + 2*RADIUS), B_val);
    fill_ints(h_C, (N + 2*RADIUS)*(N + 2*RADIUS), 0);

	auto queue = Queue{device};

	//create device copies
	auto d_A = alpaka::allocAsyncBuf<uint32_t, uint32_t>(queue, size);
	auto d_B = alpaka::allocAsyncBuf<uint32_t, uint32_t>(queue, size);
	auto d_Astenc = alpaka::allocAsyncBuf<uint32_t, uint32_t>(queue, size);
	auto d_Bstenc = alpaka::allocAsyncBuf<uint32_t, uint32_t>(queue, size);
	auto d_C = alpaka::allocAsyncBuf<uint32_t, uint32_t>(queue, size);
	//copy host object info to device object
	alpaka::memcpy(queue, d_A, h_A);
  	alpaka::memcpy(queue, d_B, h_B);
	alpaka::memcpy(queue, d_Astenc, h_Astenc);
  	alpaka::memcpy(queue, d_Bstenc, h_Bstenc);
	alpaka::memcpy(queue, d_C, h_C);

	// Launch stencil_2d() kernel on GPU
	uint32_t gridSize = (DSIZE + BLOCK_SIZE-1)/BLOCK_SIZE;
	auto div = makeWorkDiv<Acc2D>({gridSize, gridSize}, {BLOCK_SIZE, BLOCK_SIZE});
	// Launch the kernel
	alpaka::exec<Acc2D>(queue, div, stencil_2d{}, d_A.data(), d_Astenc.data()); 
	alpaka::exec<Acc2D>(queue, div, stencil_2d{}, d_B.data(), d_Bstenc.data()); 
  	alpaka::exec<Acc2D>(queue, div, matrix_mult{}, d_Astenc.data(), d_Bstenc.data(), d_C.data(), DSIZE); 

	alpaka::memcpy(queue, h_Astenc, d_Astenc);
  	alpaka::memcpy(queue, h_Bstenc, d_Bstenc);
	alpaka::memcpy(queue, h_C, d_C);
  	alpaka::wait(queue);

	cudaCheckErrors("Error with kernel");

	// Error Checking
    stencil_checker(h_Astenc, A_val);
    stencil_checker(h_Bstenc, B_val);
    mult_checker(h_Astenc, h_Bstenc, h_C);

	printf("Success!\n");

	return 0;
}