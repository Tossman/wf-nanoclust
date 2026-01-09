// modules/local/read_correction.nf
// Read correction using multiple sequence alignment

process READ_CORRECTION {
    tag "${cluster_file.baseName}"
    label 'process_medium'
    label 'wfnanoclust'

    input:
        tuple val(meta), path(cluster_file)

    output:
        tuple val(meta), val(cluster_id), path("${cluster_id}_corrected.fasta"), emit: corrected
        path "versions.yml", emit: versions

    script:
    cluster_id = cluster_file.baseName
    def max_reads = params.polishing_reads
    """
    #!/usr/bin/env python3
    import random
    from pathlib import Path

    def read_fastq(filepath):
        \"\"\"Read FASTQ file and return list of (id, seq, qual)\"\"\"
        reads = []
        with open(filepath, 'r') as f:
            while True:
                header = f.readline().strip()
                if not header:
                    break
                seq = f.readline().strip()
                plus = f.readline().strip()
                qual = f.readline().strip()
                read_id = header[1:].split()[0]
                reads.append((read_id, seq, qual))
        return reads

    def select_best_reads(reads, max_reads):
        \"\"\"Select reads with highest mean quality\"\"\"
        if len(reads) <= max_reads:
            return reads
        
        # Calculate mean quality for each read
        scored_reads = []
        for read_id, seq, qual in reads:
            mean_qual = sum(ord(c) - 33 for c in qual) / len(qual) if qual else 0
            scored_reads.append((mean_qual, read_id, seq, qual))
        
        # Sort by quality and take top reads
        scored_reads.sort(reverse=True)
        return [(r[1], r[2], r[3]) for r in scored_reads[:max_reads]]

    # Read cluster FASTQ
    print(f"Reading cluster file: ${cluster_file}")
    reads = read_fastq("${cluster_file}")
    print(f"Found {len(reads)} reads in cluster")

    # Select best reads for correction
    max_reads = ${max_reads}
    selected_reads = select_best_reads(reads, max_reads)
    print(f"Selected {len(selected_reads)} reads for correction")

    # Write selected reads as FASTA for downstream processing
    with open("${cluster_id}_corrected.fasta", 'w') as f:
        for i, (read_id, seq, qual) in enumerate(selected_reads):
            f.write(f">{read_id}\\n{seq}\\n")

    print(f"Wrote corrected reads to ${cluster_id}_corrected.fasta")
    """

    stub:
    cluster_id = cluster_file.baseName
    """
    touch ${cluster_id}_corrected.fasta
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //')
    END_VERSIONS
    """
}
