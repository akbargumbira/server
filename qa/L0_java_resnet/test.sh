#!/bin/bash
# Copyright (c) 2022, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#  * Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#  * Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#  * Neither the name of NVIDIA CORPORATION nor the names of its
#    contributors may be used to endorse or promote products derived
#    from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ``AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
# OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

REPO_VERSION=${NVIDIA_TRITON_SERVER_VERSION}
if [ "$#" -ge 1 ]; then
    REPO_VERSION=$1
fi
if [ -z "$REPO_VERSION" ]; then
    echo -e "Repository version must be specified"
    echo -e "\n***\n*** Test Failed\n***"
    exit 1
fi
if [ ! -z "$TEST_REPO_ARCH" ]; then
    REPO_VERSION=${REPO_VERSION}_${TEST_REPO_ARCH}
fi

# Models
DATADIR=/data/inferenceserver/${REPO_VERSION}

# Create local model repository
mkdir -p models/
cp -r $DATADIR/perf_model_store/resnet50* models/

# Set up test files based on installation instructions
# https://github.com/bytedeco/javacpp-presets/blob/master/tritonserver/README.md
# rm -r javacpp-presets
# git clone https://github.com/bytedeco/javacpp-presets.git
cd javacpp-presets
mvn clean install --projects .,tritonserver
mvn clean install -f platform --projects ../tritonserver/platform -Djavacpp.platform.host
cd ..

MODEL_REPO=`pwd`/models
SAMPLES_REPO=`pwd`/javacpp-presets/tritonserver/samples
BASE_COMMAND="mvn clean compile -f $SAMPLES_REPO exec:java -Djavacpp.platform=linux-x86_64"
source ../common/util.sh

cp Simple.java $SAMPLES_REPO
rm -f *.log
RET=0

# Run with default settings
$BASE_COMMAND -Dexec.args="-r $MODEL_REPO" >>client.log 2>&1
if [ $? -ne 0 ]; then
    RET=1
fi

# TODO: Create one loop with all framework checking

# Check PyTorch passed
if [ `grep -c "PyTorch test passed" client.log` != "1" ]; then
    echo -e "\n***\n*** Failed. Expected 'PyTorch test passed''\n***"
    RET=1
fi

# # Check TensorFlow passed
# if [ `grep -c "TensorFlow test passed" client.log` != "1" ]; then
#     echo -e "\n***\n*** Failed. Expected 'TensorFlow test passed''\n***"
#     RET=1
# fi

# # Check ONNX Runtime passed
# if [ `grep -c "ONNX test passed" client.log` != "1" ]; then
#     echo -e "\n***\n*** Failed. Expected 'ONNX test passed'\n***"
#     RET=1
# fi

if [ $RET -eq 0 ]; then
    echo -e "\n***\n*** Test Passed\n***"
else
    echo -e "\n***\n*** Test FAILED\n***"
fi

exit $RET
