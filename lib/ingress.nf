// lib/ingress.nf
// EPI2ME Standard Data Ingress Module for wf-nanoclust
// Handles FASTQ/BAM input with sample sheet support

import java.nio.file.Path

/**
 * Standard fastq ingress for EPI2ME workflows
 * Handles single files, directories, barcoded directories, and sample sheets
 *
 * @param args Map with keys: input, sample, sample_sheet, analyse_unclassified, stats
 * @return Channel of [meta, reads, stats]
 */
def fastq_ingress(Map args) {
    def input_path = args.input ? file(args.input, checkIfExists: true) : null
    
    if (!input_path) {
        log.error "No input provided. Please specify --fastq parameter."
        return Channel.empty()
    }

    // Handle sample sheet if provided
    if (args.sample_sheet) {
        return process_sample_sheet(args)
    }
    
    // Single file input
    if (input_path.isFile()) {
        return process_single_file(input_path, args)
    }
    
    // Directory input
    if (input_path.isDirectory()) {
        return process_directory(input_path, args)
    }
    
    log.error "Invalid input path: ${args.input}"
    return Channel.empty()
}

/**
 * Process input with sample sheet
 */
def process_sample_sheet(Map args) {
    def sample_sheet = file(args.sample_sheet, checkIfExists: true)
    def input_dir = file(args.input, checkIfExists: true)
    
    return Channel
        .fromPath(sample_sheet)
        .splitCsv(header: true)
        .map { row ->
            def meta = create_meta(row)
            def barcode_dir = file("${input_dir}/${row.barcode}")
            def fastq_files = find_fastq_files(barcode_dir)
            
            if (fastq_files.isEmpty()) {
                log.warn "No FASTQ files found for barcode: ${row.barcode}"
                return null
            }
            
            return tuple(meta, fastq_files, null)
        }
        .filter { it != null }
}

/**
 * Process single FASTQ file
 */
def process_single_file(Path input_file, Map args) {
    def sample_name = args.sample ?: input_file.baseName.replaceAll(/\.(fastq|fq)(\.gz)?$/, '')
    def meta = [
        id: sample_name,
        alias: sample_name,
        barcode: null,
        type: 'test_sample',
        n_seqs: 0
    ]
    
    return Channel.of(tuple(meta, input_file, null))
}

/**
 * Process directory input - detect barcodes or treat as single sample
 */
def process_directory(Path input_dir, Map args) {
    // Check for barcode subdirectories
    def barcode_dirs = []
    input_dir.eachDir { subdir ->
        def name = subdir.name
        if (name =~ /^barcode\d+$/) {
            barcode_dirs << subdir
        } else if (args.analyse_unclassified && name == 'unclassified') {
            barcode_dirs << subdir
        }
    }
    
    if (barcode_dirs.isEmpty()) {
        // No barcodes found - treat as single sample directory
        return process_flat_directory(input_dir, args)
    }
    
    // Process barcoded directories
    return Channel
        .fromPath(barcode_dirs)
        .map { barcode_dir ->
            def meta = [
                id: barcode_dir.name,
                alias: barcode_dir.name,
                barcode: barcode_dir.name,
                type: 'test_sample',
                n_seqs: 0
            ]
            def fastq_files = find_fastq_files(barcode_dir)
            
            if (fastq_files.isEmpty()) {
                log.warn "No FASTQ files found in: ${barcode_dir}"
                return null
            }
            
            return tuple(meta, fastq_files, null)
        }
        .filter { it != null }
}

/**
 * Process flat directory without barcode structure
 */
def process_flat_directory(Path input_dir, Map args) {
    def sample_name = args.sample ?: input_dir.name
    def meta = [
        id: sample_name,
        alias: sample_name,
        barcode: null,
        type: 'test_sample',
        n_seqs: 0
    ]
    
    def fastq_files = find_fastq_files(input_dir)
    
    if (fastq_files.isEmpty()) {
        log.error "No FASTQ files found in: ${input_dir}"
        return Channel.empty()
    }
    
    return Channel.of(tuple(meta, fastq_files, null))
}

/**
 * Create metadata map from sample sheet row
 */
def create_meta(Map row) {
    return [
        id: row.alias ?: row.barcode,
        alias: row.alias ?: row.barcode,
        barcode: row.barcode,
        type: row.type ?: 'test_sample',
        analysis_group: row.analysis_group ?: row.alias ?: row.barcode,
        n_seqs: 0
    ]
}

/**
 * Find all FASTQ files in a directory (recursive)
 */
def find_fastq_files(Path dir) {
    def fastqs = []
    def extensions = ['fastq', 'fq', 'fastq.gz', 'fq.gz']
    
    if (!dir.exists()) {
        return fastqs
    }
    
    dir.eachFileRecurse { file ->
        def name = file.name.toLowerCase()
        if (extensions.any { ext -> name.endsWith(".${ext}") }) {
            fastqs << file
        }
    }
    
    return fastqs
}

/**
 * XAM (BAM/CRAM) ingress - placeholder for future support
 */
def xam_ingress(Map args) {
    log.warn "BAM/CRAM ingress not yet implemented - please use FASTQ input"
    return Channel.empty()
}
