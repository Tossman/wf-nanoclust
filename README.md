# wf-nanoclust

**De novo clustering and consensus building for 16S/18S rRNA amplicons from Oxford Nanopore sequencing**

[![EPI2ME Compatible](https://img.shields.io/badge/EPI2ME-Compatible-blue)](https://epi2me.nanoporetech.com/)
[![Nextflow](https://img.shields.io/badge/nextflow-%E2%89%A523.04.2-brightgreen.svg)](https://www.nextflow.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## Introduction

wf-nanoclust is an EPI2ME-compatible Nextflow workflow adapted from [NanoCLUST](https://github.com/genomicsITER/NanoCLUST) for species-level analysis of 16S/18S rRNA nanopore sequencing data. It uses UMAP dimensionality reduction combined with HDBSCAN clustering to identify operational taxonomic units (OTUs) de novo, without requiring reference databases for clustering.

### Key Features

- **UMAP + HDBSCAN Clustering**: Unsupervised machine learning for species-level read clustering
- **Consensus Polishing**: Multi-round polishing with Racon for accurate consensus sequences
- **BLAST Classification**: Taxonomic assignment using NCBI 16S/18S databases
- **EPI2ME Desktop Integration**: Full GUI support via the EPI2ME Desktop application
- **Interactive HTML Reports**: Comprehensive reports with UMAP visualizations and abundance plots

### Citation

If you use this workflow, please cite the original NanoCLUST publication:

> Rodríguez-Pérez H, Ciuffreda L, Flores C. **NanoCLUST: a species-level analysis of 16S rRNA nanopore sequencing data.** *Bioinformatics*. 2021;37(11):1600-1601. [doi:10.1093/bioinformatics/btaa900](https://doi.org/10.1093/bioinformatics/btaa900)

---

## Quick Start

### Prerequisites

1. **Nextflow** (≥23.04.2)
   ```bash
   curl -s https://get.nextflow.io | bash
   sudo mv nextflow /usr/local/bin/
   ```

2. **Docker** or **Singularity**
   ```bash
   # Docker installation varies by OS - see https://docs.docker.com/engine/install/
   ```

3. **BLAST Database** (16S_ribosomal_RNA)
   ```bash
   mkdir -p db/taxdb
   wget https://ftp.ncbi.nlm.nih.gov/blast/db/16S_ribosomal_RNA.tar.gz
   tar -xzvf 16S_ribosomal_RNA.tar.gz -C db
   wget https://ftp.ncbi.nlm.nih.gov/blast/db/taxdb.tar.gz
   tar -xzvf taxdb.tar.gz -C db/taxdb
   ```

### Running the Workflow

#### Option 1: Command Line

```bash
# Basic usage
nextflow run epi2me-labs/wf-nanoclust \
    --fastq /path/to/reads.fastq \
    --database /path/to/db/16S_ribosomal_RNA \
    --taxonomy /path/to/db/taxdb \
    -profile standard

# With sample sheet for multiplexed data
nextflow run epi2me-labs/wf-nanoclust \
    --fastq /path/to/barcoded_data/ \
    --sample_sheet sample_sheet.csv \
    --database /path/to/db/16S_ribosomal_RNA \
    --taxonomy /path/to/db/taxdb \
    -profile standard
```

#### Option 2: EPI2ME Desktop

1. Open EPI2ME Desktop
2. Navigate to **Workflows**
3. Import from GitHub: `https://github.com/epi2me-labs/wf-nanoclust`
4. Configure parameters via the GUI
5. Click **Start**

---

## Input Requirements

### FASTQ Input

The workflow accepts:
- Single FASTQ file
- Directory containing FASTQ files
- Barcoded directory structure (barcode01/, barcode02/, etc.)

### Sample Sheet (Optional)

For multiplexed samples, provide a CSV with columns:

| barcode | alias | type |
|---------|-------|------|
| barcode01 | sample_A | test_sample |
| barcode02 | sample_B | test_sample |
| barcode03 | neg_ctrl | negative_control |

### BLAST Database

Download the NCBI 16S ribosomal RNA database:

```bash
# Create database directory
mkdir -p db/taxdb

# Download 16S database
wget https://ftp.ncbi.nlm.nih.gov/blast/db/16S_ribosomal_RNA.tar.gz
tar -xzvf 16S_ribosomal_RNA.tar.gz -C db

# Download taxonomy database
wget https://ftp.ncbi.nlm.nih.gov/blast/db/taxdb.tar.gz
tar -xzvf taxdb.tar.gz -C db/taxdb
```

---

## Parameters

### Input Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `--fastq` | Input FASTQ file(s) or directory | **Required** |
| `--sample_sheet` | Sample sheet CSV for multiplexed data | - |
| `--analyse_unclassified` | Include unclassified reads | false |

### Read Filtering

| Parameter | Description | Default |
|-----------|-------------|---------|
| `--min_read_length` | Minimum read length (bp) | 1400 |
| `--max_read_length` | Maximum read length (bp) | 1700 |
| `--min_read_quality` | Minimum mean Phred quality | 8 |

> **Note**: For 18S rRNA analysis, adjust to `--min_read_length 1700 --max_read_length 2100`

### Clustering Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `--umap_set_size` | Max reads for UMAP clustering | 100000 |
| `--cluster_sel_epsilon` | HDBSCAN cluster distance threshold | 0.5 |
| `--min_cluster_size` | Minimum reads per cluster | 50 |

### Polishing & Classification

| Parameter | Description | Default |
|-----------|-------------|---------|
| `--polishing_reads` | Reads used for consensus polishing | 100 |
| `--database` | Path to BLAST database | **Required** |
| `--taxonomy` | Path to taxonomy database | **Required** |

### Output

| Parameter | Description | Default |
|-----------|-------------|---------|
| `--out_dir` | Output directory | output |

---

## Output Files

```
output/
├── wf-nanoclust-report.html    # Interactive HTML report
├── qc/
│   └── *_qc_stats.tsv          # Quality control statistics
├── clustering/
│   ├── *_cluster_assignments.tsv
│   └── *_umap_plot.png         # UMAP visualization
├── consensus/
│   └── *_consensus.fasta       # Polished consensus sequences
├── classification/
│   └── *_classification.csv    # BLAST results with taxonomy
├── abundances/
│   ├── abundance_genus.tsv
│   ├── abundance_species.tsv
│   └── *.png                   # Abundance plots
└── execution/
    ├── timeline.html
    ├── report.html
    └── trace.txt
```

---

## Profiles

| Profile | Description |
|---------|-------------|
| `standard` | Docker with default resources |
| `singularity` | Singularity containers |
| `test` | Small test dataset |
| `low_memory` | Reduced memory usage (16GB) |
| `high_resolution` | High-diversity samples (64GB) |
| `profile_18S` | 18S rRNA settings |

Example:
```bash
nextflow run epi2me-labs/wf-nanoclust \
    --fastq data/ \
    --database db/16S_ribosomal_RNA \
    --taxonomy db/taxdb \
    -profile standard,low_memory
```

---

## Memory Requirements

The clustering step is memory-intensive. Memory usage scales with `--umap_set_size`:

| umap_set_size | Approximate RAM |
|---------------|-----------------|
| 25,000 | ~8 GB |
| 50,000 | 10-13 GB |
| 100,000 | 32-36 GB |
| 200,000 | ~64 GB |

If you encounter memory errors (exit code 137), reduce `--umap_set_size` or increase available RAM.

---

## Troubleshooting

### Common Issues

**Memory Error (Exit 137)**
```bash
# Reduce clustering dataset size
nextflow run ... --umap_set_size 25000
```

**No Clusters Found**
```bash
# Lower minimum cluster size or increase epsilon
nextflow run ... --min_cluster_size 20 --cluster_sel_epsilon 0.7
```

**BLAST Database Not Found**
```bash
# Ensure paths are absolute
nextflow run ... --database $(pwd)/db/16S_ribosomal_RNA
```

**Container Pull Fails**
```bash
# Pre-pull the container
docker pull ontresearch/wf-nanoclust:v1.0.0
```

---

## Creating 2ME Package (Offline Installation)

For air-gapped systems, create a 2ME package:

```bash
# Build the package
./create_2me.sh v1.0.0

# Transfer to target system
scp wf-nanoclust-v1.0.0.2me user@target:/path/

# Import via EPI2ME Desktop
# Workflows → Import from file → Select .2me file
```

---

## Development

### Building the Container

```bash
cd docker
docker build -t ontresearch/wf-nanoclust:v1.0.0 .
```

### Running Tests

```bash
nextflow run main.nf -profile test,standard
```

### Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Acknowledgements

- Original NanoCLUST authors: Héctor Rodríguez-Pérez, Laura Ciuffreda, Carlos Flores
- EPI2ME Labs team at Oxford Nanopore Technologies
- The Nextflow and nf-core communities

---

## Support

- [GitHub Issues](https://github.com/epi2me-labs/wf-nanoclust/issues)
- [Oxford Nanopore Community Forum](https://community.nanoporetech.com/)
- [EPI2ME Documentation](https://epi2me.nanoporetech.com/)
