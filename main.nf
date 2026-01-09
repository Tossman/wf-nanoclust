#!/usr/bin/env nextflow

/*
========================================================================================
    wf-nanoclust - EPI2ME Compatible NanoCLUST Workflow
========================================================================================
    De novo clustering and consensus building for 16S/18S rRNA amplicons
    Adapted from NanoCLUST (https://github.com/genomicsITER/NanoCLUST)
    
    EPI2ME Labs adaptation by: [Your Name]
    Original NanoCLUST authors: Rodríguez-Pérez H, Ciuffreda L, Flores C
    
    Citation:
    Rodríguez-Pérez H, Ciuffreda L, Flores C. NanoCLUST: a species-level analysis 
    of 16S rRNA nanopore sequencing data. Bioinformatics. 2021;37(11):1600-1601.
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

// Import ingress modules
include { fastq_ingress } from './lib/ingress'
include { getParams } from './lib/common'

// Import local modules
include { QC_FILTER } from './modules/local/qc_filter'
include { KMER_FREQS } from './modules/local/kmer_freqs'
include { READ_CLUSTERING } from './modules/local/read_clustering'
include { SPLIT_BY_CLUSTER } from './modules/local/split_by_cluster'
include { READ_CORRECTION } from './modules/local/read_correction'
include { DRAFT_SELECTION } from './modules/local/draft_selection'
include { RACON_PASS } from './modules/local/racon_pass'
include { MEDAKA_PASS } from './modules/local/medaka_pass'
include { CONSENSUS_CLASSIFICATION } from './modules/local/consensus_classification'
include { GET_ABUNDANCES } from './modules/local/get_abundances'
include { PLOT_ABUNDANCES } from './modules/local/plot_abundances'
include { MAKE_REPORT } from './modules/local/make_report'

// Workflow version
def workflow_version = "v1.0.0"

// Optional file placeholder
OPTIONAL_FILE = file("$projectDir/data/OPTIONAL_FILE")


/*
========================================================================================
    PROCESSES FOR VERSION COLLECTION AND OUTPUT
========================================================================================
*/

process getVersions {
    label 'wfnanoclust'
    cpus 1

    output:
        path "versions.txt"
    
    script:
    """
    python --version 2>&1 | sed 's/Python /python,/' > versions.txt
    echo "umap-learn,0.5.3" >> versions.txt
    echo "hdbscan,0.8.29" >> versions.txt
    echo "biopython,1.79" >> versions.txt
    echo "medaka,1.7.2" >> versions.txt
    racon --version 2>&1 | head -1 | sed 's/^/racon,/' >> versions.txt || echo "racon,unknown" >> versions.txt
    minimap2 --version 2>&1 | sed 's/^/minimap2,/' >> versions.txt || echo "minimap2,unknown" >> versions.txt
    blastn -version 2>&1 | head -1 | sed 's/blastn: /blastn,/' >> versions.txt || echo "blastn,unknown" >> versions.txt
    """
}

process output {
    // Publish inputs to output directory
    label 'wfnanoclust'
    publishDir (
        params.out_dir,
        mode: "copy",
        saveAs: { dirname ? "$dirname/$fname" : fname }
    )
    input:
        tuple path(fname), val(dirname)
    output:
        path fname
    """
    """
}

process collectIngressResultsInDir {
    label 'wfnanoclust'
    input:
        tuple val(meta), path(stats), path(reads)
    output:
        tuple val(meta), path("${meta.alias}")
    script:
    """
    mkdir -p ${meta.alias}
    mv $stats ${meta.alias}/ || true
    mv $reads ${meta.alias}/ || true
    """
}


/*
========================================================================================
    MAIN WORKFLOW
========================================================================================
*/

