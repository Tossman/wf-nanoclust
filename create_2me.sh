#!/bin/bash
# create_2me.sh - Create 2ME package for EPI2ME Desktop import
# Usage: ./create_2me.sh [version]

set -e

# Configuration
WORKFLOW_NAME="wf-nanoclust"
VERSION="${1:-v1.0.0}"
OUTPUT_FILE="${WORKFLOW_NAME}-${VERSION}.2me"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "Creating 2ME Package for ${WORKFLOW_NAME}"
echo "Version: ${VERSION}"
echo "========================================"

# Create temporary directory
BUILD_DIR=$(mktemp -d)
mkdir -p "${BUILD_DIR}/workflow"
mkdir -p "${BUILD_DIR}/containers"

echo ""
echo "Step 1: Copying workflow files..."
# Copy workflow files
cp -r "${SCRIPT_DIR}/main.nf" "${BUILD_DIR}/workflow/"
cp -r "${SCRIPT_DIR}/nextflow.config" "${BUILD_DIR}/workflow/"
cp -r "${SCRIPT_DIR}/nextflow_schema.json" "${BUILD_DIR}/workflow/"
cp -r "${SCRIPT_DIR}/output_definition.json" "${BUILD_DIR}/workflow/"
cp -r "${SCRIPT_DIR}/modules" "${BUILD_DIR}/workflow/"
cp -r "${SCRIPT_DIR}/lib" "${BUILD_DIR}/workflow/"

# Copy bin directory if exists
if [ -d "${SCRIPT_DIR}/bin" ]; then
    cp -r "${SCRIPT_DIR}/bin" "${BUILD_DIR}/workflow/"
fi

# Copy data directory if exists
if [ -d "${SCRIPT_DIR}/data" ]; then
    cp -r "${SCRIPT_DIR}/data" "${BUILD_DIR}/workflow/"
fi

# Copy test data if exists (small subset)
if [ -d "${SCRIPT_DIR}/test_data" ]; then
    mkdir -p "${BUILD_DIR}/workflow/test_data"
    # Copy only small test files
    find "${SCRIPT_DIR}/test_data" -name "*.fastq" -size -10M -exec cp {} "${BUILD_DIR}/workflow/test_data/" \;
fi

echo "Step 2: Exporting Docker containers..."
# Export Docker container
if docker image inspect "ontresearch/${WORKFLOW_NAME}:${VERSION}" > /dev/null 2>&1; then
    docker save "ontresearch/${WORKFLOW_NAME}:${VERSION}" -o "${BUILD_DIR}/containers/wf-nanoclust.tar"
    echo "  - Exported ontresearch/${WORKFLOW_NAME}:${VERSION}"
elif docker image inspect "ontresearch/${WORKFLOW_NAME}:latest" > /dev/null 2>&1; then
    docker save "ontresearch/${WORKFLOW_NAME}:latest" -o "${BUILD_DIR}/containers/wf-nanoclust.tar"
    echo "  - Exported ontresearch/${WORKFLOW_NAME}:latest"
else
    echo "  WARNING: Docker image not found. Building..."
    cd "${SCRIPT_DIR}/docker"
    docker build -t "ontresearch/${WORKFLOW_NAME}:${VERSION}" .
    docker save "ontresearch/${WORKFLOW_NAME}:${VERSION}" -o "${BUILD_DIR}/containers/wf-nanoclust.tar"
    cd "${SCRIPT_DIR}"
fi

echo "Step 3: Creating manifest..."
# Create manifest
cat > "${BUILD_DIR}/manifest.json" << EOF
{
    "name": "${WORKFLOW_NAME}",
    "version": "${VERSION}",
    "description": "De novo clustering and consensus building for 16S/18S rRNA amplicons from Oxford Nanopore sequencing",
    "author": "EPI2ME Labs",
    "homepage": "https://github.com/epi2me-labs/${WORKFLOW_NAME}",
    "containers": [
        "wf-nanoclust.tar"
    ],
    "entrypoint": "main.nf",
    "nextflow_version": ">=23.04.2",
    "epi2me_desktop_version": ">=25.11"
}
EOF

echo "Step 4: Creating metadata..."
# Create metadata
cat > "${BUILD_DIR}/metadata.json" << EOF
{
    "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "format_version": "2.0",
    "workflow": {
        "name": "${WORKFLOW_NAME}",
        "version": "${VERSION}",
        "git_url": "https://github.com/epi2me-labs/${WORKFLOW_NAME}"
    },
    "dependencies": {
        "python": "3.9",
        "nextflow": ">=23.04.2",
        "blast": "2.14.0",
        "minimap2": "2.26",
        "racon": "1.5.0"
    },
    "tags": [
        "amplicon",
        "16S",
        "18S",
        "metagenomics",
        "clustering",
        "denovo",
        "microbiome"
    ]
}
EOF

echo "Step 5: Creating 2ME archive..."
# Create TAR archive
cd "${BUILD_DIR}"
tar -czf "${SCRIPT_DIR}/${OUTPUT_FILE}" .

# Cleanup
cd "${SCRIPT_DIR}"
rm -rf "${BUILD_DIR}"

echo ""
echo "========================================"
echo "2ME package created successfully!"
echo "Output: ${OUTPUT_FILE}"
echo "Size: $(du -h ${OUTPUT_FILE} | cut -f1)"
echo "========================================"
echo ""
echo "To import into EPI2ME Desktop:"
echo "  1. Open EPI2ME Desktop"
echo "  2. Go to Workflows > Import from file"
echo "  3. Select ${OUTPUT_FILE}"
echo ""
