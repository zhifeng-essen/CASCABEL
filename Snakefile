"""
CASCABEL
Version: 4.0
Author: Julia Engelmann and Alejandro Abdala
Last update: 30/07/2019
"""
run=config["RUN"]

def selectInput():
    if (config["align_vs_reference"]["align"] == "T" and config["cutAdapters"] == "T"):
        return ["{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_accepted.align.no_adapter.degapped.oneline.fna"]
    elif (config["align_vs_reference"]["align"] == "T" and config["cutAdapters"] != "T"):
        return ["{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_accepted.align.degapped.oneline.fna"]
    elif (config["align_vs_reference"]["align"] != "T" and config["cutAdapters"] == "T"):
        return ["{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_accepted_no_adapters.fna"]
    else:
        return ["{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_accepted.fna"]

rule all:
    input:
        expand("{PROJECT}/runs/{run}/report_{sample}_"+config["assignTaxonomy"]["tool"]+".pdf" if config["pdfReport"] == "T" else "{PROJECT}/runs/{run}/report_{sample}_"+config["assignTaxonomy"]["tool"]+".html", PROJECT=config["PROJECT"],sample=config["LIBRARY"], run=run),
        expand("{PROJECT}/runs/{run}/report_"+config["assignTaxonomy"]["tool"]+".zip",PROJECT=config["PROJECT"], run=run)
        #expand("{PROJECT}/runs/{run}/report_{sample}_"+config["assignTaxonomy"]["tool"]+".pdf" , PROJECT=config["PROJECT"],sample=config["LIBRARY"], run=run)
        #if (config["pdfReport"] == "T" and config["portableReport"] == "F") else
        #expand("{PROJECT}/runs/{run}/report_{sample}_"+config["assignTaxonomy"]["tool"]+".html", PROJECT=config["PROJECT"],sample=config["LIBRARY"], run=run)
        #if (config["pdfReport"] == "F" and config["portableReport"] == "F") else
        #expand("{PROJECT}/runs/{run}/report_"+config["assignTaxonomy"]["tool"]+".zip", PROJECT=config["PROJECT"],sample=config["LIBRARY"], run=run)


if len(config["LIBRARY"])==1 and config["demultiplexing"]["demultiplex"] == "T":
    rule init_structure:
        input:
            fw = config["fw_reads"],
            rv = config["rv_reads"],
            metadata = config["metadata"]
        output:
            r1="{PROJECT}/samples/{sample}/rawdata/fw.fastq"  if config["gzip_input"] == "F" else "{PROJECT}/samples/{sample}/rawdata/fw.fastq.gz",
            r2="{PROJECT}/samples/{sample}/rawdata/rv.fastq"  if config["gzip_input"] == "F" else "{PROJECT}/samples/{sample}/rawdata/rv.fastq.gz",
            metadata="{PROJECT}/metadata/sampleList_mergedBarcodes_{sample}.txt"
        shell:
            "Scripts/init_sample.sh "+config["PROJECT"]+" "+config["LIBRARY"][0]+" {input.metadata} {input.fw} {input.rv}"
elif len(config["LIBRARY"])==1 and config["demultiplexing"]["demultiplex"] == "F":
    rule init_structure:
        input:
            fw = config["fw_reads"],
            rv = config["rv_reads"],
        output:
            r1="{PROJECT}/samples/{sample}/rawdata/fw.fastq" if config["gzip_input"] == "F" else "{PROJECT}/samples/{sample}/rawdata/fw.fastq.gz",
            r2="{PROJECT}/samples/{sample}/rawdata/rv.fastq" if config["gzip_input"] == "F" else "{PROJECT}/samples/{sample}/rawdata/rv.fastq.gz"
        shell:
            "Script/init_sample_dmx.sh "+config["PROJECT"]+" "+config["LIBRARY"][0]+"  {input.fw} {input.rv}"
#First we run fastQC over the rawdata
rule fast_qc:
    input:
        r1="{PROJECT}/samples/{sample}/rawdata/fw.fastq" if config["gzip_input"] == "F" else "{PROJECT}/samples/{sample}/rawdata/fw.fastq.gz",
        r2="{PROJECT}/samples/{sample}/rawdata/rv.fastq" if config["gzip_input"] == "F" else "{PROJECT}/samples/{sample}/rawdata/rv.fastq.gz"
    output:
        o1="{PROJECT}/samples/{sample}/qc/fw_fastqc.html",
        o2="{PROJECT}/samples/{sample}/qc/rv_fastqc.html",
        s1="{PROJECT}/samples/{sample}/qc/fw_fastqc/summary.txt",
        s2="{PROJECT}/samples/{sample}/qc/rv_fastqc/summary.txt"
    benchmark:
        "{PROJECT}/samples/{sample}/qc/fq.benchmark"
    shell:
        "{config[fastQC][command]} {input.r1} {input.r2} --extract {config[fastQC][extra_params]} -o {wildcards.PROJECT}/samples/{wildcards.sample}/qc/"
#validate qc if too many fails on qc report
rule validateQC:
    input:
        "{PROJECT}/samples/{sample}/qc/fw_fastqc/summary.txt",
        "{PROJECT}/samples/{sample}/qc/rv_fastqc/summary.txt",
        "{PROJECT}/samples/{sample}/qc/fw_fastqc.html",
        "{PROJECT}/samples/{sample}/qc/rv_fastqc.html",
        "{PROJECT}/samples/{sample}/rawdata/fw.fastq" if config["gzip_input"] == "F" else "{PROJECT}/samples/{sample}/rawdata/fw.fastq.gz",
        "{PROJECT}/samples/{sample}/rawdata/rv.fastq" if config["gzip_input"] == "F" else "{PROJECT}/samples/{sample}/rawdata/rv.fastq.gz"
    output:
        "{PROJECT}/samples/{sample}/qc/fq_fw_internal_validation.txt",
        "{PROJECT}/samples/{sample}/qc/fq_rv_internal_validation.txt"
    script:
        "Scripts/validateQC.py"
