#!/bin/bash
PROJECT=$1
FOLDER=fp1100/calypso
echo "Compiling project $1 in $FOLDER"
cd $FOLDER
$QUARTUS_EXE --flow compile $PROJECT
cd -
