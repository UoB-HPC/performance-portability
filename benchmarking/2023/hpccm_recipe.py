"""
HPCCM development container for the C++ HPC tutorial
https://github.com/NVIDIA/hpc-container-maker/
"""
import platform
nvhpc_ver = '23.5'
cuda_ver = '_multi'
gcc_ver = '12'
oneapi_installer = 'https://registrationcenter-download.intel.com/akdlm/IRC_NAS/992857b9-624c-45de-9701-f6445d845359/l_BaseKit_p_2023.2.0.49397.sh'

# llvm_ver = '17'

Stage0 += baseimage(
    image=f'nvcr.io/nvidia/nvhpc:{nvhpc_ver}-devel-cuda{cuda_ver}-ubuntu22.04')

arch = 'x86_64'
if platform.machine() == 'aarch64':
    arch = 'aarch64'

Stage0 += packages(ospackages=[
    'libtbb-dev',  # Required for GCC C++ parallel STL
    'python3', 'python3-pip', 'python-is-python3', 'python3-setuptools', 'python3-dev',
    'nginx', 'zip', 'make', 'build-essential', 'curl',
    'git', 'bc', 'debianutils', 'libnuma1', 'openssh-client', 'wget', 'numactl',
    'ninja-build', 'rsync'

])

# Install GNU and LLVM toolchains and CMake
Stage0 += gnu(version=gcc_ver, extra_repository=True)
# Stage0 += llvm(version=llvm_ver, upstream=True, extra_tools=True, toolset=True)
Stage0 += cmake(eula=True, version='3.24.2')
Stage0 += shell(commands=[
    'set -ex',  # Exit on first error and debug output
    f'wget {oneapi_installer} -O oneapi_installer.sh',
    'chmod +x oneapi_installer.sh',
    './oneapi_installer.sh -a -s --eula accept --components intel.oneapi.lin.dpcpp-cpp-compiler:intel.oneapi.lin.tbb.devel:intel.oneapi.lin.dpl',
])
Stage0 += shell(commands=[
    'set -ex',  # Exit on first error and debug output

    # Configure the HPC SDK toolchain to pick the latest GCC
    f'cd /opt/nvidia/hpc_sdk/Linux_{arch}/{nvhpc_ver}/compilers/bin/',
    'makelocalrc -d . -x .',

    'git clone --depth=1 --branch=release-v3 https://github.com/NVIDIA/NVTX.git',
    'cp -r NVTX/c/include/nvtx3 /usr/include/nvtx3',
    'rm -rf NVTX',
    'cd -',

    # # libc++abi: make sure clang with -stdlib=libc++ can find it
    # f'ln -sf /usr/lib/llvm-{llvm_ver}/lib/libc++abi.so.1 /usr/lib/llvm-{llvm_ver}/lib/libc++abi.so',

    # Install HPC SDK mdspan systemwide:
    f'ln -sf /opt/nvidia/hpc_sdk/Linux_{arch}/{nvhpc_ver}/compilers/include/experimental/mdspan /usr/include/mdspan',
    f'ln -sf /opt/nvidia/hpc_sdk/Linux_{arch}/{nvhpc_ver}/compilers/include/experimental/__p0009_bits /usr/include/__p0009_bits',

])

Stage0 += environment(variables={
    # 'LD_LIBRARY_PATH': f'/usr/lib/llvm-{llvm_ver}/lib:$LD_LIBRARY_PATH',
    # 'LIBRARY_PATH':    f'/usr/lib/llvm-{llvm_ver}/lib:$LIBRARY_PATH',
    # Simplify running HPC-X on systems without InfiniBand
    'OMPI_MCA_coll_hcoll_enable': '0',
    # We do not need VFS; using it from a container in a 'generic' way is not trivial:
    'UCX_VFS_ENABLE': 'n',
    # Allow HPC-X to oversubscribe the CPU with more ranks than cores without using mpirun --oversubscribe
    'OMPI_MCA_rmaps_base_oversubscribe': 'true',
    # Workaround hwloc binding:
    'OMPI_MCA_hwloc_base_binding_policy': 'none',
    # DLI course needs to run as root:
    'OMPI_ALLOW_RUN_AS_ROOT': '1',
    'OMPI_ALLOW_RUN_AS_ROOT_CONFIRM': '1',
})
