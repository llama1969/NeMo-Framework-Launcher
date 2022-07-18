#!/bin/bash

log_dir=${1}
input_length=${2}
output_length=${3}
input_len_name=${4}
output_len_name=${5}
vocab_size=${6}
tensor_para=${7}
pipeline_para=${8}
request_batch_sizes=${@:9}

all_log=${log_dir}/all-${input_length}-${output_length}.log

# vocab_size=29184
# vocab_size=51200

echo -e "| Batch Size | Input length | Output length | FT latency (ms) | Throughput per GPU (sentence/s) |" > $all_log

for request_batch_size in ${request_batch_sizes[@]}; do
    tmp_log=${log_dir}/bs-${request_batch_size}-${input_length}-${output_length}.log
    python3 /lustre/fsw/joc/donghyukc/bignlp-scripts/bignlp/inference_scripts/identity_test.py --vocab_size ${vocab_size} -r -s ${input_length} -o ${output_length} --input_len_name ${input_len_name} --output_len_name ${output_len_name} -b ${request_batch_size} 2>&1 | tee ${tmp_log}
    ft_latency=`tail -n 1 ${tmp_log} | head -n 1 | awk '{print $4}'`
    num_gpu=`echo $tensor_para \* $pipeline_para | bc`
    throughput_ms=`echo "($request_batch_size / $ft_latency) / $num_gpu" | bc -l`
    throughput_s=`echo $throughput_ms \* 1000 | bc -l`
    echo "" | awk -v ft_latency=$ft_latency \
                -v throughput_s=$throughput_s \
                -v request_batch_size=$request_batch_size \
                -v input_length=$input_length -v output_length=$output_length \
                '{printf "%3d, %4d, %4d, %7.2f, %7.2f\n", request_batch_size, input_length, output_length, ft_latency, throughput_s}' >> $all_log
done
