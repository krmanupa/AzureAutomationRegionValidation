#!/bin/bash

python2=$(python2 --version 2>&1 | grep 'not found')
python3=$(python3 --version 2>&1 | grep 'not found')

if [ -z "${python2}" ]
then
    #echo "python exists";
    echo "python2"
    exit 0
elif [ -z "${python3}" ]
then
    #echo "python3 exists";
    echo "python3"
    exit 0
else
    echo "'python2' or 'python3' not found on this machine. Please install python."
    exit 1
fi
