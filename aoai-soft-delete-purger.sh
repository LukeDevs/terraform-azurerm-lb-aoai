#!/bin/bash  
  
# Log in to Azure if not already logged in  
az account show &> /dev/null || az login  
  
# Get the list of soft-deleted Cognitive Services accounts  
soft_deleted_accounts=$(az cognitiveservices account list-deleted --query "[].{name:name, id:id, location:location}" -o tsv)  
  
# Check if there are any soft-deleted accounts  
if [ -z "$soft_deleted_accounts" ]; then  
  echo "No soft-deleted Cognitive Services accounts found."  
else  
  echo "Purging soft-deleted Cognitive Services accounts:"  
  echo "$soft_deleted_accounts" | while read -r name id location; do  
    # Get the resource group from the account ID  
    resourceGroup=$(echo "$id" | awk -F/ '{print $9}')  
  
    echo "Purging account: $name, resource group: $resourceGroup, location: $location"  
    az cognitiveservices account purge --name "$name" --resource-group "$resourceGroup" --location "$location"  
  done  
  echo "Purge completed."  
fi  