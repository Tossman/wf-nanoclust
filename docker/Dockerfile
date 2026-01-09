# Dockerfile for wf-nanoclust
# EPI2ME Compatible Container
# All dependencies in a single multi-purpose container

FROM python:3.9-slim-bullseye

LABEL maintainer="EPI2ME Labs <epi2me-labs@nanoporetech.com>"
LABEL description="wf-nanoclust - De novo 16S/18S rRNA clustering and classification"
LABEL version="1.0.0"

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    wget \
    curl \
    zlib1g-dev \
    libbz2-dev \
    liblzma-dev \
    libncurses5-dev \
    libncursesw5-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libffi-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install minimap2
RUN wget -qO- https://github.com/lh3/minimap2/releases/download/v2.26/minimap2-2.26_x64-linux.tar.bz2 | tar -xjf - \
    && mv minimap2-2.26_x64-linux/minimap2 /usr/local/bin/ \
    && rm -rf minimap2-2.26_x64-linux

# Install racon
RUN git clone --recursive https://github.com/lbcb-sci/racon.git \
    && cd racon \
    && mkdir build && cd build \
    && cmake -DCMAKE_BUILD_TYPE=Release .. \
    && make -j$(nproc) \
    && cp bin/racon /usr/local/bin/ \
    && cd ../.. && rm -rf racon

# Install BLAST+
RUN wget -qO- https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.14.0/ncbi-blast-2.14.0+-x64-linux.tar.gz | tar -xzf - \
    && mv ncbi-blast-2.14.0+/bin/* /usr/local/bin/ \
    && rm -rf ncbi-blast-2.14.0+

# Install Python packages
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir \
    numpy==1.24.3 \
    pandas==2.0.3 \
    scipy==1.11.1 \
    scikit-learn==1.3.0 \
    biopython==1.81 \
    matplotlib==3.7.2 \
    seaborn==0.12.2 \
    umap-learn==0.5.3 \
    hdbscan==0.8.29 \
    pysam==0.21.0 \
    pyfastx==0.8.4 \
    numba==0.57.1

# Set environment variables
ENV PYTHONNOUSERSITE=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Create working directory
WORKDIR /data

# Default command
CMD ["/bin/bash"]
