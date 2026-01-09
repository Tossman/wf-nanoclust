// modules/local/consensus_classification.nf
// BLAST-based taxonomic classification of consensus sequences

process CONSENSUS_CLASSIFICATION {
    tag "${cluster_id}"
    label 'process_medium'
    label 'wfnanoclust'

    publishDir "${params.out_dir}/classification", mode: 'copy', pattern: "*.csv"

    input:
        tuple val(meta), val(cluster_id), path(consensus)
        path database
        path taxonomy

    output:
        tuple val(meta), val(cluster_id), path("${cluster_id}_classification.csv"), emit: results
        path "versions.yml", emit: versions

    script:
    def threads = task.cpus
    """
    #!/bin/bash
    set -e

    # Check if consensus is valid
    if [ ! -s ${consensus} ]; then
        echo "Empty consensus, skipping classification"
        echo "cluster_id,read_count,taxid,scientific_name,percent_identity,alignment_length,evalue,kingdom,phylum,class,order,family,genus,species" > ${cluster_id}_classification.csv
        echo "${cluster_id},0,0,Unclassified,0,0,0,Unknown,Unknown,Unknown,Unknown,Unknown,Unknown,Unknown" >> ${cluster_id}_classification.csv
        exit 0
    fi

    # Set BLASTDB environment variable
    export BLASTDB="${taxonomy}"

    # Run BLAST
    echo "Running BLAST classification for ${cluster_id}..."
    
    blastn -query ${consensus} \
           -db ${database} \
           -out ${cluster_id}_blast.txt \
           -outfmt "6 qseqid sseqid staxids sscinames pident length evalue bitscore" \
           -max_target_seqs 5 \
           -num_threads ${threads} \
           -evalue 1e-10 || {
        echo "BLAST failed, creating empty result"
        echo "cluster_id,read_count,taxid,scientific_name,percent_identity,alignment_length,evalue,kingdom,phylum,class,order,family,genus,species" > ${cluster_id}_classification.csv
        echo "${cluster_id},0,0,Unclassified,0,0,0,Unknown,Unknown,Unknown,Unknown,Unknown,Unknown,Unknown" >> ${cluster_id}_classification.csv
        exit 0
    }

    # Parse BLAST results
    python3 << 'EOF'
import csv
import os

def parse_blast_results(blast_file, cluster_id):
    \"\"\"Parse BLAST results and return best hit\"\"\"
    results = []
    
    if not os.path.exists(blast_file) or os.path.getsize(blast_file) == 0:
        return None
    
    with open(blast_file, 'r') as f:
        for line in f:
            parts = line.strip().split('\\t')
            if len(parts) >= 8:
                result = {
                    'query': parts[0],
                    'subject': parts[1],
                    'taxid': parts[2].split(';')[0] if parts[2] else '0',
                    'sciname': parts[3].split(';')[0] if parts[3] else 'Unknown',
                    'pident': float(parts[4]),
                    'length': int(parts[5]),
                    'evalue': float(parts[6]) if parts[6] else 0,
                    'bitscore': float(parts[7])
                }
                results.append(result)
    
    if not results:
        return None
    
    # Return best hit (first one, already sorted by bitscore by BLAST)
    return results[0]

def get_taxonomy_from_name(sciname):
    \"\"\"Extract taxonomic levels from scientific name (simplified)\"\"\"
    # This is a simplified version - full implementation would use NCBI taxonomy
    parts = sciname.split()
    
    taxonomy = {
        'kingdom': 'Bacteria',  # Default assumption for 16S
        'phylum': 'Unknown',
        'class': 'Unknown',
        'order': 'Unknown',
        'family': 'Unknown',
        'genus': parts[0] if parts else 'Unknown',
        'species': ' '.join(parts[:2]) if len(parts) >= 2 else 'Unknown'
    }
    
    return taxonomy

# Parse results
cluster_id = "${cluster_id}"
blast_file = "${cluster_id}_blast.txt"
output_file = "${cluster_id}_classification.csv"

best_hit = parse_blast_results(blast_file, cluster_id)

# Write output
with open(output_file, 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(['cluster_id', 'read_count', 'taxid', 'scientific_name', 
                     'percent_identity', 'alignment_length', 'evalue',
                     'kingdom', 'phylum', 'class', 'order', 'family', 'genus', 'species'])
    
    if best_hit:
        taxonomy = get_taxonomy_from_name(best_hit['sciname'])
        writer.writerow([
            cluster_id, 0, best_hit['taxid'], best_hit['sciname'],
            best_hit['pident'], best_hit['length'], best_hit['evalue'],
            taxonomy['kingdom'], taxonomy['phylum'], taxonomy['class'],
            taxonomy['order'], taxonomy['family'], taxonomy['genus'], taxonomy['species']
        ])
        print(f"Classification: {best_hit['sciname']} ({best_hit['pident']:.1f}% identity)")
    else:
        writer.writerow([
            cluster_id, 0, 0, 'Unclassified', 0, 0, 0,
            'Unknown', 'Unknown', 'Unknown', 'Unknown', 'Unknown', 'Unknown', 'Unknown'
        ])
        print("No classification found")

EOF

    # Clean up
    rm -f ${cluster_id}_blast.txt
    
    echo "Classification complete for ${cluster_id}"
    """

    stub:
    """
    touch ${cluster_id}_classification.csv
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        blastn: \$(blastn -version 2>&1 | head -1 | sed 's/blastn: //')
    END_VERSIONS
    """
}
