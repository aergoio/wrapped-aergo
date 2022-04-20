#!/bin/bash

if [ -f output.lua ]
then
  rm output.lua
fi

process_file() {
  cat ../ARC1-Extensions/src/ARC1-$1.lua >> output.lua
}

process_file "Core"
# "Burnable" and "Mintable" SHOULD NOT be included!
process_file "Pausable"
process_file "Blacklist"
process_file "allApproval"
process_file "limitedApproval"

cat waergo.lua >> output.lua
