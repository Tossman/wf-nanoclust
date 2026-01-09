// modules/local/qc_filter.nf
// Quality control and read filtering process

process QC_FILTER {
    tag "${meta.id}"
    label 'process_medium'
    label 'wfnanoclust'

    publishDir "${params.out_dir}/qc", mode: 'copy', pattern: "*.{tsv,json}"

    input:
        tuple val(meta), path(reads), val(stats)

    output:
        tuple val(meta), path("${meta.id}_filtered.fastq.gz"), emit: reads
        tuple val(meta), path("${meta.id}_qc_stats.tsv"), emit: stats
        path "versions.yml", emit: versions

    script:
    def prefix = meta.id
    def min_len = params.min_read_length
    def max_len = params.max_read_length
    def min_qual = params.min_read_quality
    """
    #!/usr/bin/env python3
    import gzip
    import sys
    from pathlib import Path

    def phred_to_quality(qual_string):
        \"\"\"Convert Phred quality string to mean quality score\"\"\"
        if not qual_string:
            return 0
        qualities = [ord(c) - 33 for c in qual_string]
        return sum(qualities) / len(qualities)

    def process_fastq(input_files, output_file, min_len, max_len, min_qual):
        stats = {
            'total_reads': 0,
            'passed_reads': 0,
            'failed_length': 0,
            'failed_quality': 0,
            'total_bases': 0,
            'passed_bases': 0
        }
        
        # Handle multiple input files
        if isinstance(input_files, str):
            input_files = [input_files]
        
        with gzip.open(output_file, 'wt') as out_fh:
            for input_file in input_files:
                input_path = Path(input_file)
                
                # Open file (handle gzipped or plain)
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
                        
                        stats['total_reads'] += 1
                        stats['total_bases'] += len(seq)
                        
                        # Length filter
                        if len(seq) < min_len or len(seq) > max_len:
                            stats['failed_length'] += 1
                            continue
                        
                        # Quality filter
                        mean_qual = phred_to_quality(qual)
                        if mean_qual < min_qual:
                            stats['failed_quality'] += 1
                            continue
                        
                        # Write passing read
                        out_fh.write(f"{header}\\n{seq}\\n{plus}\\n{qual}\\n")
                        stats['passed_reads'] += 1
                        stats['passed_bases'] += len(seq)
                        
                finally:
                    fh.close()
        
        return stats

    # Get input files
    input_files = "${reads}".split()
    
    # Process reads
    stats = process_fastq(
        input_files,
        "${prefix}_filtered.fastq.gz",
        ${min_len},
        ${max_len},
        ${min_qual}
    )
    
    # Write stats
    with open("${prefix}_qc_stats.tsv", 'w') as f:
        f.write("sample\\ttotal_reads\\tpassed_reads\\tfailed_length\\tfailed_quality\\ttotal_bases\\tpassed_bases\\tpass_rate\\n")
        pass_rate = (stats['passed_reads'] / stats['total_reads'] * 100) if stats['total_reads'] > 0 else 0
        f.write(f"${prefix}\\t{stats['total_reads']}\\t{stats['passed_reads']}\\t{stats['failed_length']}\\t{stats['failed_quality']}\\t{stats['total_bases']}\\t{stats['passed_bases']}\\t{pass_rate:.2f}\\n")

    print(f"QC Complete: {stats['passed_reads']}/{stats['total_reads']} reads passed ({stats['passed_reads']/stats['total_reads']*100:.1f}%)")
    """

    stub:
    """
    touch ${meta.id}_filtered.fastq.gz
    touch ${meta.id}_qc_stats.tsv
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //')
    END_VERSIONS
    """
}
