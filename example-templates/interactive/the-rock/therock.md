# TheRock Usage Guide on OSSCI

The OSSCI Fleet aims to provide central infrastructure to enable developer access to support AIG’s GPU software development, leveraging our in-house GPU as a Service (GPUaaS) platform.
We hope that this infrastructure will serve as the foundation for AMD's AI development workflow, supporting both internal teams and external contributors.
This guide covers how to build and test [TheRock](https://github.com/ROCm/TheRock), a lightweight open source build platform for HIP and ROCm, using the OSSCI platform.

# OSSCI VSCode Setup

Please follow [VSCode Setup Instructions](../vscode/README.md) to setup an interactive VSCode session.

# TheRock

To build and install TheRock, there are three easy to use options available.

## Prerequisites

```bash
# Install Ubuntu dependencies
sudo apt update
sudo apt install gfortran git git-lfs ninja-build cmake g++ pkg-config xxd patchelf automake libtool python3-venv python3-dev libegl1-mesa-dev wget
```

## Option 1: Build From Source (Preferred for ROCm Developers)

```bash
# Clone the repository
git clone https://github.com/ROCm/TheRock.git
cd TheRock

# Init python virtual environment and install python dependencies
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# Download submodules and apply patches
python ./build_tools/fetch_sources.py

# To build ROCm/HIP
cmake -B build -GNinja . -DTHEROCK_AMDGPU_FAMILIES=gfx942
cmake --build build
```

Not all family and targets are currently supported. See [therock_amdgpu_targets.cmake](https://github.com/ROCm/TheRock/blob/main/cmake/therock_amdgpu_targets.cmake) file for available options.

### Validation

Tests of the integrity of the build are enabled by default and can be run
with ctest:

```bash
ctest --test-dir build
```

Test basic functionality of TheRock build:

```bash
./build/dist/rocm/bin/rocm-smi
./build/dist/rocm/bin/rocminfo
./build/dist/rocm/bin/test_hip_api
```

### Daily Devlopment

If interested in using TheRock as a development environment for devloping ROCm compoments, please refer to [development_guide.md](https://github.com/ROCm/TheRock/blob/main/docs/development/development_guide.md)

## Option 2: Install TheRock Python Packages

TheRock provides several Python packages which together form the complete ROCm SDK.

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install \
  --index-url https://d2awnip2yjpvqn.cloudfront.net/v2/gfx94X-dcgpu/ \
  rocm[libraries,devel]
```

### Validation

The rocm-sdk tool can be used to inspect and test the installation:

```bash
rocm-sdk targets
rocm-sdk test
```

Test basic functionality:

```bash
rocm-smi
rocminfo
```

## Option 3: Install TheRock From Tarball

Standalone "ROCm SDK tarballs" are assembled from the same
[artifacts](https://github.com/ROCm/TheRock/blob/main/docs/development/artifacts.md) as the Python packages which can be
installed using pip, without the additional wrapper Python wheels or utility scripts.
View latest nightly artifacts here: https://therock-nightly-tarball.s3.amazonaws.com/

```bash
mkdir therock-tarball && cd therock-tarball
# For example...
wget https://therock-nightly-tarball.s3.us-east-2.amazonaws.com/therock-dist-linux-gfx94X-dcgpu-7.0.0rc20250729.tar.gz

mkdir install
tar -xf *.tar.gz -C install
```

### Validation

After installing (downloading and extracting) a tarball, you can test it by
running programs from the `bin/` directory:

```bash
ls install
# bin  include  lib  libexec  llvm  share

# Now test some of the installed tools:
./install/bin/rocminfo
./install/bin/rocm-smi
./install/bin/test_hip_api
```
