# Changelog

All notable changes to wf-nanoclust will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v1.0.0] - 2026-01-09

### Added

- Initial EPI2ME-compatible release adapted from NanoCLUST
- Full DSL2 conversion from original DSL1 workflow
- `nextflow_schema.json` for EPI2ME Desktop GUI integration
- `output_definition.json` for standardized output specifications
- EPI2ME-style `lib/ingress.nf` module for sample handling
- Support for sample sheets with barcode-to-alias mapping
- Interactive HTML report generation with:
  - Quality control summary
  - UMAP clustering visualizations
  - Taxonomic abundance plots
  - Classification tables
- Multiple execution profiles:
  - `standard` - Docker with default resources
  - `singularity` - Singularity container support
  - `low_memory` - Reduced memory requirements
  - `high_resolution` - High-diversity sample analysis
  - `profile_18S` - 18S rRNA settings
- 2ME package creation script for offline installation
- Comprehensive documentation

### Changed

- Converted all processes from DSL1 to DSL2 modular structure
- Reorganized directory structure to EPI2ME standards
- Parameter naming conventions aligned with EPI2ME workflows
- Container strategy updated to single multi-purpose container
- Output directory structure standardized

### Technical Details

- Minimum Nextflow version: 23.04.2
- Container: ontresearch/wf-nanoclust:v1.0.0
- Compatible with EPI2ME Desktop 25.11+

---

## Pre-EPI2ME Adaptation

For the original NanoCLUST changelog, see:
https://github.com/genomicsITER/NanoCLUST/blob/master/CHANGELOG.md
