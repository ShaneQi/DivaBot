#!/bin/bash
docker run \
-d \
--name divabot \
-v `pwd`:/divabot \
-w /divabot \
swift:5.3 \
/bin/bash -c \
"swift run"
