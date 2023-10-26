output "openai_model_fqdn_list" {
  value = [
    for key, account in azurerm_cognitive_account.aoai_cognitive_account :
    substr(replace(account.endpoint, "https://", ""), 0, length(replace(account.endpoint, "https://", "")) - 1)
  ]
  description = "A list of the endpoints for each deployed cognitive service based on the selected model"
}

output "openai_model_fqdn_map" {
  value = {
    for model_region in local.model_region_pairs :
    model_region.model => substr(replace(azurerm_cognitive_account.aoai_cognitive_account[model_region.region].endpoint, "https://", ""), 0, length(replace(azurerm_cognitive_account.aoai_cognitive_account[model_region.region].endpoint, "https://", "")) - 1)...
  }
  description = "A map of the endpoints for each deployed cognitive service based on the selected model"
}
