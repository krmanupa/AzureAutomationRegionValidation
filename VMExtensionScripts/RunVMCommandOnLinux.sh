#!/bin/bash

helpFunction()
{
   echo ""
   echo "Usage: $0 -u fileuri -n fileName -e endpoint -k key -g groupname -w workspaceid  -l workspacekey"
   echo -e "\t-a Description of what is parameterA"
   echo -e "\t-b Description of what is parameterB"
   echo -e "\t-c Description of what is parameterC"
   exit 1 # Exit script after printing help
}

while getopts "a:b:c:" opt
do
   case "$opt" in
      u ) fileuri="$OPTARG";;
      n ) filename="$OPTARG";;
      e ) endpoint="$OPTARG" ;;
      k ) key="$OPTARG" ;;
      g ) groupname="$OPTARG" ;;
      w ) workspaceid="$OPTARG" ;;      
      l ) workspacekey="$OPTARG" ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

wget $fileuri > $filename
python $filename -e $endpoint -k $key -g $groupname -w $workspaceid -l $workspacekey