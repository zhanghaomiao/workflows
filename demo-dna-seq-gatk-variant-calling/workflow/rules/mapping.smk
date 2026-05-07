rule trim_reads_se:
    input:
        unpack(get_fastq),
    output:
        temp("results/trimmed/{sample}-{unit}.fastq.gz"),
    params:
        **config["params"]["trimmomatic"]["se"],
        extra="",
    log:
        "logs/trimmomatic/{sample}-{unit}.log",
    wrapper:
        "file:/share_gpu/zhangjm/dev_projects/flow_projects/vignettes/snakemake-wrappers-3.5.3/bio/trimmomatic/se"


rule trim_reads_pe:
    input:
        unpack(get_fastq),
    output:
        r1=temp("results/trimmed/{sample}-{unit}.1.fastq.gz"),
        r2=temp("results/trimmed/{sample}-{unit}.2.fastq.gz"),
        r1_unpaired=temp("results/trimmed/{sample}-{unit}.1.unpaired.fastq.gz"),
        r2_unpaired=temp("results/trimmed/{sample}-{unit}.2.unpaired.fastq.gz"),
        trimlog="results/trimmed/{sample}-{unit}.trimlog.txt",
    params:
        **config["params"]["trimmomatic"]["pe"],
        extra=lambda w, output: "-trimlog {}".format(output.trimlog),
    log:
        "logs/trimmomatic/{sample}-{unit}.log",
    wrapper:
        "file:/share_gpu/zhangjm/dev_projects/flow_projects/vignettes/snakemake-wrappers-3.5.3/bio/trimmomatic/pe"


rule map_reads:
    input:
        reads=get_trimmed_reads,
        idx=rules.bwa_index.output,
    output:
        "results/mapped/{sample}-{unit}.sorted.bam",
    log:
        "logs/bwa_mem/{sample}-{unit}.log",
    params:
        index=lambda w, input: os.path.splitext(input.idx[0])[0],
        extra=get_read_group,
        sorting="samtools",
        sort_order="coordinate",
    threads: 15
    wrapper:
        "file:/share_gpu/zhangjm/dev_projects/flow_projects/vignettes/snakemake-wrappers-3.5.3/bio/bwa/mem"


# rule mark_duplicates:
#     input:
#         bams="results/mapped/{sample}-{unit}.sorted.bam",
#     output:
#         bam=temp("results/dedup/{sample}-{unit}.bam"),
#         metrics="results/qc/dedup/{sample}-{unit}.metrics.txt",
#     log:
#         "logs/picard/dedup/{sample}-{unit}.log",
#     resources:
#         mem_mb=32000,
#     params:
#         config["params"]["picard"]["MarkDuplicates"],
#     wrapper:
#         "file:/share_gpu/zhangjm/dev_projects/flow_projects/vignettes/snakemake-wrappers-3.5.3/bio/picard/markduplicates"


rule mark_duplicates:
    input:
        bams="results/mapped/{sample}-{unit}.sorted.bam",
    output:
        bam="results/dedup/{sample}-{unit}.bam",
        metrics="results/qc/dedup/{sample}-{unit}.metrics.txt",
    log:
        "logs/picard/dedup/{sample}-{unit}.log",
    resources:
        mem_mb=32000,
    conda:
        "/share_gpu/zhangjm/dev_projects/flow_projects/vignettes/snakemake-wrappers-3.5.3/bio/picard/markduplicates/environment.yaml"
    shell:
        """
        picard MarkDuplicates \
            -Xmx{resources.mem_mb}M \
            I={input.bams} \
            O={output.bam} \
            M={output.metrics} \
            REMOVE_DUPLICATES=true \
            VALIDATION_STRINGENCY=LENIENT \
            &> {log}
        """


rule recalibrate_base_qualities:
    input:
        bam=get_recal_input(),
        bai=get_recal_input(bai=True),
        ref="resources/genome.fasta",
        dict="resources/genome.dict",
        known="resources/variation.noiupac.vcf.gz",
        known_idx="resources/variation.noiupac.vcf.gz.tbi",
    output:
        recal_table="results/recal/{sample}-{unit}.grp",
    log:
        "logs/gatk/bqsr/{sample}-{unit}.log",
    params:
        extra=get_regions_param() + config["params"]["gatk"]["BaseRecalibrator"],
    resources:
        mem_mb=1024,
    wrapper:
        "file:/share_gpu/zhangjm/dev_projects/flow_projects/vignettes/snakemake-wrappers-3.5.3/bio/gatk/baserecalibrator"


rule apply_base_quality_recalibration:
    input:
        bam=get_recal_input(),
        bai=get_recal_input(bai=True),
        ref="resources/genome.fasta",
        dict="resources/genome.dict",
        recal_table="results/recal/{sample}-{unit}.grp",
    output:
        bam=protected("results/recal/{sample}-{unit}.bam"),
    log:
        "logs/gatk/apply-bqsr/{sample}-{unit}.log",
    params:
        extra=get_regions_param(),
    resources:
        mem_mb=1024,
    wrapper:
        "file:/share_gpu/zhangjm/dev_projects/flow_projects/vignettes/snakemake-wrappers-3.5.3/bio/gatk/applybqsr"


rule samtools_index:
    input:
        "{prefix}.bam",
    output:
        "{prefix}.bam.bai",
    log:
        "logs/samtools/index/{prefix}.log",
    wrapper:
        "file:/share_gpu/zhangjm/dev_projects/flow_projects/vignettes/snakemake-wrappers-3.5.3/bio/samtools/index"
