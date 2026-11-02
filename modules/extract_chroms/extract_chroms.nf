def chroms_label(species, chroms) {
    if (chroms) {
        def list = chroms.tokenize(',')
        return list.size() <= 3 ? list.join('_') : "custom_${list.size()}chroms"
    }
    return species ?: 'common_chr'
}

process EXTRACT_CHROMS {
    tag "$meta.id"
    container 'local/hic-prep-input:1.0'
    containerOptions "-v ${moduleDir}/scripts:/scripts:ro"

    input:
    tuple val(meta), path(input_cool)
    val species
    val chroms

    output:
    tuple val(meta), path("${meta.id}.chroms_${chroms_label(species, chroms)}.cool"), emit: extracted_cool

    script:
    def species_opt = species ? "--species ${species}" : ""
    def chroms_opt = chroms ? "--chroms ${chroms}" : ""
    """
    python3 /scripts/extract_chroms.py \\
        ${input_cool.name} \\
        ${meta.id}.chroms_${chroms_label(species, chroms)}.cool \\
        ${species_opt} \\
        ${chroms_opt}
    """
}
