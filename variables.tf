# Required variables  
variable "required_application_gateway_settings" {
  type = object({
    region                        = string
    virtual_network_address_space = list(string)
  })
  description = "The required settings region and virtual_network_address_space used in the creation of the Azure Application Gateway."
}

variable "models_to_deploy" {
  type        = list(string)
  description = "The list of OpenAI models to deploy."
}

# Optional variables  
variable "deployment_name" {
  type        = string
  description = "The user chosen name of the deployment."
  default     = "lb"
}

variable "https_settings" {
  type = object({
    domain_name              = string
    ssl_certificate_path     = string
    ssl_certificate_password = string
  })
  default = {
    domain_name              = ""
    ssl_certificate_path     = ""
    ssl_certificate_password = ""
  }
  description = "The optional settings domain_name, ssl_certificate_path, and ssl_certificate_password used in the creation of a HTTPS listener in Azure Application Gateway."
}

variable "optional_application_gateway_settings" {
  type = object({
    deploy_http_listener = bool
    scale_capacity       = number
  })
  default = {
    deploy_http_listener = true
    scale_capacity       = 2
  }
  description = "The optional settings deploy_http_listener and scale_capacity used in the creation of the Azure Application Gateway."
}
