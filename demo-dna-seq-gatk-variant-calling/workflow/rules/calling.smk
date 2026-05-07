if "restrict-regions" in config["processing"]:

    rule compose_regions:
        input:
            config["processing"]["restrict-regions"],
        output:
            "results/called/{contig}.regions.bed",
        conda:
            "../envs/bedops.yaml"
        shell:
            "bedextract {wildcards.contig} {input} > {output}"


rule call_variants:
    input:
        bam=get_sample_bams,
        ref="resources/genome.fasta",
        idx="resources/genome.dict",
        known="resources/variation.noiupac.vcf.gz",
        tbi="resources/variation.noiupac.vcf.gz.tbi",
        regions=(
            "results/called/{contig}.regions.bed"
            if config["processing"].get("restrict-regions")
            else []
        ),
    output:
        gvcf=protected("results/called/{sample}.{contig}.g.vcf.gz"),
        # index="results/called/{sample}.{contig}.g.vcf.gz.tbi",
    threads: 15
    resources:
        mem_mb=16000,
    log:
        "logs/gatk/haplotypecaller/{sample}.{contig}.log",
    params:
        extra=get_call_variants_params,
    wrapper:
        "file:/share_gpu/zhangjm/dev_projects/flow_projects/vignettes/snakemake-wrappers-3.5.3/bio/gatk/haplotypecaller"


rule combine_calls:
    input:
        ref="resources/genome.fasta",
        gvcfs=expand(
            "results/called/{sample}.{{contig}}.g.vcf.gz", sample=samples.index
        ),
    output:
        gvcf="results/called/all.{contig}.g.vcf.gz",
    threads: 15
    resources:
        mem_mb=16000,
    log:
        "logs/gatk/combinegvcfs.{contig}.log",
    wrapper:
        "file:/share_gpu/zhangjm/dev_projects/flow_projects/vignettes/snakemake-wrappers-3.5.3/bio/gatk/combinegvcfs"


rule genotype_variants:
    input:
        ref="resources/genome.fasta",
        gvcf="results/called/all.{contig}.g.vcf.gz",
        # index="results/called/all.{contig}.g.vcf.gz.tbi",
    output:
        vcf=temp("results/genotyped/all.{contig}.vcf.gz"),
    params:
        extra=config["params"]["gatk"]["GenotypeGVCFs"],
    resources:
        mem_mb=16000,
    threads: 15
    log:
        "logs/gatk/genotypegvcfs.{contig}.log",
    wrapper:
        "file:/share_gpu/zhangjm/dev_projects/flow_projects/vignettes/snakemake-wrappers-3.5.3/bio/gatk/genotypegvcfs"


rule merge_variants:
    input:
        vcfs=lambda w: expand(
            "results/genotyped/all.{contig}.vcf.gz", contig=get_contigs()
        ),
    output:
        vcf="results/genotyped/all.vcf.gz",
    resources:
        mem_mb=16000,
    log:
        "logs/picard/merge-genotyped.log",
    wrapper:
        "file:/share_gpu/zhangjm/dev_projects/flow_projects/vignettes/snakemake-wrappers-3.5.3/bio/picard/mergevcfs"
