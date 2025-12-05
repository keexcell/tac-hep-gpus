### C++ and CPU profiling
- Compiled C++ file on HEP cluster with `g++ project_pt1.cpp -o project_cpp`, ran file with `./project_cpp`  
- For VTune:  
    - On the GPUs set up environment with `source /opt/intel/oneapi/setvars.sh`

### Porting to CUDA
- From HEP cluster, `ssh g38nXX` onto the GPUs
- Compiled: `nvcc project_pt2.cu -o project_cuda`, ran: `./project_cuda`
- Ran nsys profiler with `nsys profile --stats=true ./project_cuda`
    - Wasn't able to open the GUI, but at least sent the report to cuda_report.txt with `nsys stats report1.nsys-rep > cuda_report.txt`
    - *document/comment on the time spent in each CUDA API call. Also, make note on the time spent on host and device.*
- *Switch to managed memory*

### Optimizing performance in CUDA
- *Optimize the performance of your code making use of non-default CUDA streams and shared memory.*
- *Once you have decided on the best approach, profile your application and compare the time spent in each API call and the overall timing of your application with your initial CUDA implementation.*

### Alpaka
