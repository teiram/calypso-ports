#!/bin/bash
PROJECT=$1
echo "Compiling project $1"
cd newbrain/calypso
$QUARTUS_EXE --flow compile $PROJECT
