#!/bin/bash
PROJECT=$1
FOLDER=aleste520ex/calypso
echo "Compiling project $1 in $FOLDER"
cd $FOLDER
$QUARTUS_EXE --flow compile $PROJECT
cd -
