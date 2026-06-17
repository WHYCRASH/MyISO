# Dockerfile for reproducible custom Ubuntu ISO build
FROM ubuntu:24.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies required for downloading, patching, and repacking the ISO
RUN apt-get update && apt-get install -y \
    xorriso \
    wget \
    curl \
    grep \
    sed \
    ca-certificates \
    qemu-system-x86 \
    qemu-utils \
    && rm -rf /var/lib/apt/lists/*

# Set up the workspace directory matching the host path
WORKDIR /home/shane/TheMasterISO

# Run the build-iso.sh script by default
CMD ["/bin/bash", "build-iso.sh"]
