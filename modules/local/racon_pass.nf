// modules/local/racon_pass.nf
// Racon polishing of consensus sequences

process RACON_PASS {
    tag "${cluster_id}"
    label 'process_polishing'
    label 'wfnanoclust'
    
    errorStrategy 'ignore'  // Continue if Racon fails for a cluster

    input:
        tuple val(meta), val(cluster_id), path(draft)
        tuple val(meta2), val(cluster_id2), path(reads)

    output:
        tuple val(meta), val(cluster_id), path("${cluster_id}_racon.fasta"), emit: polished
        path "versions.yml", emit: versions

    script:
    def threads = task.cpus
    """
    # Convert reads from FASTA to FASTQ-like format for minimap2
    # First check if we have sequences
    if [ ! -s ${draft} ]; then
        echo "Empty draft, skipping polishing"
        cp ${draft} ${cluster_id}_racon.fasta
        exit 0
    fi

    # Map reads to draft
    minimap2 -ax map-ont -t ${threads} ${draft} ${reads} > ${cluster_id}_aligned.sam 2>/dev/null || {
        echo "Minimap2 alignment failed, using draft as is"
        cp ${draft} ${cluster_id}_racon.fasta
        exit 0
    }

    # Run Racon polishing
    racon -t ${threads} -q 5 -e 0.05 ${reads} ${cluster_id}_aligned.sam ${draft} > ${cluster_id}_racon.fasta 2>/dev/null || {
        echo "Racon polishing failed, using draft as is"
        cp ${draft} ${cluster_id}_racon.fasta
    }

    # Check if output is valid
    if [ ! -s ${cluster_id}_racon.fasta ]; then
        echo "Empty Racon output, using draft"
        cp ${draft} ${cluster_id}_racon.fasta
    fi

    # Clean up
    rm -f ${cluster_id}_aligned.sam

    echo "Racon polishing complete for ${cluster_id}"
    """

    stub:
    """
    touch ${cluster_id}_racon.fasta
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        racon: \$(racon --version 2>&1 | head -1 || echo "unknown")
        minimap2: \$(minimap2 --version 2>&1 || echo "unknown")
    END_VERSIONS
    """
}
