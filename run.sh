#!/bin/bash
# https://github.com/subhh/FID-Romanistik-metadataTransformations

# change directory to location of shell script
cd $(dirname $0)

# pathnames
openrefine_server="$(readlink -f opt/openrefine/refine)"
openrefine_client="$(readlink -f opt/openrefine-client)"
data_dir="$(readlink -f data)"
log_dir="$(readlink -f log)"

# config
ram="2048M" # highest OpenRefine memory load is below 2048M
separator="%E2%90%9F" # multiple values are separated by unicode character unit separator (U+241F)
config_dir="$(readlink -f cfg/all)" # location of OpenRefine transformation rules in json format

# help screen
function usage () {
    cat <<EOF
Usage: ./run.sh [-s SOLRURL] [-d OPENREFINEURL]

== options ==
    -s SOLRURL       ingest data to specified Solr core
    -d OPENREFINEURL ingest data to external OpenRefine service

== example ==
./run.sh -s http://localhost:8983/solr/fid-rom -d http://localhost:3333
EOF
   exit 1
}

# defaults
port="3334"

# get user input
options="s:d:h"
while getopts $options opt; do
   case $opt in
   s )  solr_url=${OPTARG%/} ;;
   d )  openrefine_url=${OPTARG%/} ;;
   h )  usage ;;
   \? ) echo 1>&2 "Unknown option: -$OPTARG"; usage; exit 1;;
   :  ) echo 1>&2 "Missing option argument for -$OPTARG"; usage; exit 1;;
   *  ) echo 1>&2 "Unimplemented option: -$OPTARG"; usage; exit 1;;
   esac
done
shift $((OPTIND - 1))

