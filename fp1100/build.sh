#!/bin/bash
PROJECT=$1
echo "Compiling project $1"
cd fp1100/calypso
$QUARTUS_EXE --flow compile $PROJECT
