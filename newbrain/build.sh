#!/bin/bash
PROJECT=$1
FOLDER=newbrain/calypso
echo "Compiling project $1 in $FOLDER"
cd $FOLDER
$QUARTUS_EXE --flow compile $PROJECT
cd -
