# wf-nanoclust Deployment Guide

This guide provides step-by-step instructions for deploying the wf-nanoclust workflow to the EPI2ME platform.

## Table of Contents

1. [Repository Structure](#repository-structure)
2. [Building the Docker Container](#building-the-docker-container)
3. [Local Testing](#local-testing)
4. [GitHub Deployment](#github-deployment)
5. [2ME Package Creation](#2me-package-creation)
6. [EPI2ME Desktop Import](#epi2me-desktop-import)
7. [Troubleshooting](#troubleshooting)

---

## Repository Structure

```
wf-nanoclust/
├── main.nf                     # Main workflow entry point (DSL2)
├── nextflow.config             # Nextflow configuration
├── nextflow_schema.json        # Parameter schema for EPI2ME GUI
├── output_definition.json      # Output file specifications
├── README.md                   # Documentation
├── CHANGELOG.md                # Version history
├── LICENSE                     # MIT License
├── create_2me.sh               # 2ME package creation script
├── .gitignore                  # Git ignore rules
│
├── lib/                        # Shared library modules
│   ├── ingress.nf              # EPI2ME-style data ingress
│   └── common.nf               # Utility functions
│
├── modules/                    # Process modules
│   └── local/
│       ├── qc_filter.nf        # Quality control
│       ├── kmer_freqs.nf       # K-mer frequency calculation
│       ├── read_clustering.nf  # UMAP + HDBSCAN clustering
│       ├── split_by_cluster.nf # Split reads by cluster
│       ├── read_correction.nf  # Read correction
│       ├── draft_selection.nf  # Draft sequence selection
│       ├── racon_pass.nf       # Racon polishing
│       ├── medaka_pass.nf      # Final polishing
│       ├── consensus_classification.nf # BLAST classification
│       ├── get_abundances.nf   # Abundance calculation
│       ├── plot_abundances.nf  # Abundance visualization
│       └── make_report.nf      # HTML report generation
│
├── docker/                     # Container definitions
│   ├── Dockerfile              # Main container
│   └── docker-compose.yml      # Development setup
│
├── data/                       # Static data files
│   ├── OPTIONAL_FILE           # Nextflow placeholder
│   └── sample_sheet_template.csv
│
├── test_data/                  # Test datasets
│
├── conf/                       # Additional configs (optional)
│
└── .github/
    └── workflows/
        └── ci.yml              # CI/CD pipeline
```

---

## Building the Docker Container

### Prerequisites

- Docker installed and running
- At least 10GB free disk space

### Build Steps

```bash
# Navigate to workflow directory
cd wf-nanoclust

# Build the container
cd docker
docker build -t ontresearch/wf-nanoclust:v1.0.0 .

# Tag as latest
docker tag ontresearch/wf-nanoclust:v1.0.0 ontresearch/wf-nanoclust:latest

# Verify build
docker images | grep wf-nanoclust
```

### Push to Docker Hub (Optional)

```bash
# Login to Docker Hub
docker login

# Push images
docker push ontresearch/wf-nanoclust:v1.0.0
docker push ontresearch/wf-nanoclust:latest
```

---

## Local Testing

### Download Test Data

```bash
# Create test data directory
mkdir -p test_data

# Download sample FASTQ (use NanoCLUST test data)
wget -O test_data/mock_community.fastq \
    https://github.com/genomicsITER/NanoCLUST/raw/master/test_datasets/mock4_run3bc08_5000.fastq
```

### Download BLAST Database

```bash
# Create database directory
mkdir -p db/taxdb

# Download 16S database
wget https://ftp.ncbi.nlm.nih.gov/blast/db/16S_ribosomal_RNA.tar.gz
tar -xzvf 16S_ribosomal_RNA.tar.gz -C db
rm 16S_ribosomal_RNA.tar.gz

# Download taxonomy database
wget https://ftp.ncbi.nlm.nih.gov/blast/db/taxdb.tar.gz
tar -xzvf taxdb.tar.gz -C db/taxdb
rm taxdb.tar.gz
```

### Run Test

```bash
# Quick test with minimal resources
nextflow run main.nf \
    -profile standard \
    --fastq test_data/mock_community.fastq \
    --database $(pwd)/db/16S_ribosomal_RNA \
    --taxonomy $(pwd)/db/taxdb \
    --out_dir test_output \
    --umap_set_size 5000 \
    --min_cluster_size 20 \
    --polishing_reads 20

# Check outputs
ls -la test_output/
cat test_output/wf-nanoclust-report.html | head -100
```

### Validate Schema

```bash
# Check JSON validity
python -m json.tool nextflow_schema.json > /dev/null && echo "Schema valid"

# Test help message
nextflow run main.nf --help
```

---

## GitHub Deployment

### Method 1: GitHub Import (Recommended for Online Use)

1. **Create GitHub Repository**
   ```bash
   git init
   git remote add origin https://github.com/YOUR-USERNAME/wf-nanoclust.git
   ```

2. **Commit and Push**
   ```bash
   git add .
   git commit -m "Initial wf-nanoclust EPI2ME adaptation"
   git tag v1.0.0
   git push origin main --tags
   ```

3. **Import in EPI2ME Desktop**
   - Open EPI2ME Desktop
   - Navigate to **Workflows** → **Import workflow**
   - Enter: `https://github.com/YOUR-USERNAME/wf-nanoclust`
   - Click **Import**

### Method 2: Fork to epi2me-labs (Official ONT Workflows)

Contact Oxford Nanopore for inclusion in the official epi2me-labs organization.

---

## 2ME Package Creation

### Overview

A 2ME package bundles the workflow, containers, and metadata into a single file for offline installation.

### Create Package

```bash
# Make script executable
chmod +x create_2me.sh

# Create package
./create_2me.sh v1.0.0

# Output: wf-nanoclust-v1.0.0.2me
```

### Package Contents

```
wf-nanoclust-v1.0.0.2me/
├── workflow/           # Nextflow files
│   ├── main.nf
│   ├── nextflow.config
│   ├── nextflow_schema.json
│   ├── output_definition.json
│   ├── modules/
│   └── lib/
├── containers/         # Docker images (tar)
│   └── wf-nanoclust.tar
├── manifest.json       # Package metadata
└── metadata.json       # Build information
```

### Transfer to Air-Gapped System

```bash
# Copy to USB drive
cp wf-nanoclust-v1.0.0.2me /media/usb/

# Or SCP to remote system
scp wf-nanoclust-v1.0.0.2me user@target:/path/to/workflows/
```

---

## EPI2ME Desktop Import

### From GitHub

1. Open EPI2ME Desktop
2. Go to **Workflows** tab
3. Click **+ Import Workflow**
4. Select **From GitHub URL**
5. Enter: `https://github.com/YOUR-USERNAME/wf-nanoclust`
6. Click **Import**
7. Wait for container download

### From 2ME File

1. Open EPI2ME Desktop
2. Go to **Workflows** tab
3. Click **+ Import Workflow**
4. Select **From File**
5. Browse to `wf-nanoclust-v1.0.0.2me`
6. Click **Import**
7. Containers will be extracted automatically

### Verify Import

After import, the workflow should appear in your workflow list with:
- ✅ Schema-driven parameter GUI
- ✅ Help text for each parameter
- ✅ Input file browser
- ✅ Profile selection

---

## Troubleshooting

### Container Issues

**Error: Cannot pull image**
```bash
# Solution: Pre-pull container
docker pull ontresearch/wf-nanoclust:v1.0.0

# Or build locally
cd docker && docker build -t ontresearch/wf-nanoclust:v1.0.0 .
```

**Error: Container not found after 2ME import**
```bash
# Load containers manually
cd /path/to/2me/extracted/containers
docker load -i wf-nanoclust.tar
```

### Workflow Issues

**Error: Schema validation failed**
```bash
# Validate schema
python -m json.tool nextflow_schema.json

# Check for trailing commas, missing quotes, etc.
```

**Error: Cannot find module**
```bash
# Ensure lib/ directory exists and contains ingress.nf
ls lib/
# Should show: ingress.nf common.nf
```

### EPI2ME Desktop Issues

**Workflow not appearing**
- Ensure nextflow_schema.json is valid JSON
- Check that main.nf has `nextflow.enable.dsl = 2`
- Verify manifest section in nextflow.config

**Parameters not showing**
- Check nextflow_schema.json definitions
- Ensure all required fields (type, title, description) are present

### Database Issues

**BLAST database not found**
```bash
# Use absolute paths
--database /absolute/path/to/db/16S_ribosomal_RNA

# Verify database files exist
ls -la /path/to/db/16S_ribosomal_RNA.*
```

---

## Verification Checklist

Before deployment, verify:

- [ ] `main.nf` starts with `nextflow.enable.dsl = 2`
- [ ] `nextflow.config` contains manifest section
- [ ] `nextflow_schema.json` is valid JSON
- [ ] `output_definition.json` is valid JSON
- [ ] All modules exist in `modules/local/`
- [ ] `lib/ingress.nf` exists
- [ ] Docker container builds successfully
- [ ] Test run completes without errors
- [ ] HTML report generates correctly
- [ ] 2ME package creates without errors

---

## Support

- **Issues**: https://github.com/epi2me-labs/wf-nanoclust/issues
- **Community**: https://community.nanoporetech.com/
- **EPI2ME Docs**: https://epi2me.nanoporetech.com/
