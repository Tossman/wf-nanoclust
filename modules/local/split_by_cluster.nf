// modules/local/split_by_cluster.nf
// Split reads by cluster assignment

process SPLIT_BY_CLUSTER {
    tag "${meta.id}"
    label 'process_medium'
    label 'wfnanoclust'

    input:
        tuple val(meta), path(reads)
        tuple val(meta2), path(cluster_assignments)

    output:
        tuple val(meta), path("cluster_*.fastq"), emit: cluster_reads
        path "cluster_summary.tsv", emit: summary

    script:
    def prefix = meta.id
    """
    #!/usr/bin/env python3
    import gzip
    from pathlib import Path
    from collections import defaultdict

    # Read cluster assignments
    print("Loading cluster assignments...")
    read_to_cluster = {}
    with open("${cluster_assignments}", 'r') as f:
        header = f.readline()
        for line in f:
            parts = line.strip().split('\\t')
            read_id = parts[0]
            cluster = int(parts[1])
            read_to_cluster[read_id] = cluster

    print(f"Loaded {len(read_to_cluster)} read assignments")

    # Count clusters
    clusters = set(read_to_cluster.values())
    valid_clusters = [c for c in clusters if c >= 0]  # Exclude noise (-1)
    print(f"Found {len(valid_clusters)} clusters (excluding noise)")

    # Open output files for each cluster
    cluster_files = {}
    cluster_counts = defaultdict(int)

    for cluster in valid_clusters:
        cluster_files[cluster] = open(f"cluster_{cluster}.fastq", 'w')

    # Process input FASTQ
    print("Splitting reads by cluster...")
    input_path = Path("${reads}")
    
    if str(input_path).endswith('.gz'):
        fh = gzip.open(input_path, 'rt')
    else:
        fh = open(input_path, 'r')

    try:
        while True:
            header = fh.readline()
            if not header:
                break
            seq = fh.readline()
            plus = fh.readline()
            qual = fh.readline()
            
            read_id = header[1:].strip().split()[0]
            
            if read_id in read_to_cluster:
                cluster = read_to_cluster[read_id]
                if cluster >= 0:  # Skip noise reads
                    cluster_files[cluster].write(header + seq + plus + qual)
                    cluster_counts[cluster] += 1
    finally:
        fh.close()

    # Close all output files
    for fh in cluster_files.values():
        fh.close()

    # Write summary
    with open("cluster_summary.tsv", 'w') as f:
        f.write("cluster\\tread_count\\n")
        for cluster in sorted(cluster_counts.keys()):
            f.write(f"{cluster}\\t{cluster_counts[cluster]}\\n")

    print(f"Split reads into {len(valid_clusters)} cluster files")
    for cluster, count in sorted(cluster_counts.items()):
        print(f"  Cluster {cluster}: {count} reads")
    """

    stub:
    """
    touch cluster_0.fastq
    touch cluster_summary.tsv
    """
}
