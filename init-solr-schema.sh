#!/bin/bash
# https://github.com/subhh/FID-Romanistik-metadataTransformations

# help screen
function usage () {
    cat <<EOF
Usage: ./init-solr-schema.sh [-s SOLRURL]

== options ==
    -s SOLRURL       URL to Solr core (default: http://localhost:8983/solr/fid)

== example ==
./init-solr-schema.sh -s http://localhost:8983/solr/fid
EOF
   exit 1
}

# defaults
solr_url="http://localhost:8983/solr/fid"

# get user input
options="s:h"
while getopts $options opt; do
   case $opt in
   s )  solr_url=${OPTARG} ;;
   h )  usage ;;
   \? ) echo 1>&2 "Unknown option: -$OPTARG"; usage; exit 1;;
   :  ) echo 1>&2 "Missing option argument for -$OPTARG"; usage; exit 1;;
   *  ) echo 1>&2 "Unimplemented option: -$OPTARG"; usage; exit 1;;
   esac
done
shift $((OPTIND - 1))

# declare additional variables
config_dir=$(readlink -f cfg/solr)
solr_base=${solr_url%/*}
solr_core=${solr_url##*/}
if [ -n "${config_dir// }" ] ; then jsonfiles=($(find -L "${config_dir}"/*.json -type f -printf "%f\n" 2>/dev/null)) ; fi

# print variables
echo "Solr core URL:           $solr_url"
echo "Solr base URL:           $solr_base"
echo "Solr core name:          $solr_core"
echo "Solr config files:       ${jsonfiles[*]}"
echo ""

# delete existing data
echo "delete existing data..."
curl -sS "${solr_base}/${solr_core}/update?commit=true" -H "Content-Type: application/json" --data-binary '{ "delete": { "query": "*:*" } }' | jq .responseHeader

# delete fields and copy fields
echo "delete fields, reload core and delete copy fields..."
curl -sS -X POST -H 'Content-type:application/json' --data-binary "{ \"delete-copy-field\" : $(curl --silent "${solr_base}/${solr_core}/schema/copyfields" | jq '[.copyFields[] | {source: .source, dest: .dest}]') }" ${solr_base}/${solr_core}/schema  | jq .responseHeader
curl -sS "${solr_base}/admin/cores?action=RELOAD&core=${solr_core}" | jq .responseHeader
curl -sS -X POST -H 'Content-type:application/json' --data-binary "{ \"delete-field\" : $(curl --silent "${solr_base}/${solr_core}/schema/fields" | jq '[ .fields[] | {name: .name } ]') }" ${solr_base}/${solr_core}/schema | jq .responseHeader

# add fields and copy fields
echo "add fields and copy fields..."
curl -sS -X POST -H 'Content-type:application/json' --data-binary "{ \"add-field\" : $(< ${config_dir}/fields.json) }" ${solr_base}/${solr_core}/schema | jq .responseHeader
curl -sS -X POST -H 'Content-type:application/json' --data-binary "{ \"add-copy-field\" : $(< ${config_dir}/copyfields.json) }" ${solr_base}/${solr_core}/schema | jq .responseHeader
