output "name_servers" {
  value       = var.https_settings.domain_name != "" && var.https_settings.ssl_certificate_password != "" && var.https_settings.ssl_certificate_path != "" ? azurerm_dns_zone.aoai_application_gateway_dns_zone[0].name_servers : []
  description = "The name servers for the DNS zone when a domain_name and SSL components are provided."
}
