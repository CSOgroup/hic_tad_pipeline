def PREP_CALLER_FORMATS(String callers) {
    def need_hic = false
    def formats = [] as Set
    callers.tokenize(',').each { c ->
        if (c == 'arrowhead')                                   need_hic = true
        else if (c in ['topdom', 'di'])                         formats << 'dense_matrix_with_coords'
        else if (c in ['mstd', 'lpad', 'ontad', 'spectraltad']) formats << 'dense_matrix_no_coords'
        else if (c == 'dedoc')                                  formats << 'sparse_matrix_bin1_dedoc'
    }
    [need_hic: need_hic, formats: formats]
}

process PREP_CALLER_INPUT {
    tag "$meta.id"
    container 'local/hic-prep-input:1.0'
    containerOptions "-v ${moduleDir}/scripts:/scripts:ro"

    input:
    tuple val(meta), path(input_file)
    val   resolution
    val   chroms
    val   callers
    val   norm_type

    output:
    tuple val(meta), path('dense_matrix_with_coords'), optional: true, emit: dense_matrix_with_coords
    tuple val(meta), path('dense_matrix_no_coords'),   optional: true, emit: dense_matrix_no_coords
    tuple val(meta), path('sparse_matrix_bin1_dedoc'), optional: true, emit: sparse_matrix_bin1_dedoc
    tuple val(meta), path("${input_file.baseName}.forcaller.hic"), optional: true, emit: hic

    script:
    def ext = input_file.name.tokenize('.').last().toLowerCase()
    if (!(ext in ['hic', 'cool'])) {
        error "PREP_CALLER_INPUT: unsupported extension '.${ext}'; expected .cool or .hic (got: ${input_file.name})"
    }
    if (ext == 'hic' && !(norm_type in ['KR', 'NONE'])) {
        error "PREP_CALLER_INPUT: norm_type must be KR or NONE for .hic input, got: ${norm_type}"
    }

    def caller_fmt = PREP_CALLER_FORMATS(callers)
    def formats    = caller_fmt.formats
    def fmt_str    = formats.join(',')
    def chrom_opt  = chroms ? "--chroms '${chroms}'" : ''
    def weight_col = norm_type == 'ICE' ? 'weight' : norm_type

    def hic_cmd = ''
    if (caller_fmt.need_hic) {
        def hic_out = "${input_file.baseName}.forcaller.hic"
        hic_cmd = ext == 'cool'
            ? (norm_type in ['ICE', 'ICE_cis']
                ? """
                python3 /scripts/utils_cool_weight2count.py ${input_file.name} input_weighted.cool ${weight_col}
                hictk convert --force input_weighted.cool ${hic_out}
                rm -f input_weighted.cool
                """
                : "hictk convert --force ${input_file.name} ${hic_out}")
            : "ln -sf ${input_file.name} ${hic_out}"
    }

    def fmt_cmd = ''
    if (formats) {
        fmt_cmd = ext == 'cool'
            ? "python3 /scripts/utils_cool2txt.py ${input_file.name} . ${chrom_opt} --formats ${fmt_str} --normalization ${norm_type}"
            : "python3 /scripts/utils_hic2txt.py ${input_file.name} ${resolution} . ${chrom_opt} --formats ${fmt_str} --normalization ${norm_type}"
    }

    """
    ${hic_cmd}
    ${fmt_cmd}
    """
}
