### C++ and CPU profiling
- Compiled C++ file on HEP cluster with `g++ project_pt1.cpp -o project_cpp`, ran file with `./project_cpp`  
- For VTune:  
    - On the GPUs set up environment with `source /opt/intel/oneapi/setvars.sh`
    - Generated the summary and hotspot reports (saved as .csv files) with 
    1. `vtune -collect hotspots -quiet ./project_cpp`
    2. `vtune -report summary -result-dir r001hs -format csv -report-output summary.csv`
    3. `vtune -report hotspots -result-dir r001hs -format csv -report-output hotspots.csv`
- matrix_mult is the most compute intensive part, being the only function showing up in the hotspots report.

### Porting to CUDA
- From HEP cluster, `ssh g38nXX` onto the GPUs
- Compiled: `nvcc first_cuda.cu -o first_cuda`, ran: `./first_cuda`
- Ran nsys profiler with `nsys profile --stats=true ./first_cuda`
    - Wasn't able to open the GUI, but at least sent the report to first_cuda_report.txt with `nsys stats report1.nsys-rep > first_cuda_report.txt`
    - cudaMalloc ran the longest with 251,285,764 ns-- 98.3% of the time. Everything else was insignificant compared to that-- the next biggest was cudaMemcpy with 1.2% of the time
    - 86% of the GPU time was spent on matrix_mult and 14% on stencil_2d
- Switch to managed memory. Compiled and ran with `nvcc managed_cuda.cu -o managed_cuda` and `./managed_cuda`
- Ran nsys profiler with `nsys profile --stats=true ./managed_cuda`, sent the report to managed_cuda_report.txt with `nsys stats report3.nsys-rep > managed_cuda_report.txt`
    - With this change now stencil_2d was more compute intensive taking up 75% of the GPU time and matrix_mult took 24.4%. They both took more time than before, adding up to 6401865 ns. On the API summary, cudaMallocManaged is running 96.6% of the time with 250,246,758ns.

### Optimizing performance in CUDA
- Compiled and ran with `nvcc stream-share_cuda.cu -o stream-share_cuda` and `./stream-share_cuda`
- Ran nsys profiler with `nsys profile --stats=true ./stream-share_cuda` and sent the report to cuda_report.txt with `nsys stats report4.nsys-rep > ss_cuda_report.txt`
    - Now cudaMallocManaged is taking up less time, only 0.1% of the time. cudaStreamCreate is open 96.9% of the time (249,654,108 ns). Stencil_2d now takes up 3,974,282 ns, 69.7% of the time, and matrix_mult takes up 1,729,768 ns. Now, versus the first CUDA implementation, stencil_2d takes up more time than matrix_mult. Most of the time is spent in the cudaStreamCreate (96.9%, 249,654,108ns). I believe this means that there was a timing improvement more obviously seen between the just managed memory and this streams+shared because ~96% of the time went down by ~1,000,000 ns.

### Alpaka
- To set up I git cloned the repos given in lecture:
    1. `git clone https://github.com/alpaka-group/alpaka.git -b 2.0.0 ${HOME}/public/alpaka`
    2. `git clone https://github.com/kokkos/mdspan.git ${HOME}/public/mdspan
       git -C ${HOME}/public/mdspan checkout 973ef6415a6396e5f0a55cb4c99afd1d1d541681`
    3. `git clone https://github.com/fwyzard/intro_to_alpaka.git -b tachep2025
       cd intro_to_alpaka/alpaka/
       make`
- I had to make sure to write the file within the intro_to_alpaka/alpaka folder but I compiled with `nvcc -x cu --expt-relaxed-constexpr -std=c++20 -O2 -g -I${HOME}/public/alpaka/include -DALPAKA_ACC_GPU_CUDA_ENABLED my_alpaka_cuda.cu -o my_alpaka_cuda` 
- To re-write code:
    - Following the syntax of 05_kernel.cc in intro_to_alpaka, the kernels had to be rewritten with:
      ```
      struct stencil_2d {
      template <typename TAcc, typename T>
      ALPAKA_FN_ACC void operator()(TAcc const& acc,  
								  T const* __restrict__ in,  
								  T * __restrict__ out,  
								 )const{  
      ...  
      };
      ```  
  at the beginning (and similar with matrix_mult) o make them alpaka functions. I was able to rewrite the shared memory variables and the threads/blocks in both kernels terms of alpaka variables (`alpaka::declareSharedVar<std::uint32_t, __COUNTER__>(acc);` and
	```
	auto globalThreadIdx = alpaka::getIdx<alpaka::Grid, alpaka::Threads>(acc);  
	auto blocksize = alpaka::getWorkDiv<alpaka::Block, alpaka::Threads>(acc);  
	auto blockId = alpaka::getWorkDiv<alpaka::Grid, alpaka::Blocks>(acc);
	```  
Instead of streams, I did alpaka queues and the host and device copies made with `allocMappedBuf` and `memcpy`




