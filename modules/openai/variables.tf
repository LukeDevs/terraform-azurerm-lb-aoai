# Required variables
variable "allowed_ip_addresses" {
  type        = list(string)
  description = "A list of IP addresses that will be allowed to access the deployed Cognitive Services accounts."
}

variable "models_to_deploy" {
  type        = list(string)
  description = "A list of openai models to deploy into their supported regions."
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group to deploy the OpenAI Cognitive Services accounts into."
}

# Optional variables
variable "deployment_name" {
  type        = string
  description = "The user chosen name of the deployment."
  default     = "aoai"
}
