#!/bin/bash

source .env

echo "Deleting AZ storage account (name: $AZ_STORAGE_ACCOUNT_NAME, group: $AZ_RESOURCE_GROUP)"
az storage account delete \
  --name $AZ_STORAGE_ACCOUNT_NAME \
  --resource-group $AZ_RESOURCE_GROUP \
  --yes

echo "Deleting VM (name: $AZ_VM_NAME, group: $AZ_RESOURCE_GROUP)"
az vm delete \
  --name $AZ_VM_NAME \
  --resource-group $AZ_RESOURCE_GROUP \
  --yes

echo "💥🖥👋"