workflow pipeline {
    take:
        samples  // Channel: [meta, reads, stats]

    main:
        // Collect software versions
        versions = getVersions()
        
        // Channel for collecting results
        ch_results = Channel.empty()
        ch_reports = Channel.empty()
        
        // Quality control and filtering
        QC_FILTER(samples)
        
        // K-mer frequency calculation for clustering
        KMER_FREQS(QC_FILTER.out.reads)
        
        // UMAP + HDBSCAN clustering
        READ_CLUSTERING(KMER_FREQS.out.freqs)
        
        // Split reads by cluster assignment
        SPLIT_BY_CLUSTER(
            QC_FILTER.out.reads,
            READ_CLUSTERING.out.clusters
        )
        
        // Per-cluster consensus building
        // The cluster reads channel needs to be transformed for parallel processing
        ch_cluster_reads = SPLIT_BY_CLUSTER.out.cluster_reads
            .transpose()  // Convert grouped output to individual cluster files
        
        // Read correction (Canu)
        READ_CORRECTION(ch_cluster_reads)
        
        // Draft sequence selection
        DRAFT_SELECTION(READ_CORRECTION.out.corrected)
        
        // Racon polishing
        RACON_PASS(
            DRAFT_SELECTION.out.draft,
            READ_CORRECTION.out.corrected
        )
        
        // Medaka polishing
        MEDAKA_PASS(RACON_PASS.out.polished)
        
        // BLAST classification
        CONSENSUS_CLASSIFICATION(
            MEDAKA_PASS.out.consensus,
            file(params.database),
            file(params.taxonomy)
        )
        
        // Calculate abundances
        GET_ABUNDANCES(
            CONSENSUS_CLASSIFICATION.out.results.collect()
        )
        
        // Plot abundance figures
        PLOT_ABUNDANCES(GET_ABUNDANCES.out.abundances)
        
        // Generate HTML report
        MAKE_REPORT(
            QC_FILTER.out.stats.collect(),
            READ_CLUSTERING.out.umap_plot.collect(),
            GET_ABUNDANCES.out.abundances,
            PLOT_ABUNDANCES.out.plots.collect(),
            CONSENSUS_CLASSIFICATION.out.results.collect(),
            versions,
            workflow_version
        )
        
    emit:
        report = MAKE_REPORT.out.html
        abundances = GET_ABUNDANCES.out.abundances
        consensus = MEDAKA_PASS.out.consensus.collect()
        classifications = CONSENSUS_CLASSIFICATION.out.results.collect()
        versions = versions
}


/*
========================================================================================
    ENTRY POINT WORKFLOW
========================================================================================
*/

workflow {
    // Print workflow info
    log.info """
    ====================================================
         wf-nanoclust ${workflow_version}
         De novo 16S/18S rRNA Clustering & Classification
    ====================================================
    fastq        : ${params.fastq}
    database     : ${params.database}
    taxonomy     : ${params.taxonomy}
    out_dir      : ${params.out_dir}
    ====================================================
    """.stripIndent()

    // Validate required parameters
    if (!params.fastq) {
        error "Error: --fastq parameter is required"
    }
    if (!params.database) {
        error "Error: --database parameter is required (path to BLAST database)"
    }
    if (!params.taxonomy) {
        error "Error: --taxonomy parameter is required (path to taxonomy database)"
    }

    // Setup ingress
    def ingress_args = [
        "input": params.fastq,
        "sample": params.sample,
        "sample_sheet": params.sample_sheet,
        "analyse_unclassified": params.analyse_unclassified,
        "stats": true,
        "fastcat_extra_args": "",
        "required_sample_types": [],
        "watch_path": false
    ]

    // Get samples via EPI2ME ingress
    samples = fastq_ingress(ingress_args)

    // Run main pipeline
    results = pipeline(samples)

    // Publish outputs
    output(
        results.report.map { f -> [f, null] }
    )
    output(
        results.abundances.flatten().map { f -> [f, "abundances"] }
    )
    output(
        results.consensus.flatten().map { f -> [f, "consensus"] }
    )
    output(
        results.classifications.flatten().map { f -> [f, "classification"] }
    )
}


/*
========================================================================================
    WORKFLOW COMPLETION
========================================================================================
*/

workflow.onComplete {
    log.info ""
    log.info "======================================================"
    if (workflow.success) {
        log.info "Pipeline completed successfully!"
    } else {
        log.info "Pipeline completed with errors"
    }
    log.info "Output directory: ${params.out_dir}"
    log.info "======================================================"
}

workflow.onError {
    log.error "Pipeline failed - check error messages above"
}
