#!/bin/sh
d=1                # index of the directory
f=0                # number of files already copied into direc$d
for x in *; do     # iterate over the files in the current directory
  #Create the target directory if this is the first file to be copied there
  if [ $f -eq 0 ]; then mkdir "direc$d"; fi
  #Move the file
  mv -- "$x" "direc$d"
  f=$((f+1))
  #If we've moved 5 files, go on to the next directory
  if [ $f -eq 5 ]; then
    f=0 d=$((d+1))
  fi
done
