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
- Compiled: `nvcc first_cuda.cu -o first_cuda`, ran: `./first_cuda`
- Ran nsys profiler with `nsys profile --stats=true ./first_cuda`
    - Wasn't able to open the GUI, but at least sent the report to first_cuda_report.txt with `nsys stats report1.nsys-rep > first_cuda_report.txt`
    - *document/comment on the time spent in each CUDA API call. Also, make note on the time spent on host and device.*
- Switch to managed memory. Compiled and ran with `nvcc managed_cuda.cu -o managed_cuda` and `./managed_cuda`
- Ran nsys profiler with `nsys profile --stats=true ./managed_cuda`, sent the report to managed_cuda_report.txt with `nsys stats report3.nsys-rep > managed_cuda_report.txt`
    - *document/comment on improvements*

### Optimizing performance in CUDA
- Compiled and ran with `nvcc stream-share_cuda.cu -o stream-share_cuda` and `./stream-share_cuda`
- Ran nsys profiler with `nsys profile --stats=true ./stream-share_cuda` and sent the report to cuda_report.txt with `nsys stats report4.nsys-rep > ss_cuda_report.txt`
    - *compare the time spent in each API call and the overall timing of your application with your initial CUDA implementation.*

### Alpaka
- *Re-write your application making use of the Alpaka portability library.*
- *Describe the steps you had to follow to re-write your code.*

