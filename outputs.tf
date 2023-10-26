output "name_servers" {
  value       = var.https_settings.domain_name != "" && var.https_settings.ssl_certificate_password != "" && var.https_settings.ssl_certificate_path != "" ? azurerm_dns_zone.aoai_application_gateway_dns_zone[0].name_servers : []
  description = "The name servers for the DNS zone when a domain_name and SSL components are provided."
}

output "openai_model_fqdn_map" {
  value       = module.openai_instances.openai_model_fqdn_map
  description = "A map of the endpoints for each deployed cognitive service based on the selected model"
}