#Run pear to extend fragments
rule pear:
     input:
         r1="{PROJECT}/samples/{sample}/rawdata/fw.fastq" if config["gzip_input"] == "F" else "{PROJECT}/samples/{sample}/rawdata/fw.fastq.gz",
         r2="{PROJECT}/samples/{sample}/rawdata/rv.fastq" if config["gzip_input"] == "F" else "{PROJECT}/samples/{sample}/rawdata/rv.fastq.gz",
         tmp1="{PROJECT}/samples/{sample}/qc/fq_fw_internal_validation.txt",
         tmp2="{PROJECT}/samples/{sample}/qc/fq_rv_internal_validation.txt"
     output:
        "{PROJECT}/runs/{run}/{sample}_data/peared/seqs.assembled.fastq",
        "{PROJECT}/runs/{run}/{sample}_data/peared/pear.log"
     benchmark:
        "{PROJECT}/runs/{run}/{sample}_data/peared/pear.benchmark"
     params:
        "{PROJECT}/runs/{run}/{sample}_data/peared/seqs"
     shell:
        "{config[pear][command]} -f {input.r1} -r {input.r2} -o {params[0]} "
        "-t {config[pear][t]} -v {config[pear][v]} -j {config[pear][j]} -p {config[pear][p]} {config[pear][extra_params]} > "
        "{output[1]}"
#Validate % of peared reds
rule validatePear:
    input:
        "{PROJECT}/runs/{run}/{sample}_data/peared/pear.log"
    output:
        "{PROJECT}/runs/{run}/{sample}_data/peared/pear.log.validation"
    script:
        "Scripts/validatePear.py"

if config["fastQCPear"] == "T":
    rule fastQCPear:
      input:
          r1="{PROJECT}/runs/{run}/{sample}_data/peared/seqs.assembled.fastq"
      output:
          o1="{PROJECT}/runs/{run}/{sample}_data/peared/qc/seqs.assembled_fastqc.html",
          s2="{PROJECT}/runs/{run}/{sample}_data/peared/qc/seqs.assembled_fastqc/summary.txt"
      params:
          "{PROJECT}/runs/{run}/{sample}_data/peared/qc/"
      benchmark:
          "{PROJECT}/runs/{run}/{sample}_data/peared/qc/fq.benchmark"
      shell:
          "{config[fastQC][command]} {input.r1} --extract -o {params}"

    rule validateFastQCPear:
        input:
            "{PROJECT}/runs/{run}/{sample}_data/peared/qc/seqs.assembled_fastqc/summary.txt",
            "{PROJECT}/runs/{run}/{sample}_data/peared/qc/seqs.assembled_fastqc.html",
            "{PROJECT}/runs/{run}/{sample}_data/peared/seqs.assembled.fastq"
        output:
            "{PROJECT}/runs/{run}/{sample}_data/peared/qc/fq_fw_internal_validation.txt"
        script:
            "Scripts/validatePearedQC.py"
else:
    rule skipFastQCPear:
        input:
            "{PROJECT}/runs/{run}/{sample}_data/peared/seqs.assembled.fastq"
        output:
            "{PROJECT}/runs/{run}/{sample}_data/peared/qc/fq_fw_internal_validation.txt"
        shell:
            "touch {output}"
if config["demultiplexing"]["demultiplex"] == "T":

    rule bc_mapping_validation:
        """
        Check if the mapping file is ok. Header line needs to start with #
        """
        input:
            mapp="{PROJECT}/metadata/sampleList_mergedBarcodes_{sample}.txt"
        output:
            "{PROJECT}/metadata/bc_validation/{sample}/sampleList_mergedBarcodes_{sample}.log" # antes .log pero creo carpeta .log??
        benchmark:
            "{PROJECT}/metadata/bc_validation/{sample}/validation.benchmark"
        params:
            "{PROJECT}/metadata/bc_validation/{sample}/"
        shell:
            "{config[qiime][path]}validate_mapping_file.py -o {params} -m {input.mapp}"
#validate bc validation log file stop WF in failure
    rule validateBCV:
        input:
            "{PROJECT}/metadata/bc_validation/{sample}/sampleList_mergedBarcodes_{sample}.log",
            "{PROJECT}/metadata/sampleList_mergedBarcodes_{sample}.txt"
        output:
            "{PROJECT}/metadata/bc_validation/{sample}/validation.log"
        params:
            "{PROJECT}/metadata/bc_validation/{sample}/"
        script:
            "Scripts/validateBCV.py"

#Extract bc from reads
    rule extract_barcodes:
        input:
            tmp2="{PROJECT}/runs/{run}/{sample}_data/peared/pear.log.validation",
            assembly="{PROJECT}/runs/{run}/{sample}_data/peared/seqs.assembled.fastq",
            tmpinput="{PROJECT}/runs/{run}/{sample}_data/peared/qc/fq_fw_internal_validation.txt"
        output:
            "{PROJECT}/runs/{run}/{sample}_data/barcodes/barcodes.fastq",
            "{PROJECT}/runs/{run}/{sample}_data/barcodes/reads.fastq"
        params:
            "{PROJECT}/runs/{run}/{sample}_data/barcodes/"
        benchmark:
            "{PROJECT}/runs/{run}/{sample}_data/barcodes/barcodes.benchmark"
        shell:
            "{config[qiime][path]}extract_barcodes.py -f {input.assembly} -c {config[ext_bc][c]} "
            "{config[ext_bc][bc_length]} {config[ext_bc][extra_params]} -o {params}"
#If allow mismatch correct bar code
    if config["bc_mismatch"]:
        rule correct_barcodes:
            input:
                bc="{PROJECT}/runs/{run}/{sample}_data/barcodes/barcodes.fastq",
                mapp="{PROJECT}/metadata/sampleList_mergedBarcodes_{sample}.txt"
            output:
                "{PROJECT}/runs/{run}/{sample}_data/barcodes/barcodes.fastq_corrected"
            benchmark:
                "{PROJECT}/runs/{run}/{sample}_data/barcodes/barcodes_corrected.benchmark"
            shell:
                "{config[Rscript][command]} Scripts/errorCorrectBarcodes.R $PWD {input.mapp} {input.bc} "  + str(config["bc_mismatch"])
#split libraries - demultiplex
    rule split_libraries:
        input:
            rFile="{PROJECT}/runs/{run}/{sample}_data/barcodes/reads.fastq",
            mapFile="{PROJECT}/metadata/sampleList_mergedBarcodes_{sample}.txt",
            bcFile="{PROJECT}/runs/{run}/{sample}_data/barcodes/barcodes.fastq_corrected" if config["bc_mismatch"] else "{PROJECT}/runs/{run}/{sample}_data/barcodes/barcodes.fastq",
            tmp3="{PROJECT}/metadata/bc_validation/{sample}/validation.log"
        output:
            seqs="{PROJECT}/runs/{run}/{sample}_data/splitLibs/seqs.fna", #marc as tmp
            spliLog="{PROJECT}/runs/{run}/{sample}_data/splitLibs/split_library_log.txt",
        params:
            outDir="{PROJECT}/runs/{run}/{sample}_data/splitLibs",
        benchmark:
            "{PROJECT}/runs/{run}/{sample}_data/splitLibs/splitLibs.benchmark"
        shell:
            "{config[qiime][path]}split_libraries_fastq.py -m {input.mapFile} -i {input.rFile} "
            "-o {params.outDir} -b {input.bcFile} -q {config[split][q]} -r {config[split][r]} "
            "--retain_unassigned_reads --barcode_type {config[split][barcode_type]} {config[split][extra_params]}"
