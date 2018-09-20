#!/bin/bash

# SCP copy
echo "Copying"
sudo chmod +rw ./sampleCol.json
scp ./sampleCol.json azusr@40.87.84.202:sampleCol.json 

# SSH command move
echo "Moving"
ssh azusr@40.87.84.202 "sudo mv sampleCol.json /var/lib/waagent/custom-script/download/0/sampleCol.json; sudo chmod +rw /var/lib/waagent/custom-script/download/0/sampleCol.json"

# SSH exec newman
ssh azusr@40.87.84.202 "sudo sh /var/lib/waagent/custom-script/download/0/newman.sh"
