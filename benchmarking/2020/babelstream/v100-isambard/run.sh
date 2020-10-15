#!/bin/bash

set -eu
date >../$1
"./$BENCHMARK_EXE" &>>../$1

