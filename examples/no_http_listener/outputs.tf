output "name_servers" {
  value       = module.load_balanced_open_ai.name_servers
  description = "The name servers for the DNS zone when a domain_name and SSL components are provided."
}
