#!/bin/bash

rm output.lua

process_file() {
  cat ../ARC1-Extensions/src/ARC1-$1.lua >> output.lua
}

process_file "Core"
#process_file "Burnable"
#process_file "Mintable"
process_file "Pausable"
process_file "Blacklist"
process_file "allApproval"
process_file "limitedApproval"

cat waergo.lua >> output.lua
