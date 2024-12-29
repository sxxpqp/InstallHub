#!/bin/bash

# Define the version
VERSION="1.12.0-1"

# Define the paths to the .deb packages using the version variable
LIB_NVIDIA_CONTAINER_TOOLS="libnvidia-container-tools_${VERSION}_amd64.deb"
LIB_NVIDIA_CONTAINER="libnvidia-container1_${VERSION}_amd64.deb"
NVIDIA_CONTAINER_RUNTIME="nvidia-container-runtime_3.12.0-1_all.deb"
NVIDIA_CONTAINER_TOOLKIT_BASE="nvidia-container-toolkit-base_${VERSION}_amd64.deb"
NVIDIA_CONTAINER_TOOLKIT="nvidia-container-toolkit_${VERSION}_amd64.deb"
NVIDIA_DOCKER2="nvidia-docker2_2.12.0-1_all.deb"

NVIDIA_DOCKER_URL="https://mirror.cs.uchicago.edu/nvidia-docker/libnvidia-container/stable/ubuntu20.04/amd64/"


if [ "$(command -v curl)" ]; then
    echo "command \"curl\" exists on system"
    curl -o  $LIB_NVIDIA_CONTAINER_TOOLS $NVIDIA_DOCKER_URL$LIB_NVIDIA_CONTAINER_TOOLS
    curl -o  $LIB_NVIDIA_CONTAINER $NVIDIA_DOCKER_URL$LIB_NVIDIA_CONTAINER
    curl -o  $NVIDIA_CONTAINER_RUNTIME $NVIDIA_DOCKER_URL$NVIDIA_CONTAINER_RUNTIME
    curl -o  $NVIDIA_CONTAINER_TOOLKIT_BASE $NVIDIA_DOCKER_URL$NVIDIA_CONTAINER_TOOLKIT_BASE
    curl -o  $NVIDIA_CONTAINER_TOOLKIT $NVIDIA_DOCKER_URL$NVIDIA_CONTAINER_TOOLKIT
    curl -o  $NVIDIA_DOCKER2 $NVIDIA_DOCKER_URL$NVIDIA_DOCKER2
fi

# Install each package using dpkg
dpkg -i *.deb
echo "NVIDIA_CONTAINER部署完成呀"

# Optional: Ensure dependencies are resolved after installation
# apt-get install -f