# declare additional variables
pid=()
path_bin=$(readlink -f bin)
path_log=$(readlink -f log)
date=$(date +%Y%m%d_%H%M)
openrefine_tmp="/tmp/openrefine_${date}"
checkpoints=${#checkpointdate[@]}
checkpointdate[$((checkpoints + 1))]=$(date +%s)
checkpointname[$((checkpoints + 1))]="Start process"
memoryload=()
multivalue_config=()
external=${openrefine_url##*/}
external_host=${external%:*}
external_port=${external##*:}
if [ -n "${config_dir// }" ] ; then jsonfiles=($(find -L "${config_dir}"/*.json -type f -printf "%f\n" 2>/dev/null)) ; fi

# safe cleanup handler
cleanup()
{
  echo "cleanup..."
  for i in ${pid[@]}; do
    kill $i &>/dev/null &
  done
  kill -9 ${pid_openrefine} &>/dev/null
  rm -rf /tmp/openrefine_${date}
  wait
}
trap "cleanup;exit" SIGHUP SIGINT SIGQUIT SIGTERM

# Simple Logging
exec &> >(tee -a "${log_dir}/all_${date}.log")

# print variables
echo "Solr core URL:           $solr_url"
echo "OpenRefine service URL:  $openrefine_url"
echo "Logfile:                 all_${date}.log"
echo ""

# run jobs in parallel
checkpoints=${#checkpointdate[@]}
checkpointdate[$((checkpoints + 1))]=$(date +%s)
checkpointname[$((checkpoints + 1))]="Download and transform all data"
echo "=== $checkpoints. ${checkpointname[$((checkpoints + 1))]} ==="
echo ""
echo "starting time: $(date --date=@${checkpointdate[$((checkpoints + 1))]})"
echo ""
echo "run scripts in parallel..."
for f in "${path_bin}"/*.sh; do
  "${f}" -p $port > /dev/null &
  pid+=("$!")
  echo -en "$(basename ${f}) (pid: $!)   "
  port=$((port + 1))
done
echo ""
echo ""
echo "wait until all jobs are done..."
count="1"
until [[ "$count" -eq "0" ]]; do
  stats=$(ps --no-headers -o %mem,%cpu ax | awk '{mem += $1; cpu += $2} END {print "%MEM: " mem, "  %CPU: " cpu}')
  count=$(ps --no-headers -p ${pid[@]} | wc -l)
  echo -en "\r $stats   Jobs: $count running   Elapsed: $SECONDS seconds    "
  sleep 5
done
echo ""
echo ""
echo "print stats and exceptions from logs..."
for f in "${path_bin}"/*.sh; do
  stats=$(tail -n 3 "${path_log}/$(basename -s .sh ${f})_${date}"*.log |  sed 's/total run time://' | sed 's/highest memory load://' | sed 's/number of records://')
  exceptions=$(grep -i exception "${path_log}/$(basename -s .sh ${f})_${date}"*.log)
  echo $(basename ${f}): $stats
  if [ -n "$exceptions" ]; then
    echo 1>&2 "$exceptions"
    echo 1>&2 "Konfiguration für ${f} scheint fehlerhaft zu sein! Bitte manuell prüfen."
    exit 2
  fi
done
echo ""

# combine all transformed data
checkpoints=${#checkpointdate[@]}
checkpointdate[$((checkpoints + 1))]=$(date +%s)
checkpointname[$((checkpoints + 1))]="Combine all transformed data"
echo "=== $checkpoints. ${checkpointname[$((checkpoints + 1))]} ==="
echo ""
echo "starting time: $(date --date=@${checkpointdate[$((checkpoints + 1))]})"
echo ""
echo "zip transformed data..."
mkdir -p "${openrefine_tmp}"
zip ${openrefine_tmp}/tmp.zip "${data_dir}/02_transformed/"*"_${date}"*".tsv"
echo ""
echo "launch OpenRefine server..."
$openrefine_server -p ${port} -d "$openrefine_tmp" -m ${ram} -v error &
pid_openrefine=$!
until wget -q -O - http://localhost:${port} | cat | grep -q -o "OpenRefine" ; do sleep 1; done
echo ""
echo "load data..."
$openrefine_client -P ${port} --create "${openrefine_tmp}/tmp.zip" --format=tsv --includeFileSources=false --projectName=all
ps -o start,etime,%mem,%cpu,rss -p ${pid_openrefine} --sort=start
memoryload+=($(ps --no-headers -o rss -p ${pid_openrefine}))
echo ""
for f in "${jsonfiles[@]}" ; do
    echo "transform ${f}..."
    $openrefine_client -P ${port} --apply "${config_dir}/${f}" "all"
    ps -o start,etime,%mem,%cpu,rss -p ${pid_openrefine} --sort=start
    memoryload+=($(ps --no-headers -o rss -p ${pid_openrefine}))
    echo ""
done
echo "export data..."
$openrefine_client -P ${port} --export --output="${data_dir}/03_combined/all_${date}.tsv" "all"
ps -o start,etime,%mem,%cpu,rss -p ${pid_openrefine} --sort=start
memoryload+=($(ps --no-headers -o rss -p ${pid_openrefine}))
echo ""
cleanup
echo ""

# Ingest data into Solr
if [ -n "$solr_url" ]; then
  checkpoints=${#checkpointdate[@]}
  checkpointdate[$((checkpoints + 1))]=$(date +%s)
  checkpointname[$((checkpoints + 1))]="Ingest data into Solr"
  echo "=== $checkpoints. ${checkpointname[$((checkpoints + 1))]} ==="
  echo ""
  echo "starting time: $(date --date=@${checkpointdate[$((checkpoints + 1))]})"
  echo ""
  # read header from tsv
  readarray multivalue_fields < <(head -n 1 "${data_dir}/03_combined/all_${date}.tsv" | sed 's/\t/\n/g')
  for i in ${multivalue_fields[@]}; do
      multivalue_config+=(\&f.$i.separator=$separator)
  done
  multivalue_config=$(printf %s "${multivalue_config[@]}")
  echo "delete existing data..."
  curl -sS "${solr_url}/update?commit=true" -H "Content-Type: application/json" --data-binary '{ "delete": { "query": "*:*" } }' | jq .responseHeader
  echo ""
  echo "load new data..."
  curl --progress-bar "${solr_url}/update/csv?commit=true&optimize=true&separator=%09&literal.source=fid-rom&split=true${multivalue_config}" --data-binary @- -H 'Content-type:text/plain; charset=utf-8' < ${data_dir}/03_combined/all_${date}.tsv | jq .responseHeader
  echo ""
fi

# Ingest data into OpenRefine
if [ -n "$openrefine_url" ]; then
  checkpoints=${#checkpointdate[@]}
  checkpointdate[$((checkpoints + 1))]=$(date +%s)
  checkpointname[$((checkpoints + 1))]="Ingest data into OpenRefine"
  echo "=== $checkpoints. ${checkpointname[$((checkpoints + 1))]} ==="
  echo ""
  echo "starting time: $(date --date=@${checkpointdate[$((checkpoints + 1))]})"
  echo ""
  echo "delete existing project fid-rom_live..."
  ${openrefine_client} -H ${external_host} -P ${external_port} --delete "fid-rom_live"
  echo ""
  echo "create new project fid-rom_live..."
  ${openrefine_client} -H ${external_host} -P ${external_port} --create "${data_dir}/03_combined/all_${date}.tsv" --encoding=UTF-8 --projectName=fid-rom_live
  echo ""
fi

# calculate and print checkpoints
echo "=== Statistics ==="
echo ""
checkpoints=${#checkpointdate[@]}
checkpointdate[$((checkpoints + 1))]=$(date +%s)
checkpointname[$((checkpoints + 1))]="End process"
echo "starting time and run time of each step:"
checkpoints=${#checkpointdate[@]}
checkpointdate[$((checkpoints + 1))]=$(date +%s)
for i in $(seq 1 $checkpoints); do
    diffsec="$((${checkpointdate[$((i + 1))]} - ${checkpointdate[$i]}))"
    printf "%35s $(date --date=@${checkpointdate[$i]}) ($(date -d@${diffsec} -u +%H:%M:%S))\n" "${checkpointname[$i]}"
done
echo ""
diffsec="$((checkpointdate[$checkpoints] - checkpointdate[1]))"
echo "total run time: $(date -d@${diffsec} -u +%H:%M:%S) (hh:mm:ss)"