#split libraries reverse complement
    rule get_unassigned:
        input:
            split="{PROJECT}/runs/{run}/{sample}_data/splitLibs/seqs.fna",
            assembly="{PROJECT}/runs/{run}/{sample}_data/peared/seqs.assembled.fastq"
        output:
            "{PROJECT}/runs/{run}/{sample}_data/splitLibs/unassigned.fastq"
        shell:
            "cat {input.split} | grep \"^>Unassigned\" |  sed 's/>Unassigned_[0-9]* /@/g' | "
            "sed 's/ .*//' | grep -F -w -A3  -f - {input.assembly} |  sed '/^--$/d' > {output}"
    rule rc_unassigned:
        input:
            "{PROJECT}/runs/{run}/{sample}_data/splitLibs/unassigned.fastq"
        output:
            "{PROJECT}/runs/{run}/{sample}_data/splitLibs/unassigned.reversed.fastq"
        shell:
            "vsearch --fastx_revcomp {input} --fastqout {output}"
    rule extract_barcodes_unassigned:
        input:
            assembly="{PROJECT}/runs/{run}/{sample}_data/splitLibs/unassigned.reversed.fastq"
        output:
            "{PROJECT}/runs/{run}/{sample}_data/barcodes_unassigned/barcodes.fastq",
            "{PROJECT}/runs/{run}/{sample}_data/barcodes_unassigned/reads.fastq"
        params:
            "{PROJECT}/runs/{run}/{sample}_data/barcodes_unassigned/"
        benchmark:
            "{PROJECT}/runs/{run}/{sample}_data/barcodes_unassigned/barcodes.benchmark"
        shell:
            "{config[qiime][path]}extract_barcodes.py -f {input.assembly} -c {config[ext_bc][c]} "
            "{config[ext_bc][bc_length]} {config[ext_bc][extra_params]} -o {params}"
#If allow mismatch correct bar code
    if config["bc_mismatch"]:
        rule correct_barcodes_unassigned:
            input:
                bc="{PROJECT}/runs/{run}/{sample}_data/barcodes_unassigned/barcodes.fastq",
                mapp="{PROJECT}/metadata/sampleList_mergedBarcodes_{sample}.txt"
            output:
                "{PROJECT}/runs/{run}/{sample}_data/barcodes_unassigned/barcodes.fastq_corrected"
            benchmark:
                "{PROJECT}/runs/{run}/{sample}_data/barcodes_unassigned/barcodes_corrected.benchmark"
            shell:
                "{config[Rscript][command]} Scripts/errorCorrectBarcodes.R $PWD {input.mapp} {input.bc} "  + str(config["bc_mismatch"])

    rule remove_unassigned:
        input:
            "{PROJECT}/runs/{run}/{sample}_data/splitLibs/seqs.fna"
        output:
            "{PROJECT}/runs/{run}/{sample}_data/splitLibs/seqs.assigned.fna"
        shell:
            "cat {input} | grep -P -A1 \"(?!>Unass)^>\" | sed '/^--$/d' > {output}"

    rule split_libraries_rc:
        """
        This rule will call a script in order to execute the librarie splitting for the
        RC sequences. It still need the seqs.fna file bz this file contains the exact
        number of sequences assigned during the first split, then the script takes that
        number and start to assign reads for the new splitting starting at the previous
        number...
        """

        input:
            spplited="{PROJECT}/runs/{run}/{sample}_data/splitLibs/seqs.fna",
            rFile="{PROJECT}/runs/{run}/{sample}_data/barcodes_unassigned/reads.fastq",
            mapFile="{PROJECT}/metadata/sampleList_mergedBarcodes_{sample}.txt",
            bcFile="{PROJECT}/runs/{run}/{sample}_data/barcodes_unassigned/barcodes.fastq_corrected" if config["bc_mismatch"]
            else "{PROJECT}/runs/{run}/{sample}_data/barcodes_unassigned/barcodes.fastq"
        output:
            seqsRC="{PROJECT}/runs/{run}/{sample}_data/splitLibsRC/seqs.fna", #marc as tmp
            spliLog="{PROJECT}/runs/{run}/{sample}_data/splitLibsRC/split_library_log.txt"
        params:
            outDirRC="{PROJECT}/runs/{run}/{sample}_data/splitLibsRC"
        benchmark:
            "{PROJECT}/runs/{run}/{sample}_data/splitLibsRC/splitLibs.benchmark"
        script:
            "Scripts/splitRC.py"
    rule validateDemultiplex:
        input:
            split="{PROJECT}/runs/{run}/{sample}_data/splitLibs/seqs.assigned.fna",
            splitRC="{PROJECT}/runs/{run}/{sample}_data/splitLibsRC/seqs.fna",
            logSplit="{PROJECT}/runs/{run}/{sample}_data/splitLibs/split_library_log.txt",
            logSplitRC="{PROJECT}/runs/{run}/{sample}_data/splitLibsRC/split_library_log.txt",
            allreads="{PROJECT}/runs/{run}/{sample}_data/barcodes/reads.fastq"
        output:
            "{PROJECT}/runs/{run}/{sample}_data/splitLibs/split_library_log.txt.validation"
        params:
            "{PROJECT}/runs/{run}/{sample}_data/splitLibs",
            "{PROJECT}/runs/{run}/{sample}_data/splitLibsRC"
        script:
            "Scripts/validateSplitNew.py"

    rule combine_accepted_reads:
        input:
            seqs="{PROJECT}/runs/{run}/{sample}_data/splitLibs/seqs.assigned.fna", #marc as tmp
            seqsRC="{PROJECT}/runs/{run}/{sample}_data/splitLibsRC/seqs.fna", #marc as
            tmpFlow="{PROJECT}/runs/{run}/{sample}_data/splitLibs/split_library_log.txt.validation"
        output:
            "{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_accepted.fna"
        benchmark:
            "{PROJECT}/runs/{run}/{sample}_data/combine_seqs_fw_rev.benchmark"
        shell:
            "cat {input.seqs} {input.seqsRC}  > {output}"

    if config["demultiplexing"]["create_fastq_files"] == "T":
        rule write_dmx_files:
            input:
                dmx="{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_accepted.fna",
                r1="{PROJECT}/samples/{sample}/rawdata/fw.fastq" if config["gzip_input"] == "F" else "{PROJECT}/samples/{sample}/rawdata/fw.fastq.gz",
                r2="{PROJECT}/samples/{sample}/rawdata/rv.fastq" if config["gzip_input"] == "F" else "{PROJECT}/samples/{sample}/rawdata/rv.fastq.gz"
            params:
                outdir="{PROJECT}/runs/{run}/{sample}_data/demultiplexed/"
            output:
                "{PROJECT}/runs/{run}/{sample}_data/demultiplexed/summary.txt"
            benchmark:
                "{PROJECT}/runs/{run}/{sample}_data/demultiplexed/demultiplex_fq.benchmark"
            shell:
                "{config[java][command]}  -cp Scripts DemultiplexQiime  --fasta  -d {input.dmx} -o {params.outdir} "
                "-r1 {input.r1} -r2 {input.r2} {config[demultiplexing][dmx_params]}"
    else:
        rule skip_dmx_file_creation:
            params:
                "{PROJECT}/runs/{run}/{sample}_data/demultiplexed/"
            output:
                "{PROJECT}/runs/{run}/{sample}_data/demultiplexed/summary.txt"
            shell:
                "touch {output}"

