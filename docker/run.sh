#!/bin/bash
docker run \
-d \
--name divabot \
-v `pwd`:/divabot \
-w /divabot \
swift:4.1 \
/bin/bash -c \
"swift run"
