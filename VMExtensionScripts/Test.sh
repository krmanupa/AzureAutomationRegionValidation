#!/bin/bash

if [! -z $(python3 -V 2>&1 | grep -Po '(?<=Python )(.+)') ]
 then
 #echo "python3 exists"; 
 echo "python3"
elif [! -z $(python2 -V 2>&1 | grep -Po '(?<=Python )(.+)') ]
 then
 #echo "python2 exists"; 
 echo "python2"
else 
  echo "'python2' or 'python3' not found on this machine. Please install python."
  exit 1
