# FID-Romanistik-MetadataTransformations

[![Codacy Badge](https://api.codacy.com/project/badge/Grade/60508e771f154d788083004d4b3157e6)](https://www.codacy.com/app/felixlohmeier/FID-Romanistik-metadataTransformations?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=subhh/FID-Romanistik-metadataTransformations&amp;utm_campaign=Badge_Grade)

Automated workflow for harvesting, transforming and indexing of metadata using [metha](https://github.com/miku/metha), [OpenRefine](http://openrefine.org/) and [Solr](http://lucene.apache.org/solr/). Part of the [FID Romanistik](https://www.fid-romanistik.de) software stack.

See upstream git repo [HOS-MetadataTransformations](https://github.com/subhh/HOS-MetadataTransformations) for use case, features and reuse.

## Installation

tested with [Ubuntu 16.04 LTS](http://releases.ubuntu.com/16.04/) and [Ubuntu 18.04 LTS](http://releases.ubuntu.com/18.04/)

install git:

```
sudo apt install git
```

clone this git repository:

```
git clone https://github.com/subhh/FID-Romanistik-MetadataTransformations.git
cd FID-Romanistik-MetadataTransformations
```

install [openjdk-8-jre-headless](https://packages.ubuntu.com/search?keywords=openjdk-8-jre-headless), [curl](https://curl.haxx.se/), [jq](https://stedolan.github.io/jq/), [metha 1.29](https://github.com/miku/metha), [OpenRefine 2.8](http://openrefine.org/), [openrefine-client 0.3.4](https://github.com/opencultureconsulting/openrefine-client) and [Solr 7.3.1](http://lucene.apache.org/solr/):

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

Run workflow with data source "dialnet-tesis" and load data into local Solr (-s) and local OpenRefine service (-d)

```
bin/dialnet-tesis.sh -s http://localhost:8983/solr/fid -d http://localhost:3333
```

Run workflow with all data sources in parallel and load data into local Solr (-s) and local OpenRefine service (-d):

```
./run.sh -s http://localhost:8983/solr/fid -d http://localhost:3333
```

Run workflow with all data sources and load data into external Solr core

```
./run.sh -s "http://..."
```

