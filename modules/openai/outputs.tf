
output "openai_model_fqdn_list" {
  value = [
    for key, account in azurerm_cognitive_account.aoai_cognitive_account :
    substr(replace(account.endpoint, "https://", ""), 0, length(replace(account.endpoint, "https://", "")) - 1)
  ]
  description = "A list of the endpoints for each deployed cognitive service based on the selected model"
}