#if demultiplex{}
else:
    rule skip_demultiplexing_fq2fasta:
        input:
            extended_reads="{PROJECT}/runs/{run}/{sample}_data/peared/seqs.assembled.fastq",
            tmp_pear_validation="{PROJECT}/runs/{run}/{sample}_data/peared/pear.log.validation",
            tmp_pear_fq_validation="{PROJECT}/runs/{run}/{sample}_data/peared/qc/fq_fw_internal_validation.txt",
        output:
            "{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_accepted.fna"
        shell:
            #to change vsearch --fastq_filter N_debres_r1.txt -fastaout test.txt
            #"fq2fa {input.extended_reads} {output}"
            "sed -n '1~4s/^@/>/p;2~4p' {input.extended_reads} {output}"
    rule skip_dmx_file_creation:
        params:
            "{PROJECT}/runs/{run}/{sample}_data/demultiplexed/"
        output:
            "{PROJECT}/runs/{run}/{sample}_data/demultiplexed/summary.txt"
        shell:
            "touch {output}"

if config["align_vs_reference"]["align"] == "T":
    rule align_vs_reference:
        input:
            "{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_accepted.fna"
        output:
            "{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_accepted.align"
        params:
            "{PROJECT}/runs/{run}/{sample}_data/"
        shell:
            "cd {params} && "
            "{config[align_vs_reference][mothur_cmd]} '#align.seqs(fasta=seqs_fw_rev_accepted.fna, reference={config[align_vs_reference][dbAligned]}, processors={config[align_vs_reference][cpus]})'"

if config["cutAdapters"] == "T":
    rule cutadapt:
        input:
            "{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_accepted.align" if config["align_vs_reference"]["align"] == "T"
            else "{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_accepted.fna"
        output:
            out="{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_accepted_no_adapters.fna",
            log="{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_accepted_no_adapters.log"
        benchmark:
           "{PROJECT}/runs/{run}/{sample}_data/cutadapt.benchmark"
        shell:
           "{config[cutadapt][command]} -f fasta {config[cutadapt][adapters]} "
           "{config[cutadapt][extra_params]} -o {output.out} {input}  > {output.log}"

if config["align_vs_reference"]["align"] == "T":
    rule degap_alignment:
        input:
            "{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_accepted.align" if config["cutAdapters"] != "T"
            else "{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_accepted_no_adapters.fna"
        output:
            "{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_accepted.align.degapped.fna" if config["cutAdapters"] != "T"
            else "{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_accepted.align.no_adapter.degapped.fna"
        shell:
            "degapseq {input} {output}"

    rule single_line_fasta:
        input:
            "{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_accepted.align.degapped.fna" if config["cutAdapters"] != "T"
            else "{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_accepted.align.no_adapter.degapped.fna"
        output:
            "{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_accepted.align.degapped.oneline.fna" if config["cutAdapters"] != "T"
            else "{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_accepted.align.no_adapter.degapped.oneline.fna"
        shell:
            "{config[java][command]} -cp Scripts FastaOneLine -f {input} -m 1 --write-discarded -o {output}"


#Creates file with sequence length ditribution
rule histogram:
    input:
        #"{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_accepted_nc.fna",
        #"{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_accepted.fna" #for tmp
        *selectInput()
    output:
        temp("{PROJECT}/runs/{run}/{sample}_data/seqs_accepted_lengths.txt"),
        temp("{PROJECT}/runs/{run}/{sample}_data/seqs_accepted_hist.txt")
    shell:
        "cat {input} | grep -v '^>' | awk '{{print length}}' > {output[0]} "
        "&&  sort -g {output[0]} | uniq -c > {output[1]}"

rule histogram_chart:
    input:
        "{PROJECT}/runs/{run}/{sample}_data/seqs_accepted_hist.txt",
        "{PROJECT}/runs/{run}/{sample}_data/seqs_accepted_lengths.txt"
    output:
        "{PROJECT}/runs/{run}/report_files/seqs_dist_hist.{sample}.png",
        "{PROJECT}/runs/{run}/{sample}_data/seqs_statistics.txt"
    params:
        "{PROJECT}/runs/{run}/{sample}_data/",
        "{PROJECT}/runs/{run}/report_files/",
        "{sample}"
    shell:
        "{config[Rscript][command]} Scripts/histogram.R $PWD {input[0]} {input[1]} {params[0]} {output[0]}"

#remove to long and to short sequences
rule remove_short_long_reads:
    input:
        "{PROJECT}/runs/{run}/{sample}_data/seqs_statistics.txt",
        "{PROJECT}/runs/{run}/report_files/seqs_dist_hist.{sample}.png",
        "{PROJECT}/runs/{run}/{sample}_data/seqs_accepted_hist.txt",
        *selectInput()
        #"{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_accepted_nc.fna"
    #params:
    #    "{PROJECT}/runs/{run}/{sample}_data/splitLibs"
    output:
        "{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_filtered.fasta",
        "{PROJECT}/runs/{run}/{sample}_data/filter.log"
    benchmark:
        "{PROJECT}/runs/{run}/{sample}_data/filter.benchmark"
    script:
        "Scripts/rmShortLong.py"


