#!/bin/bash

set -eu
date >../$1
"./$BENCHMARK_EXE" --arraysize $((2 ** 29)) &>>../$1

