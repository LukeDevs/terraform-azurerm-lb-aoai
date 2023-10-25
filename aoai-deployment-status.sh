#!/bin/bash  
  
# Set your subscription ID  
subscription_id="<INSERT_SUBSCRIPTION_HERE>"  
  
# Get the list of resource groups in the subscription  
resource_groups=$(az group list --query "[].name" -o tsv)  
  
# Print the table header  
printf "%-40s %-40s %-20s\n" "Resource Group" "Cognitive Service Name" "Deployment Status"  
  
# Loop through each resource group  
for rg in $resource_groups; do  
  # Get the list of cognitive services in the resource group  
  cognitive_services=$(az resource list --resource-group $rg --resource-type "Microsoft.CognitiveServices/accounts" --query "[?contains(kind, 'OpenAI')].name" -o tsv)  
  
  # Loop through each cognitive service  
  for cs in $cognitive_services; do  
    # Get the deployment status of the cognitive service  
    deployment_status=$(az resource show --ids "/subscriptions/$subscription_id/resourceGroups/$rg/providers/Microsoft.CognitiveServices/accounts/$cs" --query "properties.provisioningState" -o tsv)  
  
    # Print the table row  
    printf "%-40s %-40s %-20s\n" "$rg" "$cs" "$deployment_status"  
  done  
done  
