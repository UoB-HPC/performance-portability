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
  "neutral"
  #"minifmm"
  #"tealeaf"
)

for code in ${applications[@]}; do
  if [[ "$code" == "babelstream_peak" ]]; then
    $1 --input-is-throughput data/"$code".csv $f "$graph"_"$code".pdf
  else
    $1 --calc-efficiency data/"$code".csv $f "$graph"_"$code".pdf
  fi
done

pdfnup --nup 3x1 "$graph"*.pdf
pdfcrop "$graph"*-nup.pdf "$graph"_tiled.pdf
#mv "$graph"*-nup.pdf "$graph"_tiled.pdf


