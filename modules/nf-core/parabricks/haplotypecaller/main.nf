process PARABRICKS_HAPLOTYPECALLER {
    tag "$meta.id"
    label 'process_high'

    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        exit 1, "Parabricks module does not support Conda. Please use Docker / Singularity / Podman instead."
    }

    container "nvcr.io/nvidia/clara/clara-parabricks:4.0.1-1"

    input:
    tuple val(meta), path(input), path(input_index), path(interval_file)
    path fasta

    output:
    tuple val(meta), path("*.vcf"), emit: vcf
    path "versions.yml",            emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def output_file = args =~ "gvcf" ? "${prefix}.g.vcf" : "${prefix}.vcf"
    def interval_file_command = interval_file ? interval_file.collect{"--interval-file $it"}.join(' ') : ""
    def copy_index_command = input_index ? "cp -L $input_index `readlink -f $input`.bai" : ""
    """
    # parabricks needs the index file to exist as a regular file in the same dir as fasta
    $copy_index_command

    pbrun \\
        haplotypecaller \\
        --ref $fasta \\
        --in-bam $input \\
        --out-variants $output_file \\
        $interval_file_command \\
        --num-gpus $task.accelerator.request \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
            pbrun: \$(echo \$(pbrun version 2>&1) | sed 's/^Please.* //' )
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def output_file = args =~ "gvcf" ? "${prefix}.g.vcf" : "${prefix}.vcf"
    """
    touch $output_file

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
            pbrun: \$(echo \$(pbrun version 2>&1) | sed 's/^Please.* //' )
    END_VERSIONS
    """
}
