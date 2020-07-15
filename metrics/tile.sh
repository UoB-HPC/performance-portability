#!/bin/bash

if [ $# -eq 0 ]
then
  echo "Usage: $0 script.py"
  exit
fi

graph=$(basename $1 .py)
applications=(
  "babelstream_peak"
  "cloverleaf"
  "minifmm"
  "neutral"
  "tealeaf"
)

for code in ${applications[@]}; do
  $1 data/"$code".csv $f "$graph"_"$code".pdf
done

pdfnup --nup 3x2 "$graph"*.pdf
mv "$graph"*-nup.pdf "$graph"_tiled.pdf


