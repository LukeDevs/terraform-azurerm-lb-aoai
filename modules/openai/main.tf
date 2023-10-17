terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.73.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.1"
    }
  }

  required_version = ">= 1.2.6"
}

provider "azurerm" {
  features {
    cognitive_account {
      purge_soft_delete_on_destroy = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

locals {

  region_abbreviation_map = {
    "North Central US"  = "ncus"
    "Australia East"    = "aue"
    "East US 2"         = "eus2"
    "Canada East"       = "cae"
    "Japan East"        = "jpe"
    "UK South"          = "uks"
    "Sweden Central"    = "swc"
    "Switzerland North" = "swn"
    "East US"           = "eus"
    "South Central US"  = "scus"
    "West Europe"       = "weu"
    "France Central"    = "fc"
  }

  gpt_4_model_name             = "gpt-4-32k"
  gpt_4_32k_primary_regions    = ["North Central US", "Australia East", "East US 2", "Canada East", "Japan East", "UK South", "Sweden Central", "Switzerland North"]
  gpt_4_32k_primary_tpm        = 80
  gpt_4_32k_primary_tpm_list   = [for _ in local.gpt_4_32k_primary_regions : local.gpt_4_32k_primary_tpm]
  gpt_4_32k_secondary_regions  = ["East US", "France Central"]
  gpt_4_32k_secondary_tpm      = 40
  gpt_4_32k_model_version      = "0613"
  gpt_4_32k_secondary_tpm_list = [for _ in local.gpt_4_32k_secondary_regions : local.gpt_4_32k_secondary_tpm]
  gpt_4_32k_all_regions        = concat(local.gpt_4_32k_primary_regions, local.gpt_4_32k_secondary_regions)
  gpt_4_32k_all_regions_mapped_tpm = merge(
    zipmap(local.gpt_4_32k_primary_regions, local.gpt_4_32k_primary_tpm_list),
    zipmap(local.gpt_4_32k_secondary_regions, local.gpt_4_32k_secondary_tpm_list)
  )

  gpt_35_model_name                   = "gpt-35-turbo-16k"
  gpt_35_turbo_16k_primary_regions    = ["North Central US", "Australia East", "East US 2", "Canada East", "Sweden Central", "Switzerland North"]
  gpt_35_turbo_16k_primary_tpm        = 300
  gpt_35_turbo_16k_primary_tpm_list   = [for _ in local.gpt_35_turbo_16k_primary_regions : local.gpt_35_turbo_16k_primary_tpm]
  gpt_35_turbo_16k_secondary_regions  = ["East US", "UK South"]
  gpt_35_turbo_16k_secondary_tpm      = 240
  gpt_35_turbo_16k_model_version      = "0613"
  gpt_35_turbo_16k_secondary_tpm_list = [for _ in local.gpt_35_turbo_16k_secondary_regions : local.gpt_35_turbo_16k_secondary_tpm]
  gpt_35_turbo_16k_all_regions        = concat(local.gpt_35_turbo_16k_primary_regions, local.gpt_35_turbo_16k_secondary_regions)
  gpt_35_turbo_16k_all_regions_mapped_tpm = merge(
    zipmap(local.gpt_35_turbo_16k_primary_regions, local.gpt_35_turbo_16k_primary_tpm_list),
    zipmap(local.gpt_35_turbo_16k_secondary_regions, local.gpt_35_turbo_16k_secondary_tpm_list)
  )

  text_embedding_model_name                 = "text-embedding-ada-002"
  text_embedding_ada_002_primary_regions    = ["North Central US", "East US 2", "Canada East", "UK South", "Sweden Central", "Switzerland North"]
  text_embedding_ada_002_primary_tpm        = 350
  text_embedding_ada_002_primary_tpm_list   = [for _ in local.text_embedding_ada_002_primary_regions : local.text_embedding_ada_002_primary_tpm]
  text_embedding_ada_002_secondary_regions  = ["East US"]
  text_embedding_ada_002_secondary_tpm      = 240
  text_embedding_ada_002_secondary_tpm_list = [for _ in local.text_embedding_ada_002_secondary_regions : local.text_embedding_ada_002_secondary_tpm]
  text_embedding_ada_002_model_version      = "2"
  text_embedding_ada_002_all_regions        = concat(local.text_embedding_ada_002_primary_regions, local.text_embedding_ada_002_secondary_regions)
  text_embedding_ada_002_all_regions_mapped_tpm = merge(
    zipmap(local.text_embedding_ada_002_primary_regions, local.text_embedding_ada_002_primary_tpm_list),
    zipmap(local.text_embedding_ada_002_secondary_regions, local.text_embedding_ada_002_secondary_tpm_list)
  )

  model_region_pairs = flatten([
    contains(var.models_to_deploy, local.gpt_4_model_name) ? [for region in local.gpt_4_32k_all_regions : { model = local.gpt_4_model_name, region = region }] : [],
    contains(var.models_to_deploy, local.gpt_35_model_name) ? [for region in local.gpt_35_turbo_16k_all_regions : { model = local.gpt_35_model_name, region = region }] : [],
    contains(var.models_to_deploy, local.text_embedding_model_name) ? [for region in local.text_embedding_ada_002_all_regions : { model = local.text_embedding_model_name, region = region }] : []
  ])

  models_to_deploy     = var.models_to_deploy
  resource_group_name  = var.resource_group_name
  naming_root          = var.deployment_name
  allowed_ip_addresses = var.allowed_ip_addresses
}

resource "azurerm_cognitive_account" "aoai_cognitive_account" {
  for_each = { for region in distinct([for model_region in local.model_region_pairs : model_region.region]) : region => region }

  name                  = "${local.naming_root}-${local.region_abbreviation_map[each.value]}"
  location              = each.value
  resource_group_name   = local.resource_group_name
  kind                  = "OpenAI"
  sku_name              = "S0"
  custom_subdomain_name = "${local.naming_root}-${local.region_abbreviation_map[each.value]}"
  local_auth_enabled    = "true"

  network_acls {
    default_action = "Deny"
    ip_rules       = local.allowed_ip_addresses
  }

  timeouts {
    create = "60m"
    update = "60m"
  }
}

resource "azurerm_cognitive_deployment" "aoai_cognitive_deployment" {
  for_each = { for model_region in local.model_region_pairs : "${model_region.model}-${model_region.region}" => model_region }

  cognitive_account_id = azurerm_cognitive_account.aoai_cognitive_account[each.value.region].id
  name                 = each.value.model

  model {
    format = "OpenAI"
    name   = each.value.model
    version = (
      each.value.model == local.gpt_4_model_name ? local.gpt_4_32k_model_version :
      each.value.model == local.gpt_35_model_name ? local.gpt_35_turbo_16k_model_version :
      each.value.model == local.text_embedding_model_name ? local.text_embedding_ada_002_model_version : ""
    )
  }
  scale {
    type = "Standard"
    capacity = (
      each.value.model == local.gpt_4_model_name ? local.gpt_4_32k_all_regions_mapped_tpm[each.value.region] :
      each.value.model == local.gpt_35_model_name ? local.gpt_35_turbo_16k_all_regions_mapped_tpm[each.value.region] :
      each.value.model == local.text_embedding_model_name ? local.text_embedding_ada_002_all_regions_mapped_tpm[each.value.region] : 0
    )
  }
}
