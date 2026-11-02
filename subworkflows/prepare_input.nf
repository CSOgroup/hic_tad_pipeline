include { CHOOSE_RESOLUTION } from '../modules/choose_resolution/choose_resolution'
include { ADD_CHR_PREFIX }    from '../modules/add_chr_prefix/add_chr_prefix'
include { EXTRACT_CHROMS }    from '../modules/extract_chroms/extract_chroms'
include { BALANCE }           from '../modules/balance/balance'
include { PREP_CALLER_INPUT } from '../modules/prep_caller_input/prep_caller_input'

workflow PREPARE_INPUT {
    take:
    ch_input
    resolution
    norm_type
    species
    chroms
    callers
    nproc

    main:
    CHOOSE_RESOLUTION(ch_input, resolution, nproc, true)
    ADD_CHR_PREFIX(CHOOSE_RESOLUTION.out.rebinned_cool, false)
    EXTRACT_CHROMS(ADD_CHR_PREFIX.out.chr_prefixed_cool, species, chroms)
    BALANCE(EXTRACT_CHROMS.out.extracted_cool, resolution, norm_type, nproc, false)
    balanced_ch = BALANCE.out.balanced_cool.mix(BALANCE.out.balanced_hic)

    PREP_CALLER_INPUT(balanced_ch, resolution, '', callers, norm_type)

    emit:
    balanced_cool            = BALANCE.out.balanced_cool
    balanced_hic             = BALANCE.out.balanced_hic
    dense_matrix_with_coords = PREP_CALLER_INPUT.out.dense_matrix_with_coords
    dense_matrix_no_coords   = PREP_CALLER_INPUT.out.dense_matrix_no_coords
    sparse_matrix_bin1_dedoc = PREP_CALLER_INPUT.out.sparse_matrix_bin1_dedoc
    hic                      = PREP_CALLER_INPUT.out.hic
}
