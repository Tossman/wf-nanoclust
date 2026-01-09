// modules/local/kmer_freqs.nf
// K-mer frequency calculation for read clustering

process KMER_FREQS {
    tag "${meta.id}"
    label 'process_medium'
    label 'wfnanoclust'

    input:
        tuple val(meta), path(reads)

    output:
        tuple val(meta), path("${meta.id}_kmer_freqs.csv"), emit: freqs
        path "versions.yml", emit: versions

    script:
    def prefix = meta.id
    def umap_size = params.umap_set_size
    """
    #!/usr/bin/env python3
    import gzip
    import sys
    from collections import defaultdict
    from pathlib import Path
    import random

    def count_kmers(seq, k=5):
        \"\"\"Count k-mer frequencies in a sequence\"\"\"
        kmer_counts = defaultdict(int)
        for i in range(len(seq) - k + 1):
            kmer = seq[i:i+k]
            if 'N' not in kmer:
                kmer_counts[kmer] += 1
        return kmer_counts

    def normalize_kmer_freqs(kmer_counts):
        \"\"\"Normalize k-mer counts to frequencies\"\"\"
        total = sum(kmer_counts.values())
        if total == 0:
            return {}
        return {k: v/total for k, v in kmer_counts.items()}

    def generate_all_kmers(k=5):
        \"\"\"Generate all possible k-mers\"\"\"
        bases = ['A', 'C', 'G', 'T']
        kmers = ['']
        for _ in range(k):
            kmers = [kmer + base for kmer in kmers for base in bases]
        return sorted(kmers)

    # Get all possible 5-mers
    all_kmers = generate_all_kmers(5)
    
    # Read FASTQ file
    reads_data = []
    input_path = Path("${reads}")
    
    if str(input_path).endswith('.gz'):
        fh = gzip.open(input_path, 'rt')
    else:
        fh = open(input_path, 'r')

    try:
        while True:
            header = fh.readline().strip()
            if not header:
                break
            seq = fh.readline().strip()
            plus = fh.readline().strip()
            qual = fh.readline().strip()
            
            read_id = header[1:].split()[0]  # Remove @ and get ID
            reads_data.append((read_id, seq))
    finally:
        fh.close()

    # Subsample if necessary
    umap_size = ${umap_size}
    if len(reads_data) > umap_size:
        random.seed(42)  # For reproducibility
        reads_data = random.sample(reads_data, umap_size)
        print(f"Subsampled to {umap_size} reads for clustering")
    else:
        print(f"Using all {len(reads_data)} reads for clustering")

    # Calculate k-mer frequencies
    print(f"Calculating k-mer frequencies for {len(reads_data)} reads...")
    
    with open("${prefix}_kmer_freqs.csv", 'w') as f:
        # Write header
        f.write("read_id," + ",".join(all_kmers) + "\\n")
        
        for read_id, seq in reads_data:
            kmer_counts = count_kmers(seq, 5)
            kmer_freqs = normalize_kmer_freqs(kmer_counts)
            
            # Write row with frequencies for all k-mers
            freqs = [str(kmer_freqs.get(kmer, 0.0)) for kmer in all_kmers]
            f.write(f"{read_id}," + ",".join(freqs) + "\\n")

    print(f"K-mer frequencies written to ${prefix}_kmer_freqs.csv")
    """

    stub:
    """
    touch ${meta.id}_kmer_freqs.csv
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //')
    END_VERSIONS
    """
}