if config["chimera"]["search"] == "T":
#check for chimeric sequences
    if config["chimera"]["method"] == "usearch61":
        rule search_chimera:
            input:
                "{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_filtered.fasta"
            #if (config["align_vs_reference"]["align"] == "T" and config["cutAdapters"] == "T") "{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_accepted.align.no_adapter.degapped.fna"
            #elif (config["align_vs_reference"]["align"] == "T" and config["cutAdapters"] != "T") "{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_accepted.align.degapped.fna"
            #elif (config["align_vs_reference"]["align"] != "T" and config["cutAdapters"] == "T") "{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_accepted_no_adapters.fna"
            #else "{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_accepted.fna"
            #*selectInput()
            output:
                "{PROJECT}/runs/{run}/{sample}_data/chimera/chimeras.txt"
            params:
                "{PROJECT}/runs/{run}/{sample}_data/chimera"
            benchmark:
                "{PROJECT}/runs/{run}/{sample}_data/chimera/chimera.benchmark"
            shell:
                "{config[qiime][path]}identify_chimeric_seqs.py -m {config[chimera][method]} -i {input}  -o {params} --threads {config[chimera][threads]} {config[chimera][extra_params]}"
            #remove chimeras
    else:
        rule search_chimera_vsearch:
            input:
                "{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_filtered.fasta"
            output:
                "{PROJECT}/runs/{run}/{sample}_data/chimera/chimeras.summary.txt"
            benchmark:
                "{PROJECT}/runs/{run}/{sample}_data/chimera/chimera.benchmark"
            shell:
                "vsearch --{config[chimera][method]} {input} --threads {config[chimera][threads]} {config[chimera][extra_params]} --uchimeout {output}"
        rule filter_chimera_vsearch:
            input:
                "{PROJECT}/runs/{run}/{sample}_data/chimera/chimeras.summary.txt"
            output:
                "{PROJECT}/runs/{run}/{sample}_data/chimera/chimeras.txt"
            shell:
                "cat {input} | awk '$18==\"Y\"{{print $2\"\\t\"$1}}' > {output}"
    rule remove_chimera:
        """
        This script counts the sequence in input[0], the chimeras in input[2] if it is interactive it
        directly removes the chimeras, otherwise ask the user, if the selection is NO, it will rename
        input[0] as output[0]
        """
        input:
            "{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_filtered.fasta",
            #"{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_accepted.align.no_adapter.degapped.fna" if config["align_vs_reference"]["align"] == "T" and config["cutAdapters"] == "T"
            #"{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_accepted.align.degapped.fna" elif config["align_vs_reference"]["align"] == "T" and config["cutAdapters"] != "T"
            #"{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_accepted_no_adapters.fna" elif config["align_vs_reference"]["align"] != "T" and config["cutAdapters"] == "T"
            #else "{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_accepted.fna",
            #*selectInput(),
            "{PROJECT}/runs/{run}/{sample}_data/chimera/chimeras.txt"
        output:
            "{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_filtered_nc.fasta",
            "{PROJECT}/runs/{run}/{sample}_data/chimera/chimera.log"
        script:
            "Scripts/remove_chimera.py"

rule count_samples_final:
    input:
        fasta="{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_filtered_nc.fasta" if config["chimera"]["search"] == "T"
        else "{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_filtered.fasta",
        metadata="{PROJECT}/metadata/sampleList_mergedBarcodes_{sample}.txt"
    output:
        "{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_filtered.dist.txt"
    shell:
        "cat {input.fasta} | grep '^>' |  cut -d'_' -f1 | sed 's/>//g' "
        "| sort | uniq -c | sort -nr | awk '{{print $1\"\\t\"$2}}' "
        "| awk 'NR==FNR{{h[$2]=$1; next}} {{print $1\"\\t\"h[$1]}}' - {input.metadata} | grep -v \"#\" > {output}"

rule distribution_chart:
    input:
        "{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_filtered.dist.txt"
    output:
        "{PROJECT}/runs/{run}/report_files/seqs_fw_rev_filtered.{sample}.dist.png"
    params:
        "{PROJECT}/runs/{run}/report_files/"
    script:
        "Scripts/sampleDist.py"

rule combine_filtered_samples:
        input:
            allFiltered = expand("{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_filtered_nc.fasta" if config["chimera"]["search"] == "T" else  "{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_filtered.fasta",PROJECT=config["PROJECT"],sample=config["LIBRARY"], run=run)
        output:
            "{PROJECT}/runs/{run}/seqs_fw_rev_combined.fasta"
        benchmark:
            "{PROJECT}/runs/{run}/combine_seqs_fw_rev.benchmark"
        script:
            "Scripts/combineAllReads.py"

#Dereplicate
if config["derep"]["dereplicate"] == "T" and config["pickOTU"]["m"] != "swarm" and config["pickOTU"]["m"] != "usearch":
    rule dereplicate:
        input:
            "{PROJECT}/runs/{run}/seqs_fw_rev_combined.fasta"
        output:
            #"{PROJECT}/runs/{run}/derep/seqs_fw_rev_combined_otus.txt", <- picking OTUs method
            "{PROJECT}/runs/{run}/derep/seqs_fw_rev_combined_derep.fasta",
            "{PROJECT}/runs/{run}/derep/seqs_fw_rev_combined_derep.uc"
        params:
            "{PROJECT}/runs/{run}/derep/"
        benchmark:
            "{PROJECT}/runs/{run}/derep/derep.benchmark"
        shell:
            "{config[derep][vsearch_cmd]} --derep_fulllength {input} --output {output[0]} --uc {output[1]} --strand {config[derep][strand]} "
            "--fasta_width 0 --minuniquesize {config[derep][min_abundance]}"

