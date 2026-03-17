# Digital Image Validation and Processing

## Overview

DIVP is a commandline tool for turning folders of raw image scans into folders of image files suitable for other destinations such as HathiTrust. This processing can involve things like:

* validating that all of the pages are there
* correcting the image metadata
* validating that source images have the appropriate resolution
* compressing the images to meet the destination specifications
* creating a checksum file of the compressed images
* verifying that a given checksum file matches the other files in the folder

The `divp process` command works with `shipments`. A `shipment` is a folder full of items, which each item is a folder full of the image files that make up the item.  

DIVP uses [grok](https://grokcompression.com/) for JPEG2000 compression.

## Developer setup

Clone the repo

```bash
git clone git@github.com:mlibrary/divp.git
cd divp
```

run the `init.sh` script.

```bash
./init.sh
```

run tests

```
docker compose run --rm app bundle exec rspec
docker compose run --rm app bundle exec rake test
```

run linting

```
docker compose run --rm app bundle exec standardrb --fix
```
