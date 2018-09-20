#!/bin/bash

# Use custom environment variables
# See .env.sample for how this should be configured
source .env

# Create Storage Account, get connection string
echo "Creating AZ storage account (name: $AZ_STORAGE_ACCOUNT_NAME, group: $AZ_RESOURCE_GROUP, location: $AZ_LOCATION, SKU: Standard_LRS)"
az storage account create -n $AZ_STORAGE_ACCOUNT_NAME -g $AZ_RESOURCE_GROUP -l $AZ_LOCATION --sku Standard_LRS
AZ_CONNECTION_STRING=$(az storage account show-connection-string -g $AZ_RESOURCE_GROUP -n $AZ_STORAGE_ACCOUNT_NAME -o tsv)
AZ_STORAGE_KEY=$(az storage account keys list -g $AZ_RESOURCE_GROUP -n $AZ_STORAGE_ACCOUNT_NAME --query "[0].value" -o tsv)
echo "Creating AZ storage container (name: $AZ_CONTAINER_NAME, account name: $AZ_STORAGE_ACCOUNT_NAME, connection string: $AZ_CONNECTION_STRING)"
az storage container create --name $AZ_CONTAINER_NAME --account-name $AZ_STORAGE_ACCOUNT_NAME --connection-string $AZ_CONNECTION_STRING
az storage share create --name $AZ_SHARE_NAME --connection-string $AZ_CONNECTION_STRING

# Upload collection files
echo "Uploading collection files"
az storage directory create --name collections --share-name $AZ_SHARE_NAME --connection-string $AZ_CONNECTION_STRING
az storage file upload-batch --destination $AZ_SHARE_NAME --source ./collections --destination-path collections --connection-string $AZ_CONNECTION_STRING

# Upload environment files
echo "Uploading environment files"
az storage directory create --name environments --share-name $AZ_SHARE_NAME --connection-string $AZ_CONNECTION_STRING
az storage file upload-batch --destination $AZ_SHARE_NAME --source ./environments --destination-path environments --connection-string $AZ_CONNECTION_STRING

# Update newman script with Azure Files share
cp ./newman.sh.template ./newman.sh
sed -i -e "s,SANAME,$AZ_STORAGE_ACCOUNT_NAME,g" ./newman.sh
sed -i -e "s,SAKEY,$AZ_STORAGE_KEY,g" ./newman.sh
sed -i -e "s,SHARENAME,$AZ_SHARE_NAME,g" ./newman.sh
echo "Uploading ./newman.sh to storage blob (container name: $AZ_CONTAINER_NAME, account name: $AZ_STORAGE_ACCOUNT_NAME, connection string: $AZ_CONNECTION_STRING)"
az storage blob upload --file ./newman.sh --container-name $AZ_CONTAINER_NAME --name newman.sh --account-name $AZ_STORAGE_ACCOUNT_NAME --connection-string $AZ_CONNECTION_STRING

# Upload reportsd to Azure Files
az storage file upload --share-name $AZ_SHARE_NAME --source ./reportsd.sh --path reportsd.sh --connection-string $AZ_CONNECTION_STRING

# Generate newman script download SAS, update protected settings for harness VM, and upload
echo "Generating SAS key (container name: $AZ_CONTAINER_NAME, expiry: $AZ_EXPIRY, connection string: $AZ_CONNECTION_STRING)"
AZ_NEWMAN_SAS=$(az storage blob generate-sas --container-name $AZ_CONTAINER_NAME --name newman.sh --permissions r --expiry $AZ_EXPIRY --connection-string $AZ_CONNECTION_STRING -o tsv)
AZ_NEWMAN_SAS=$(echo $AZ_NEWMAN_SAS | sed "s,&,\\\&,g") # stupid ampersand is a special char in sed... gotta escape it.
echo "Formatted SAS key: $AZ_NEWMAN_SAS"
NEWMANDL="https://$AZ_STORAGE_ACCOUNT_NAME.blob.core.windows.net/$AZ_CONTAINER_NAME/newman.sh?$AZ_NEWMAN_SAS"
cp ./har.protectedSettings.json.template ./har.protectedSettings.json
sed -i -e "s,URLHERE,$NEWMANDL,g" ./har.protectedSettings.json

# Create Test Harness VM
echo "Creating Test Harness VM (resource group: $AZ_RESOURCE_GROUP, name: $AZ_VM_NAME, vnet name: $AZ_VNET_NAME, subnet: $AZ_SUBNET)"
PUBLIC_IP_ADDRESS=$(az vm create \
    --resource-group $AZ_RESOURCE_GROUP \
    --name $AZ_VM_NAME \
    --image UbuntuLTS \
    --vnet-name $AZ_VNET_NAME \
    --subnet $AZ_SUBNET \
    --admin-username azusr \
    --generate-ssh-keys \
    --query "publicIpAddress" \
    --output tsv)

az vm open-port --port 80 --resource-group $AZ_RESOURCE_GROUP --name $AZ_VM_NAME

echo "Setting AZ extension for custom script (resource group: $AZ_RESOURCE_GROUP, VM name: $AZ_VM_NAME)"
az vm extension set \
    --resource-group $AZ_RESOURCE_GROUP \
    --vm-name $AZ_VM_NAME \
    --name customScript \
    --publisher Microsoft.Azure.Extensions \
    --protected-settings ./har.protectedSettings.json

# Cleanup Files
rm newman.sh
rm har.protectedSettings.json

echo "http://$PUBLIC_IP_ADDRESS/reports.html"