#cluster OTUs
rule cluster_OTUs:
    input:
        "{PROJECT}/runs/{run}/derep/seqs_fw_rev_combined_derep.fasta" if config["derep"]["dereplicate"] == "T" and config["pickOTU"]["m"] != "swarm"
        and config["pickOTU"]["m"] != "usearch" else "{PROJECT}/runs/{run}/seqs_fw_rev_combined.fasta"
        #"{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_filtered.fasta"
    output:
        "{PROJECT}/runs/{run}/otu/seqs_fw_rev_combined_derep_otus.txt" if config["derep"]["dereplicate"] == "T" and config["pickOTU"]["m"] != "swarm"
        and config["pickOTU"]["m"] != "usearch" else "{PROJECT}/runs/{run}/otu/seqs_fw_rev_combined_otus.txt"
    params:
        trieDir="{PROJECT}/runs/{run}/otu/"
    benchmark:
        "{PROJECT}/runs/{run}/otu.benchmark"
    shell:
        "{config[qiime][path]}pick_otus.py -m {config[pickOTU][m]} -i {input} "
        "-o {params.trieDir}  -s {config[pickOTU][s]} --threads {config[pickOTU][cpus]} {config[pickOTU][extra_params]} "

if config["derep"]["dereplicate"] == "T" and config["pickOTU"]["m"] != "swarm"  and config["pickOTU"]["m"] != "usearch":
    rule remap_clusters:
        input:
            otu_txt="{PROJECT}/runs/{run}/otu/seqs_fw_rev_combined_derep_otus.txt",
            uc_derep="{PROJECT}/runs/{run}/derep/seqs_fw_rev_combined_derep.uc"
        output:
            "{PROJECT}/runs/{run}/otu/seqs_fw_rev_combined_remapped_otus.txt"
        shell:
            "{config[java][command]} -cp Scripts/ClusterMapper/build/classes clustermapper.ClusterMapper uc2otu "
            "-uc {input.uc_derep} -otu {input.otu_txt} -o {output}"
#pick representative OTUs
rule pick_representatives:
    input:
        otus="{PROJECT}/runs/{run}/otu/seqs_fw_rev_combined_derep_otus.txt" if config["derep"]["dereplicate"] == "T" and config["pickOTU"]["m"] != "swarm"
        and config["pickOTU"]["m"] != "usearch" else "{PROJECT}/runs/{run}/otu/seqs_fw_rev_combined_otus.txt",
        filtered="{PROJECT}/runs/{run}/seqs_fw_rev_combined.fasta"
        #filtered="{PROJECT}/runs/{run}/{sample}_data/seqs_fw_rev_filtered.fasta"
    output:
        reps="{PROJECT}/runs/{run}/otu/representative_seq_set.fasta",
        log="{PROJECT}/runs/{run}/otu/representative_seq_set.log"
    benchmark:
        "{PROJECT}/runs/{run}/pick_reps.benchmark"
    shell:
        "{config[qiime][path]}pick_rep_set.py -m {config[pickRep][m]} -i {input.otus} "
        "-f {input.filtered} -o {output.reps} --log_fp {output.log} {config[pickRep][extra_params]}"


#assign taxonomy to representative OTUs
if  config["assignTaxonomy"]["tool"] == "blast":
    rule assign_taxonomy:
        input:
            "{PROJECT}/runs/{run}/otu/representative_seq_set.fasta"
        output:
            temp("{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/representative_seq_set_tax_blastn.out")
        params:
            reference="-db " +config["assignTaxonomy"]["blast"]["blast_db"] if len(str(config["assignTaxonomy"]["blast"]["blast_db"])) > 1
            else "-subject " +config["assignTaxonomy"]["blast"]["fasta_db"]
        benchmark:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/assign_taxa.benchmark"
        shell:
            "{config[assignTaxonomy][blast][command]} {params.reference} -query {input} -evalue {config[assignTaxonomy][blast][evalue]} "
            "-outfmt '6 qseqid sseqid pident qcovs evalue bitscore' -num_threads {config[assignTaxonomy][blast][jobs]} "
            "-max_target_seqs {config[assignTaxonomy][blast][max_target_seqs]} -perc_identity {config[assignTaxonomy][blast][identity]} "
            "{config[assignTaxonomy][blast][extra_params]} -out {output[0]} "
    rule complete_blast_out:
        """
         Add missing ids to blast out
        """
        input:
            blastout="{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/representative_seq_set_tax_blastn.out",
            otus="{PROJECT}/runs/{run}/otu/seqs_fw_rev_combined_derep_otus.txt" if config["derep"]["dereplicate"] == "T" and config["pickOTU"]["m"] != "swarm"
            and config["pickOTU"]["m"] != "usearch" else "{PROJECT}/runs/{run}/otu/seqs_fw_rev_combined_otus.txt"
        output:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/representative_seq_set_tax_blastn.complete.out"
        benchmark:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/complte_blast.assign_taxa.benchmark"
        shell:
            "cat {input.blastout} | cut -f1 | sort | uniq | grep -v -w -F -f - {input.otus} "
            "| awk '{{print $1\"\\tUnassigned\\t-\\t-\\t-\\t-\"}}' | cat {input.blastout} - > {output}"

    rule prepare_blast_for_stampa:
        """
         Take completed blast output file and make some reformat in order to
         fulfill stampa format.
        """
        input:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/representative_seq_set_tax_blastn.complete.out"
        output:
            temp("{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/hits.blast.out")
        benchmark:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/assign_taxa.hits.benchmark"
        shell:
            "cat {input}  | cut -f2 | sort | uniq | grep -F -w -f -  {config[assignTaxonomy][blast][mapFile]} | "
            "awk 'NR==FNR {{h[$1] = $2; next}} {{print $1\"\\t\"$3\"\\t\"$2\" \"h[$2]}}' FS=\"\\t\" - FS=\"\\t\" {input} "
            " > {output}"
    rule run_stampa:
        """
         compute lca using stampa merge script
        """
        input:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/hits.blast.out"
        params:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/"
        output:
            temp("{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/results.blast.out")
        benchmark:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/stampa.benchmark"
        shell:
            "Scripts/stampa_merge.py {params} {config[assignTaxonomy][blast][taxo_separator]}"
    rule normalize_taxo_out:
        """
         Normalize the output in terms of its format and names in order to be able
         to continue with the pipeline
        """
        input:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/results.blast.out"
        output:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/representative_seq_set_tax_assignments.txt"
        benchmark:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/stampa.benchmark"
        shell:
            "cat {input} |  awk -F\"\\t\" '{{print $1\"\\t\"$4\"\\t\"$3\"\\t\"$5}}' | sed 's/N;o;_;h;i;t/Unassigned/' > {output}"

