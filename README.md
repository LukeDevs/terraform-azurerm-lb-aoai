# Loadbalanced Azure OpenAI Service
A Terraform module to deploy and configure the neccessary services for providing layer 7 load balancing of the Azure OpenAI Service. 
## Overview
This module deploys a single Azure Application Gateway to front of multiple different region based Azure OpenAI Services.

Load balancing the Azure OpenAI Service allows for a higher combined Tokens Per Minute (TPM) and Requests Per Minute (RPM) throughput over levraging leveraging a single Azure OpenAI Service in isolation. 
## Authenticating against Loadbalanced Azure OpenAI Service
Being load balanced it is not possible to use the Azure OpenAI Service API key to authenticate. Instead end users must be granted an appropriate Azure OpenAI RBAC role. Details of which can be found here: https://learn.microsoft.com/en-us/azure/ai-services/openai/how-to/role-based-access-control.

## Module Usage
```hcl
module "load_balanced_open_ai" {
  source           = "../.."
  models_to_deploy = ["gpt-35-turbo-16k", "text-embedding-ada-002"]
  required_application_gateway_settings = {
    region                        = "ukwest",
    virtual_network_address_space = ["10.41.0.0/16"]
  }
  deployment_name = "max-test"
  optional_application_gateway_settings = {
    deploy_http_listener = true,
    scale_capacity       = 2
  }
  https_settings = {
    domain_name              = "<REPLACE_WITH_DOMAIN_NAME>"
    ssl_certificate_path     = "<REPLACE_WITH_PATH_TO_PFX_CERT>"
    ssl_certificate_password = "<REPLACE_WITH_CERT_PASSWORD>"
  }
}
```
## Notes
* Currently the deployed Azure OpenAI services are publicly addressable. Direct access to the Azure OpenAI services is restricted through the use of a Network Firewall Rule applied to each service. This rule is configured to only permit traffic coming from the Azure Application Gateway. 

## Known Issues  
  
* CONTEXT: The Azure OpenAI Services identify as Azure Cognitive Services behind the scenes. Each Azure OpenAI Service is by default provisioned with maxmimum Tokens Per Minute quota assigned to it for the region its been deployed into. This module will fail to deploy if the Azure OpenAI Service is already at its maximum quota for that region.    
      
  ISSUE: Deleting Azure OpenAI Services via the portal will delete the resource from the Azure portal but does not release the Tokens Per Minute quota for the region. The platform registers these Azure OpenAI Services as 'Soft Deleted', these soft deleted instances will need to be purged to allow the module to deploy correctly into each region.    
      
  RESOLUTION: Use the aoai-soft-delete-purger.sh script to purge these soft deleted instances and free up the region based quota.  
