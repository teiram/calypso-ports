#!/bin/bash

env
set -x

cd ../jtcores
source setprj.sh
jtcore cop -t calypso

