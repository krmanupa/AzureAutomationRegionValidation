#!/bin/bash

if [ "$#" -eq 0 ]
then
	# Checking which python version is available 
	# python3
	if [[ -z $(python2 --version 2>&1 | grep 'not found') ]]
	then
		#echo "python exists"; 
		pythonVer="python2"
	elif [[ -z $(python3 --version 2>&1 | grep 'not found') ]]
	then
		#echo "python3 exists"; 
		pythonVer="python3"
	else 
		echo "'python2' or 'python3' not found on this machine. Please install python."
		exit 1
	fi
else
	echo "parameters were passed."
fi

