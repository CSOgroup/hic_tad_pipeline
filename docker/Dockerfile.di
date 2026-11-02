FROM kmiles18/tad-callers-based-on-matlab:v1.0

RUN apt-get update && \
    apt-get install -y --no-install-recommends perl && \
    rm -rf /var/lib/apt/lists/*

COPY HMM_calls_v2.m /home/work/DI/domaincall_software/HMM_calls_v2.m

COPY DI_from_matrix.pl \
     file_ends_cleaner.pl \
     converter_7col.pl \
     hmm_probablity_correcter_pm.pl \
     hmm-state_caller.pl \
     hmm-state_domains_mz.pl \
     /opt/di_scripts/

RUN chmod +x /opt/di_scripts/*.pl

RUN chmod -R a+rX /home/work/DI
