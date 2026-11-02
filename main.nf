include { PREPARE_INPUT }  from './subworkflows/prepare_input'
include { CALL_TADS }      from './subworkflows/call_tads'
include { CONSENSUS_TADS } from './modules/consensus_tads/consensus_tads'

def parseInput(String input) {
    def rows
    if (input.toLowerCase().endsWith('.csv')) {
        def sheet = file(input, checkIfExists: true)
        def records = sheet.splitCsv(header: true)
        if (!records) error "Samplesheet is empty: ${input}"
        def missing_cols = ['sample', 'file'] - records[0].keySet()
        if (missing_cols) error "Samplesheet ${input} is missing column(s): ${missing_cols.join(',')} (expected header: sample,file)"
        rows = records.collect { r ->
            def raw = r.file?.trim()
            if (!r.sample?.trim() || !raw) error "Samplesheet ${input} has a row with empty sample or file: ${r}"
            def f = raw.startsWith('/') ? file(raw) : sheet.parent.resolve(raw)
            if (!f.exists()) error "File not found for sample '${r.sample}': ${f}"
            [[id: r.sample.trim()], f]
        }
    } else {
        def files = file(input, checkIfExists: true)
        files = files instanceof List ? files : [files]
        if (!files) error "No files match --input: ${input}"
        rows = files.collect { f -> [[id: f.baseName], f] }
    }

    def bad_ext = rows.findAll { _meta, f -> !(f.extension.toLowerCase() in ['cool', 'mcool', 'hic']) }
    if (bad_ext) error "Unsupported input format (expected .cool/.mcool/.hic): ${bad_ext.collect { _meta, f -> f.name }.join(', ')}"

    def bad_ids = rows.collect { meta, _f -> meta.id }.findAll { id -> !(id ==~ /[A-Za-z0-9._-]+/) }
    if (bad_ids) error "Invalid sample name(s): ${bad_ids.collect { id -> "'${id}'" }.join(', ')}. Only letters, digits, '.', '_' and '-' are allowed"

    def dup_ids = rows.countBy { meta, _f -> meta.id }.findAll { _id, n -> n > 1 }.keySet()
    if (dup_ids) error "Duplicate sample name(s): ${dup_ids.join(',')}. Sample names must be unique (rename files or use a samplesheet)"

    return channel.fromList(rows)
}

workflow {
    main:
    def VALID_CALLERS = ['arrowhead', 'topdom', 'di', 'mstd', 'lpad', 'ontad', 'spectraltad', 'dedoc']
    def VALID_NORM    = ['ICE', 'ICE_cis', 'KR', 'NONE']
    def VALID_SPECIES = ['', 'human', 'mouse']

    if (!params.input)      error "Missing required param: --input <.cool/.mcool/.hic file or samplesheet .csv>"
    if (!params.resolution) error "Missing required param: --resolution <bp>"
    if (!(params.resolution.toString().isLong() && (params.resolution as Long) > 0)) {
        error "--resolution must be a positive integer (bp), got: ${params.resolution}"
    }
    if (!(params.norm_type in VALID_NORM)) error "--norm_type must be one of ${VALID_NORM.join(', ')}, got: ${params.norm_type}"
    if (!(params.species in VALID_SPECIES)) error "--species must be human or mouse, got: ${params.species}"
    if (!((params.consensus_step as Double) < 0)) error "--consensus_step must be negative, got: ${params.consensus_step}"

    def callers = params.callers.toString()
    def enabled = callers.split(',').collect { c -> c.trim() }.findAll { c -> c } as Set
    def unknown = enabled - VALID_CALLERS
    if (unknown) error "Unknown caller(s): ${unknown.join(',')}. Valid callers: ${VALID_CALLERS.join(',')}"
    if (!enabled) error "No callers enabled — check --callers"

    def chroms = params.chroms.toString()

    ch_input = parseInput(params.input.toString())

    PREPARE_INPUT(ch_input, params.resolution, params.norm_type, params.species, chroms, callers, params.nproc)

    CALL_TADS(
        PREPARE_INPUT.out.hic,
        PREPARE_INPUT.out.dense_matrix_with_coords,
        PREPARE_INPUT.out.dense_matrix_no_coords,
        PREPARE_INPUT.out.sparse_matrix_bin1_dedoc,
        params.resolution, chroms, params.norm_type, callers, enabled
    )

    CONSENSUS_TADS(CALL_TADS.out.clean_results, params.consensus_threshold, params.consensus_step, params.nproc)

    publish:
    balanced       = PREPARE_INPUT.out.balanced_cool.mix(PREPARE_INPUT.out.balanced_hic)
    caller_input   = PREPARE_INPUT.out.hic
        .mix(PREPARE_INPUT.out.dense_matrix_with_coords)
        .mix(PREPARE_INPUT.out.dense_matrix_no_coords)
        .mix(PREPARE_INPUT.out.sparse_matrix_bin1_dedoc)
    caller_results = CALL_TADS.out.tad_results.mix(CALL_TADS.out.clean_results)
    consensus_tads = CONSENSUS_TADS.out.consensus
}

output {
    balanced {
        path { meta, _f -> "${meta.id}/balanced" }
    }
    caller_input {
        path { meta, _f -> "${meta.id}/caller_input" }
    }
    caller_results {
        path { meta, _f -> "${meta.id}/caller_results" }
    }
    consensus_tads {
        path { meta, _f -> "${meta.id}" }
    }
}
