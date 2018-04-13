# FID-Romanistik-MetadataTransformations

[![Codacy Badge](https://api.codacy.com/project/badge/Grade/60508e771f154d788083004d4b3157e6)](https://www.codacy.com/app/felixlohmeier/FID-Romanistik-metadataTransformations?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=subhh/FID-Romanistik-metadataTransformations&amp;utm_campaign=Badge_Grade)

Automated workflow for harvesting, transforming and indexing of metadata using [metha](https://github.com/miku/metha), [OpenRefine](http://openrefine.org/) and [Solr](http://lucene.apache.org/solr/). Part of the [FID Romanistik](https://www.fid-romanistik.de) software stack.

See upstream git repo [HOS-MetadataTransformations](https://github.com/subhh/HOS-MetadataTransformations) for use case, features and reuse.

## Installation

tested with [Ubuntu 16.04 LTS](https://www.ubuntu.com/download/desktop)

install git:

```
sudo apt install git
```

clone this git repository:

```
git clone https://github.com/subhh/FID-Romanistik-MetadataTransformations.git
cd FID-Romanistik-MetadataTransformations
```

install [default-jre](https://packages.ubuntu.com/de/xenial/default-jre), [curl](https://curl.haxx.se/), [metha](https://github.com/miku/metha), [OpenRefine](http://openrefine.org/), [openrefine-client](https://github.com/opencultureconsulting/openrefine-client) and [Solr](http://lucene.apache.org/solr/):

```
sudo ./install.sh
```

Configure [Solr schema](cfg/solr):

```
./init-solr-schema.sh
```

## Usage

Data will be available after first run at:

* Solr admin: <http://localhost:8983/solr/#/fid>
* Solr browse: <http://localhost:8983/solr/fid/browse>
* OpenRefine: <http://localhost:3333>

Run workflow with data source "dialnet-tesis" and load data into local Solr and local OpenRefine service

```
bin/dialnet-tesis.sh
```

Run workflow with all data sources in parallel and load data into local Solr and local OpenRefine service:

```
./run.sh
```

Run workflow with all data sources and load data into external Solr core

```
./run.sh -s "http://hosdev.sub.uni-hamburg.de:8983/solr/HOS_MASTER"

```
