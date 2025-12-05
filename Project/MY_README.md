### C++ and CPU profiling
- Compiled C++ file on HEP cluster with `g++ project_pt1.cpp -o project_cpp`, ran file with `./project_cpp`  
- For VTune:  
    - On the GPUs set up environment with `source /opt/intel/oneapi/setvars.sh`
    - Generated the summary and hotspot reports (saved as .csv files) with 
    1. `vtune -collect hotspots -quiet ./project_cpp`
    2. `vtune -report summary -result-dir r001hs -format csv -report-output summary.csv`
    3. `vtune -report hotspots -result-dir r001hs -format csv -report-output hotspots.csv`
- *identify compute intensive parts*

### Porting to CUDA
- From HEP cluster, `ssh g38nXX` onto the GPUs
- Compiled: `nvcc project_pt2.cu -o project_cuda`, ran: `./project_cuda`
- Ran nsys profiler with `nsys profile --stats=true ./project_cuda`
    - Wasn't able to open the GUI, but at least sent the report to cuda_report.txt with `nsys stats report1.nsys-rep > cuda_report.txt`
    - *document/comment on the time spent in each CUDA API call. Also, make note on the time spent on host and device.*
- Switch to managed memory. Compiled and ran with `nvcc project_managed.cu -o managed_cuda` and `./managed_cuda`
    - *run nsys, document/comment on improvements*

### Optimizing performance in CUDA
- *Optimize the performance of your code making use of non-default CUDA streams and shared memory.*
- *Once you have decided on the best approach, profile your application and compare the time spent in each API call and the overall timing of your application with your initial CUDA implementation.*

### Alpaka
