// modules/local/get_abundances.nf
// Calculate taxonomic abundances from classification results

process GET_ABUNDANCES {
    label 'process_low'
    label 'wfnanoclust'

    publishDir "${params.out_dir}/abundances", mode: 'copy'

    input:
        path classification_files

    output:
        path "abundance_*.tsv", emit: abundances
        path "abundance_summary.json", emit: summary

    script:
    """
    #!/usr/bin/env python3
    import csv
    import json
    from collections import defaultdict
    from pathlib import Path

    def load_classifications(files):
        \"\"\"Load all classification results\"\"\"
        classifications = []
        
        for f in files:
            if not Path(f).exists():
                continue
            
            with open(f, 'r') as fh:
                reader = csv.DictReader(fh)
                for row in reader:
                    classifications.append(row)
        
        return classifications

    def calculate_abundances(classifications, level):
        \"\"\"Calculate relative abundances at a taxonomic level\"\"\"
        counts = defaultdict(int)
        total = 0
        
        for c in classifications:
            taxon = c.get(level, 'Unknown')
            if taxon and taxon != 'Unknown' and taxon != 'Unclassified':
                counts[taxon] += 1
                total += 1
        
        # Calculate relative abundances
        abundances = {}
        for taxon, count in counts.items():
            abundances[taxon] = {
                'count': count,
                'relative_abundance': count / total if total > 0 else 0
            }
        
        return abundances, total

    # Get all classification files
    files = "${classification_files}".split()
    print(f"Processing {len(files)} classification files")

    # Load all classifications
    classifications = load_classifications(files)
    print(f"Loaded {len(classifications)} classifications")

    # Calculate abundances at each level
    levels = ['kingdom', 'phylum', 'class', 'order', 'family', 'genus', 'species']
    summary = {'total_clusters': len(classifications)}

    for level in levels:
        abundances, total = calculate_abundances(classifications, level)
        summary[f'{level}_count'] = len(abundances)
        
        # Write TSV file
        output_file = f"abundance_{level}.tsv"
        with open(output_file, 'w') as f:
            f.write(f"{level}\\tcount\\trelative_abundance\\n")
            
            # Sort by abundance (descending)
            sorted_taxa = sorted(abundances.items(), 
                                key=lambda x: x[1]['count'], 
                                reverse=True)
            
            for taxon, data in sorted_taxa:
                f.write(f"{taxon}\\t{data['count']}\\t{data['relative_abundance']:.6f}\\n")
        
        print(f"  {level}: {len(abundances)} unique taxa")

    # Write summary JSON
    with open("abundance_summary.json", 'w') as f:
        json.dump(summary, f, indent=2)

    print("Abundance calculation complete")
    """

    stub:
    """
    touch abundance_genus.tsv
    touch abundance_species.tsv
    touch abundance_summary.json
    """
}
