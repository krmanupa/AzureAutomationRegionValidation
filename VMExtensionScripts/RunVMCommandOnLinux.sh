#!/bin/bash

wget $fileuri
python $filename -e $endpoint -k $key -g $groupname -w $workspaceid -l $workspacekey -r $region