elif  config["assignTaxonomy"]["tool"] == "vsearch":
    rule assign_taxonomy:
        input:
            "{PROJECT}/runs/{run}/otu/representative_seq_set.fasta"
        output:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/representative_seq_set_tax_vsearch.out"
        params:
            reference="-db " +config["assignTaxonomy"]["blast"]["blast_db"] if len(str(config["assignTaxonomy"]["blast"]["blast_db"])) > 1
            else "-subject " +config["assignTaxonomy"]["blast"]["fasta_db"]
        benchmark:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/assign_taxa.benchmark"
        shell:
            "{config[assignTaxonomy][vsearch][command]}  --usearch_global {input} --db {config[assignTaxonomy][vsearch][db_file]} "
            "--dbmask none --qmask none --rowlen 0 --id {config[assignTaxonomy][vsearch][identity]} "
            "--iddef {config[assignTaxonomy][vsearch][identity_definition]}  --userfields query+id{config[assignTaxonomy][vsearch][identity_definition]}+target "
            "--threads {config[assignTaxonomy][vsearch][jobs]} {config[assignTaxonomy][vsearch][extra_params]} "
            " --maxaccepts {config[assignTaxonomy][vsearch][max_target_seqs]} --output_no_hits --userout {output[0]} "

    rule mapp_vsearch_taxo:
        """
         Take completed blast output file and make some reformat in order to
         fulfill stampa format.
        """
        input:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/representative_seq_set_tax_vsearch.out"
        output:
            temp("{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/taxons.txt")
        benchmark:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/assign_taxa.map.benchmark"
        shell:
            "cat {input}  | cut -f3 | sort | uniq | grep -F -w -f -  {config[assignTaxonomy][vsearch][mapFile]} > {output} "

    rule prepare_vsearch_for_stampa:
        """
         Take completed blast output file and make some reformat in order to
         fulfill stampa format.
        """
        input:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/taxons.txt",
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/representative_seq_set_tax_vsearch.out"
        output:
            temp("{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/hits.vsearch.out")
        benchmark:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/assign_taxa.hits.benchmark"
        shell:
            "echo '*\\tUnassigned' | cat {input[0]} - | awk 'NR==FNR {{h[$1] = $2; next}} {{print $1\"\\t\"$2\"\\t\"$3\" \"h[$3]}}' FS=\"\\t\" - FS=\"\\t\" {input[1]} "
            " > {output}"

    rule run_stampa:
        """
         compute lca using stampa merge script
        """
        input:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/hits.vsearch.out"
        params:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/"
        output:
            temp("{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/results.vsearch.out")
        benchmark:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/stampa.benchmark"
        shell:
            "Scripts/stampa_merge.py {params} {config[assignTaxonomy][vsearch][taxo_separator]}"
    rule normalize_taxo_out:
        """
         Normalize the output in terms oif format and names in order to be table
         to continjue with the pipeline
        """
        input:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/results.vsearch.out"
        output:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/representative_seq_set_tax_assignments.txt"
        benchmark:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/stampa.benchmark"
        shell:
            "cat {input} |  awk -F\"\\t\" '{{print $1\"\\t\"$4\"\\t\"$3\"\\t\"$5}}' | sed 's/N;o;_;h;i;t/Unassigned/' > {output}"

else:
    rule assign_taxonomy:
        input:
            "{PROJECT}/runs/{run}/otu/representative_seq_set.fasta"
        output:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/representative_seq_set_tax_assignments.txt",
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/representative_seq_set_tax_assignments.log"
        params:
            outdir="{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/"
        benchmark:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/assign_taxa.benchmark"
        shell:
            "{config[qiime][path]}parallel_assign_taxonomy_{config[assignTaxonomy][qiime][method]}.py -i {input} --id_to_taxonomy_fp {config[assignTaxonomy][qiime][mapFile]} "
            "{config[assignTaxonomy][qiime][dbType]} {config[assignTaxonomy][qiime][dbFile]} --jobs_to_start {config[assignTaxonomy][qiime][jobs]} "
            "--output_dir {params.outdir}  {config[assignTaxonomy][qiime][extra_params]}"

rule make_otu_table:
    input:
        tax="{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/representative_seq_set_tax_assignments.txt",
        otus="{PROJECT}/runs/{run}/otu/seqs_fw_rev_combined_remapped_otus.txt" if config["derep"]["dereplicate"] == "T" and config["pickOTU"]["m"] != "swarm"
        and config["pickOTU"]["m"] != "usearch" else "{PROJECT}/runs/{run}/otu/seqs_fw_rev_combined_otus.txt"
    output:
        "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/otuTable.biom"
    benchmark:
        "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/otuTable.biom.benchmark"
    shell:
        "{config[qiime][path]}make_otu_table.py -i {input.otus} -t {input.tax} -o {output} {config[makeOtu][extra_params]}"

#filter OTU table
rule summarize_taxa:
    input:
        "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/otuTable.biom"
    output:
        "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/summary/otuTable_L6.txt"
    params:
        "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/summary/"
    benchmark:
        "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/summary/summarize_taxa.benchmark"
    shell:
        "{config[qiime][path]}summarize_taxa.py -i {input} -o {params} {config[summTaxa][extra_params]}"

#Converts otu table from biom format to tsv
rule convert_table:
    input:
        "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/otuTable.biom",
        #"{PROJECT}/runs/{run}/otu/taxa_"+config["assignTaxonomy"]["method"]+"/"
    output:
        "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/otuTable.txt"
    benchmark:
        "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/otuTable.txt.benchmark"
    shell:
        "{config[biom][command]} convert -i {input[0]} -o {output} {config[biom][tableType]} "
        "{config[biom][headerKey]} {config[biom][outFormat]} {config[biom][extra_params]}"

#filter OTU table
rule filter_otu:
    input:
        "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/otuTable.biom"
    output:
        "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/otuTable_noSingletons.biom"
    benchmark:
        "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/otuTable_nosingletons.bio.benchmark"
    shell:
        "{config[qiime][path]}filter_otus_from_otu_table.py -i {input} -o {output} -n {config[filterOtu][n]} {config[filterOtu][extra_params]}"
#Convert to/from the BIOM table format.
rule convert_filter_otu:
    input:
        "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/otuTable_noSingletons.biom"
    output:
        "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/otuTable_noSingletons.txt"
    benchmark:
        "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/otuTable_nosingletons.txt.benchmark"
    shell:
        "{config[biom][command]} convert -i {input} -o {output} {config[biom][tableType]} "
        "{config[biom][headerKey]} {config[biom][outFormat]} {config[biom][extra_params]}"

