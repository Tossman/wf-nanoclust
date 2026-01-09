// modules/local/draft_selection.nf
// Select draft sequence for consensus polishing

process DRAFT_SELECTION {
    tag "${cluster_id}"
    label 'process_low'
    label 'wfnanoclust'

    input:
        tuple val(meta), val(cluster_id), path(corrected_reads)

    output:
        tuple val(meta), val(cluster_id), path("${cluster_id}_draft.fasta"), emit: draft
        path "versions.yml", emit: versions

    script:
    """
    #!/usr/bin/env python3
    from Bio import SeqIO
    from Bio.Seq import Seq
    import statistics

    # Read all sequences
    sequences = list(SeqIO.parse("${corrected_reads}", "fasta"))
    print(f"Loaded {len(sequences)} sequences for draft selection")

    if len(sequences) == 0:
        # Create empty draft if no sequences
        with open("${cluster_id}_draft.fasta", 'w') as f:
            f.write(">empty_draft\\nN\\n")
        print("Warning: No sequences available for draft")
    else:
        # Calculate median length
        lengths = [len(seq.seq) for seq in sequences]
        median_len = statistics.median(lengths)
        
        # Select sequence closest to median length
        best_seq = None
        best_diff = float('inf')
        
        for seq in sequences:
            diff = abs(len(seq.seq) - median_len)
            if diff < best_diff:
                best_diff = diff
                best_seq = seq
        
        # Write draft sequence
        with open("${cluster_id}_draft.fasta", 'w') as f:
            f.write(f">{best_seq.id}_draft\\n{str(best_seq.seq)}\\n")
        
        print(f"Selected draft: {best_seq.id} (length: {len(best_seq.seq)})")
        print(f"Median length: {median_len:.0f}")
    """

    stub:
    """
    touch ${cluster_id}_draft.fasta
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //')
        biopython: \$(python -c "import Bio; print(Bio.__version__)")
    END_VERSIONS
    """
}
