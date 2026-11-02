include { ARROWHEAD }     from '../modules/arrowhead/arrowhead'
include { TOPDOM }        from '../modules/topdom/topdom'
include { DI }            from '../modules/di/di'
include { MSTD }          from '../modules/mstd/mstd'
include { ONTAD }         from '../modules/ontad/ontad'
include { SPECTRALTAD }   from '../modules/spectraltad/spectraltad'
include { DEDOC }         from '../modules/dedoc/dedoc'
include { LPAD }          from '../modules/lpad/lpad'
include { CLEAN_RESULTS } from '../modules/clean_results/clean_results'

def checkExpectedSamples(List expected_channels, ch_grouped_results) {
    def ch_expected_metas = channel.empty()
    expected_channels.each { ch -> ch_expected_metas = ch_expected_metas.mix(ch) }
    ch_expected_metas = ch_expected_metas.unique()

    def ch_got_metas = ch_grouped_results.map { meta, _dirs -> meta }

    ch_expected_metas.collect().map { e -> [e] }
        .combine(ch_got_metas.collect().map { g -> [g] })
        .map { expected, got ->
            def got_ids = got.collect { m -> m.id }
            def missing = expected.findAll { meta -> !(meta.id in got_ids) }
            if (missing) error "All enabled callers failed for sample(s): ${missing.collect { m -> m.id }.join(',')}"
        }
}

workflow CALL_TADS {
    take:
    ch_hic
    ch_dense_with_coords
    ch_dense_no_coords
    ch_dedoc
    resolution
    chroms
    norm_type
    callers
    enabled

    main:
    result_channels = []
    if ('arrowhead'   in enabled) { ARROWHEAD(ch_hic, resolution, chroms, norm_type); result_channels << ARROWHEAD.out.results }
    if ('topdom'      in enabled) { TOPDOM(ch_dense_with_coords);                     result_channels << TOPDOM.out.results }
    if ('di'          in enabled) { DI(ch_dense_with_coords, resolution);             result_channels << DI.out.results }
    if ('mstd'        in enabled) { MSTD(ch_dense_no_coords);                         result_channels << MSTD.out.results }
    if ('ontad'       in enabled) { ONTAD(ch_dense_no_coords);                        result_channels << ONTAD.out.results }
    if ('spectraltad' in enabled) { SPECTRALTAD(ch_dense_no_coords);                  result_channels << SPECTRALTAD.out.results }
    if ('dedoc'       in enabled) { DEDOC(ch_dedoc);                                  result_channels << DEDOC.out.results }
    if ('lpad'        in enabled) { LPAD(ch_dense_no_coords);                         result_channels << LPAD.out.results }

    if (result_channels.isEmpty()) error "No callers enabled — check --callers"

    all_results = channel.empty()
    result_channels.each { ch -> all_results = all_results.mix(ch) }

    grouped_results = all_results.groupTuple()

    def expected_inputs = []
    if ('arrowhead' in enabled) expected_inputs << ch_hic.map { meta, _f -> meta }
    if ((['topdom', 'di'] as Set).any { c -> c in enabled }) expected_inputs << ch_dense_with_coords.map { meta, _f -> meta }
    if ((['mstd', 'ontad', 'spectraltad', 'lpad'] as Set).any { c -> c in enabled }) expected_inputs << ch_dense_no_coords.map { meta, _f -> meta }
    if ('dedoc' in enabled) expected_inputs << ch_dedoc.map { meta, _f -> meta }

    checkExpectedSamples(expected_inputs, grouped_results)

    CLEAN_RESULTS(grouped_results, resolution, callers, chroms)

    emit:
    tad_results   = all_results
    clean_results = CLEAN_RESULTS.out.clean_results
}
