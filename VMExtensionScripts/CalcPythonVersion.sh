#!/bin/bash

python2=$(python2 --version 2>&1 | grep 'not found')
python3=$(python3 --version 2>&1 | grep 'not found')

if [ -z "${python2}" ]
then
    #echo "python exists";
    #exit with code 0 if python is present.
    exit 0
elif [ -z "${python3}" ]
then
    #echo "python3 exists";
    #exit with code 1 if python3 is present.
    exit 1
else
    echo "'python2' or 'python3' not found on this machine. Please install python."
    exit 1
fi
