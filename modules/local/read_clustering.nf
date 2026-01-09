// modules/local/read_clustering.nf
// UMAP dimensionality reduction + HDBSCAN clustering

process READ_CLUSTERING {
    tag "${meta.id}"
    label 'process_clustering'
    label 'wfnanoclust'

    publishDir "${params.out_dir}/clustering", mode: 'copy', pattern: "*.{png,tsv}"

    input:
        tuple val(meta), path(kmer_freqs)

    output:
        tuple val(meta), path("${meta.id}_cluster_assignments.tsv"), emit: clusters
        tuple val(meta), path("${meta.id}_umap_plot.png"), emit: umap_plot
        path "${meta.id}_clustering_stats.json", emit: stats
        path "versions.yml", emit: versions

    script:
    def prefix = meta.id
    def epsilon = params.cluster_sel_epsilon
    def min_cluster = params.min_cluster_size
    """
    #!/usr/bin/env python3
    import pandas as pd
    import numpy as np
    import umap
    import hdbscan
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    import json
    import warnings
    warnings.filterwarnings('ignore')

    print("Loading k-mer frequencies...")
    df = pd.read_csv("${kmer_freqs}")
    
    read_ids = df['read_id'].values
    features = df.drop('read_id', axis=1).values
    
    print(f"Loaded {len(read_ids)} reads with {features.shape[1]} features")
    
    # UMAP dimensionality reduction
    print("Running UMAP dimensionality reduction...")
    reducer = umap.UMAP(
        n_neighbors=15,
        min_dist=0.1,
        n_components=2,
        metric='euclidean',
        random_state=42,
        low_memory=True
    )
    
    embedding = reducer.fit_transform(features)
    print(f"UMAP embedding shape: {embedding.shape}")
    
    # HDBSCAN clustering
    print("Running HDBSCAN clustering...")
    clusterer = hdbscan.HDBSCAN(
        min_cluster_size=${min_cluster},
        cluster_selection_epsilon=${epsilon},
        min_samples=5,
        metric='euclidean',
        cluster_selection_method='eom'
    )
    
    cluster_labels = clusterer.fit_predict(embedding)
    
    # Count clusters (excluding noise labeled as -1)
    unique_clusters = set(cluster_labels) - {-1}
    n_clusters = len(unique_clusters)
    n_noise = sum(1 for l in cluster_labels if l == -1)
    
    print(f"Found {n_clusters} clusters")
    print(f"Noise points: {n_noise} ({100*n_noise/len(cluster_labels):.1f}%)")
    
    # Save cluster assignments
    print("Saving cluster assignments...")
    results_df = pd.DataFrame({
        'read_id': read_ids,
        'cluster': cluster_labels,
        'umap_x': embedding[:, 0],
        'umap_y': embedding[:, 1]
    })
    results_df.to_csv("${prefix}_cluster_assignments.tsv", sep='\\t', index=False)
    
    # Generate UMAP plot
    print("Generating UMAP visualization...")
    plt.figure(figsize=(12, 10))
    
    # Plot noise points first (in gray)
    noise_mask = cluster_labels == -1
    if any(noise_mask):
        plt.scatter(
            embedding[noise_mask, 0],
            embedding[noise_mask, 1],
            c='lightgray',
            s=1,
            alpha=0.5,
            label='Noise'
        )
    
    # Plot clustered points
    cluster_mask = ~noise_mask
    if any(cluster_mask):
        scatter = plt.scatter(
            embedding[cluster_mask, 0],
            embedding[cluster_mask, 1],
            c=cluster_labels[cluster_mask],
            s=3,
            alpha=0.7,
            cmap='Spectral'
        )
        plt.colorbar(scatter, label='Cluster ID')
    
    plt.xlabel('UMAP 1')
    plt.ylabel('UMAP 2')
    plt.title(f'${prefix} - UMAP + HDBSCAN Clustering\\n{n_clusters} clusters identified')
    plt.tight_layout()
    plt.savefig("${prefix}_umap_plot.png", dpi=150, bbox_inches='tight')
    plt.close()
    
    # Save clustering statistics
    cluster_sizes = {}
    for cluster_id in unique_clusters:
        size = sum(1 for l in cluster_labels if l == cluster_id)
        cluster_sizes[int(cluster_id)] = size
    
    stats = {
        'sample': '${prefix}',
        'total_reads': len(read_ids),
        'n_clusters': n_clusters,
        'n_noise': n_noise,
        'noise_fraction': n_noise / len(read_ids),
        'cluster_sizes': cluster_sizes,
        'parameters': {
            'min_cluster_size': ${min_cluster},
            'cluster_sel_epsilon': ${epsilon}
        }
    }
    
    with open("${prefix}_clustering_stats.json", 'w') as f:
        json.dump(stats, f, indent=2)
    
    print("Clustering complete!")
    """

    stub:
    """
    touch ${meta.id}_cluster_assignments.tsv
    touch ${meta.id}_umap_plot.png
    touch ${meta.id}_clustering_stats.json
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //')
        umap: \$(python -c "import umap; print(umap.__version__)")
        hdbscan: \$(python -c "import hdbscan; print(hdbscan.__version__)")
    END_VERSIONS
    """
}
