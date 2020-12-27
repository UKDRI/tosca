#!/usr/bin/env nextflow

// Specify DSL2
nextflow.enable.dsl=2

process CLUSTER_HYBRIDS {

    tag "${sample_id}"
    publishDir "${params.outdir}/hybrids", mode: 'copy', overwrite: true

    cpus 8
    memory 32G
    time '24h'

    input:
        tuple val(sample_id), path(hybrids)

    output:
        tuple val(sample_id), path("${sample_id}.mfe.clusters.tsv.gz"), emit: hybrids

    script:

    percent_overlap = params.percent_overlap
    sample_size = params.sample_size

    """
    #!/usr/bin/env Rscript

    suppressPackageStartupMessages(library(data.table))
    suppressPackageStartupMessages(library(primavera))
    suppressPackageStartupMessages(library(parallel))

    setDTthreads(${task.cpus})

    # Load hybrids
    hybrids.dt <- fread("$hybrids")
    clusters.dt <- cluster_hybrids(hybrids.dt, percent_overlap = $percent_overlap, sample_size = $sample_size, cores = ${task.cpus})
    fwrite(clusters.dt, "${sample_id}.mfe.clusters.tsv.gz", sep = "\t")
    """

}

process COLLAPSE_CLUSTERS {

    tag "${sample_id}"
    publishDir "${params.outdir}/clusters", mode: 'copy', overwrite: true

    cpus 4
    memory 16G
    time '12h'

    input:
        tuple val(sample_id), path(hybrids)
        // path(transcript_gtf)

    output:
        tuple val(sample_id), path("${sample_id}.clusters.tsv.gz"), emit: clusters
        // tuple val(sample_id), path("${sample_id}.intragenic_clusters.bed.gz"), emit: bed

    script:

    """
    #!/usr/bin/env Rscript

    suppressPackageStartupMessages(library(data.table))
    suppressPackageStartupMessages(library(primavera))

    hybrids.dt <- fread("$hybrids")

    # Collapse clusters
    clusters.dt <- collapse_clusters(hybrids.dt)
    fwrite(clusters.dt, "${sample_id}.clusters.tsv.gz", sep = "\t")

    message("Completed!")
    """
}

process clusterhybrids {

    tag "${sample_id}"
    publishDir "${params.outdir}/hybrids", mode: 'copy', overwrite: true

    cpus 8
    time '24h'

    input:
        tuple val(sample_id), path(hybrids)

    output:
        tuple val(sample_id), path("${sample_id}.intragenic_hybrids.mfe.clusters.tsv.gz")

    script:
    """
    #!/usr/bin/env Rscript

    suppressPackageStartupMessages(library(data.table))
    suppressPackageStartupMessages(library(primavera))
    suppressPackageStartupMessages(library(tictoc))

    setDTthreads(8)

    ptm <- proc.time()

    # Load hybrids
    hybrids.dt <- fread("$hybrids")

    # Get intragenic hybrids
    intragenic.hybrids.dt <- hybrids.dt[L_seqnames == R_seqnames][grep("ENS", L_seqnames)]
    fwrite(intragenic.hybrids.dt, paste0("$sample_id", ".intragenic_hybrids.tsv.gz"), sep = "\t")

    # Get Cluster
    message("Clustering...")
    tic()

    # Split out by gene
    intragenic.hybrids.list <- split(intragenic.hybrids.dt, intragenic.hybrids.dt\$L_seqnames)
    solo.intragenic.hybrids.list <- intragenic.hybrids.list[S4Vectors::elementNROWS(intragenic.hybrids.list) == 1] # Remove solos to add in later
    message(length(solo.intragenic.hybrids.list), " genes with one hybrid")
    toomany.intragenic.hybrids.list <- intragenic.hybrids.list[S4Vectors::elementNROWS(intragenic.hybrids.list) > 5000] # Remove too many
    message(length(toomany.intragenic.hybrids.list), " genes with >5000 hybrids")
    intragenic.hybrids.list <- intragenic.hybrids.list[S4Vectors::elementNROWS(intragenic.hybrids.list) > 1]
    intragenic.hybrids.list <- intragenic.hybrids.list[S4Vectors::elementNROWS(intragenic.hybrids.list) <= 5000]
    message(length(intragenic.hybrids.list), " genes to cluster")

    # TODO: add in check for length

    library(tictoc)
    tic()
    intragenic.hybrids.clusters.list <- lapply(1:length(intragenic.hybrids.list), function(i) {

    # message(i)
    ClusterHybrids(intragenic.hybrids.list[[i]], percent_overlap = 0.25)

    })

    # Name and id order flipped for genes without clusters, because of merging clusters back in, hence use.names = TRUE
    intragenic.hybrids.clusters.dt <- rbindlist(intragenic.hybrids.clusters.list, use.names = TRUE)
    solo.intragenic.hybrids.dt <- rbindlist(solo.intragenic.hybrids.list, use.names = TRUE) # Add solos back in
    
    if(length(toomany.intragenic.hybrids.list) == 0) {
    
        toomany.intragenic.hybrids.dt <- data.table()
    
    } else {
    
        toomany.intragenic.hybrids.dt <- rbindlist(toomany.intragenic.hybrids.list, use.names = TRUE)[, cluster := Inf]
    
    }
    
    intragenic.hybrids.clusters.dt <- rbind(intragenic.hybrids.clusters.dt, solo.intragenic.hybrids.dt, toomany.intragenic.hybrids.dt, use.names = TRUE, fill = TRUE)
    toc()

    stopifnot(nrow(intragenic.hybrids.clusters.dt) == nrow(intragenic.hybrids.dt))

    f_out <- paste0("$sample_id", ".intragenic_hybrids.mfe.clusters.tsv.gz")
    fwrite(intragenic.hybrids.clusters.dt, f_out, sep = "\t")

    message("Completed!")
    """
}