if  config["krona"]["report"].casefold() == "t" or config["krona"]["report"].casefold() == "true":
    rule krona_report:
        input:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/otuTable_noSingletons.txt" if config["krona"]["otu_table"].casefold() != "singletons"
            else "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/otuTable.txt"
        output:
            "{PROJECT}/runs/{run}/report_files/krona_report."+config["assignTaxonomy"]["tool"]+".html"
        params:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/"
        benchmark:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/krona_report.benchmark"
        script:
            "Scripts/otu2krona.py"
else:
    rule skip_krona:
        output:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/skip.krona"
        shell:
            "touch {output}"
#OTU map-based filtering: Keep all sequences that show up in an OTU map.
rule filter_rep_seqs:
    input:
        fastaRep="{PROJECT}/runs/{run}/otu/representative_seq_set.fasta",
        otuNoSingleton="{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/otuTable_noSingletons.biom"
    output:
        "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/representative_seq_set_noSingletons.fasta"
    benchmark:
        "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/representative_seq_set_noSingletons.benchmark"
    shell:
        "{config[qiime][path]}filter_fasta.py -f {input.fastaRep} -o {output} -b {input.otuNoSingleton} {config[filterFasta][extra_params]}"
if config["alignRep"]["align"] == "T":
#Align representative sequences
    rule align_rep_seqs:
        input:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/representative_seq_set_noSingletons.fasta"
        output:
            aligned="{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/aligned/representative_seq_set_noSingletons_aligned.fasta",
            log="{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/aligned/representative_seq_set_noSingletons_log.txt"
        params:
            outdir="{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/aligned/"
        benchmark:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/aligned/align_rep_seqs.benchmark"
        shell:
            "{config[qiime][path]}align_seqs.py -m {config[alignRep][m]} -i {input} -o {params.outdir} {config[alignRep][extra_params]}"

#This step should be applied to generate a useful tree when aligning against a template alignment (e.g., with PyNAST)
    rule filter_alignment:
        input:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/aligned/representative_seq_set_noSingletons_aligned.fasta"
        output:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/aligned/filtered/representative_seq_set_noSingletons_aligned_pfiltered.fasta"
        params:
            outdir="{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/aligned/filtered/"
        benchmark:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/aligned/filtered/align_rep_seqs.benchmark"
        shell:
            "{config[qiime][path]}filter_alignment.py -i {input} -o {params.outdir} {config[filterAlignment][extra_params]}"

#Many downstream analyses require that the phylogenetic tree relating the OTUs in a study be present.
#The script make_phylogeny.py produces this tree from a multiple sequence alignment
    rule make_tree:
        input:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/aligned/filtered/representative_seq_set_noSingletons_aligned_pfiltered.fasta"
        output:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/aligned/filtered/representative_seq_set_noSingletons_aligned_pfiltered.tre"
        benchmark:
            "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/aligned/filtered/representative_seq_set_noSingletons_aligned_pfiltered.benchmark"
        shell:
            "{config[qiime][path]}make_phylogeny.py -i {input} -o {output} -t {config[makeTree][method]} {config[makeTree][extra_params]}"

rule report_all:
   input:
        a="{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/otuTable.txt",
        b="{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/summary/otuTable_L6.txt",
        c="{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/otuTable_noSingletons.txt",
        e="{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/aligned/filtered/representative_seq_set_noSingletons_aligned_pfiltered.tre"
        if config["alignRep"]["align"] == "T" else
        "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/representative_seq_set_noSingletons.fasta",
        f="{PROJECT}/runs/{run}/report_files/krona_report."+config["assignTaxonomy"]["tool"]+".html"
        if config["krona"]["report"] == "T" else
        "{PROJECT}/runs/{run}/otu/taxonomy_"+config["assignTaxonomy"]["tool"]+"/skip.krona"
   output:
        temp("{PROJECT}/runs/{run}/reporttmp_all.html")
   benchmark:
        "{PROJECT}/runs/{run}/report_all.benchmark"
   script:
        "Scripts/report_all_v2.py"

rule tune_report_all:
    input:
        "{PROJECT}/runs/{run}/reporttmp_all.html"
    output:
        "{PROJECT}/runs/{run}/otu_report_"+config["assignTaxonomy"]["tool"]+".html"
    script:
        "Scripts/tuneReport.py"
if config["pdfReport"].casefold() == "t":
    rule translate_to_pdf:
        input:
            "{PROJECT}/runs/{run}/otu_report_"+config["assignTaxonomy"]["tool"]+".html"
        output:
            "{PROJECT}/runs/{run}/otu_report_"+config["assignTaxonomy"]["tool"]+".pdf"
        shell:
            "wkhtmltopdf {input} {output}"

rule report:
    input:
        report_all="{PROJECT}/runs/{run}/otu_report_"+config["assignTaxonomy"]["tool"]+".html",
        dist_chart="{PROJECT}/runs/{run}/report_files/seqs_fw_rev_filtered.{sample}.dist.png",
        dmxFiles="{PROJECT}/runs/{run}/{sample}_data/demultiplexed/summary.txt"
    output:
        temp("{PROJECT}/runs/{run}/{sample}_data/report.html")
    script:
        "Scripts/report_v2.py"
rule tune_report:
    input:
        "{PROJECT}/runs/{run}/{sample}_data/report.html"
    output:
        "{PROJECT}/runs/{run}/report_{sample}_"+config["assignTaxonomy"]["tool"]+".html"
    script:
        "Scripts/tuneReport.py"
if config["pdfReport"].casefold() == "t":
    rule translate_pdf_final_report:
        input:
            toTranslate="{PROJECT}/runs/{run}/report_{sample}_"+config["assignTaxonomy"]["tool"]+".html",
            tmp="{PROJECT}/runs/{run}/otu_report_"+config["assignTaxonomy"]["tool"]+".pdf"
        output:
            "{PROJECT}/runs/{run}/report_{sample}_"+config["assignTaxonomy"]["tool"]+".pdf"
        shell:
            "{config[wkhtmltopdf_command]} {input.toTranslate} {output}"

rule create_portable_report:
    input:
        expand("{PROJECT}/runs/{run}/report_{sample}_"+config["assignTaxonomy"]["tool"]+".html", PROJECT=config["PROJECT"],sample=config["LIBRARY"], run=run),
        "{PROJECT}/runs/{run}/otu_report_"+config["assignTaxonomy"]["tool"]+".html"
    output:
        "{PROJECT}/runs/{run}/report_"+config["assignTaxonomy"]["tool"]+".zip"
    params:
        "{PROJECT}/runs/{run}/report_files"
    shell:
        "zip -r {output} {params} {input}"
