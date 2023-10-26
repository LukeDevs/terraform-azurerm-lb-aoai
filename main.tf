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

resource "random_string" "unique_deployment_name" {
  length  = 6
  special = false
  upper   = false
  numeric = false
}

locals {

  # Constant values
  gateway_ip_configuration_name   = "aoai-gateway-ip-configuration"
  frontend_http_port_name         = "aoai-frontend-port"
  frontend_https_port_name        = "aoai-frontend-https-port"
  ssl_certificate_name            = "aoai-ssl-cert"
  frontend_ip_configuration_name  = "aoai-frontend-ip-configuration"
  backend_https_settings_name     = "aoai-backend-https-settings"
  http_listener_name              = "aoai-http-listener"
  https_listener_name             = "aoai-https-listener"
  http_request_routing_rule_name  = "aoai-http-request-routing-rule"
  https_request_routing_rule_name = "aoai-https-request-routing-rule"
  health_probe_name               = "aoai-health-probe"
  url_path_map_name               = "aoai-model-url-path-map"
  default_backend_address_pool    = "default-backend-address-pool"

  # Calculated values
  prefix                                = random_string.unique_deployment_name.result
  load_balancer_subnet_address_prefixes = cidrsubnets(local.virtual_network_address_space[0], 8)
  deploy_https_listener                 = var.https_settings.ssl_certificate_password != "" && var.https_settings.domain_name != "" && var.https_settings.ssl_certificate_path != "" ? [1] : []
  deploy_http_listener                  = var.optional_application_gateway_settings.deploy_http_listener ? [1] : []
  deploy_domain_name                    = var.https_settings.domain_name != "" ? 1 : 0
  deploy_http_listener_models           = local.deploy_http_listener == [1] ? keys(module.openai_instances.openai_model_fqdn_map) : []
  deploy_https_listener_models          = local.deploy_https_listener == [1] ? keys(module.openai_instances.openai_model_fqdn_map) : []

  # Composed values
  naming_root = "${local.prefix}-${local.deployment_name}"

  # Variable mappings  
  models_to_deploy              = var.models_to_deploy
  model_regions_to_deploy       = var.model_regions_to_deploy
  region                        = var.required_application_gateway_settings.region
  virtual_network_address_space = var.required_application_gateway_settings.virtual_network_address_space
  deployment_name               = var.deployment_name
  scale_capacity                = var.optional_application_gateway_settings.scale_capacity
  domain_name                   = var.https_settings.domain_name
  ssl_certificate_path          = var.https_settings.ssl_certificate_path
  ssl_certificate_password      = var.https_settings.ssl_certificate_password

  # Resource mappings
  load_balancer_resource_group_name = azurerm_resource_group.load_balancer_resource_group.name
}

resource "azurerm_resource_group" "load_balancer_resource_group" {
  name     = "${local.naming_root}-rg"
  location = local.region
}

resource "azurerm_resource_group" "aoai_services_resource_group" {
  name     = "${local.naming_root}-aoai-rg"
  location = local.region
}

resource "azurerm_virtual_network" "load_balancer_virtual_network" {
  name                = "${local.naming_root}-vnet"
  resource_group_name = local.load_balancer_resource_group_name
  location            = local.region
  address_space       = local.virtual_network_address_space
}

resource "azurerm_subnet" "load_balancer_front_end_subnet" {
  name                 = "${local.naming_root}-front-end-snet"
  resource_group_name  = local.load_balancer_resource_group_name
  virtual_network_name = azurerm_virtual_network.load_balancer_virtual_network.name
  address_prefixes     = [local.load_balancer_subnet_address_prefixes[0]]
}

resource "azurerm_network_security_group" "load_balancer_front_end_subnet_network_security_group" {
  name                = "${local.naming_root}-front-end-nsg"
  resource_group_name = local.load_balancer_resource_group_name
  location            = local.region
}

resource "azurerm_network_security_rule" "load_balancer_front_end_AllowGatewayManager_security_rule" {
  name                        = "AllowGatewayManager"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "65200-65535"
  source_address_prefix       = "GatewayManager"
  destination_address_prefix  = "*"
  resource_group_name         = local.load_balancer_resource_group_name
  network_security_group_name = azurerm_network_security_group.load_balancer_front_end_subnet_network_security_group.name
}

resource "azurerm_network_security_rule" "load_balancer_front_end_AllowHTTPInbound_security_rule" {
  name                        = "AllowHTTPInbound"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = local.load_balancer_resource_group_name
  network_security_group_name = azurerm_network_security_group.load_balancer_front_end_subnet_network_security_group.name
}

resource "azurerm_network_security_rule" "load_balancer_front_end_AllowHTTPSInbound_security_rule" {
  name                        = "AllowHTTPSInbound"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = local.load_balancer_resource_group_name
  network_security_group_name = azurerm_network_security_group.load_balancer_front_end_subnet_network_security_group.name
}

resource "azurerm_subnet_network_security_group_association" "load_balancer_front_end_network_security_group_association" {
  subnet_id                 = azurerm_subnet.load_balancer_front_end_subnet.id
  network_security_group_id = azurerm_network_security_group.load_balancer_front_end_subnet_network_security_group.id
}

resource "azurerm_public_ip" "load_balancer_front_end_public_ip" {
  name                = "${local.naming_root}-front-end-pip"
  resource_group_name = local.load_balancer_resource_group_name
  location            = local.region
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_dns_zone" "aoai_application_gateway_dns_zone" {
  count               = local.deploy_domain_name
  name                = local.domain_name
  resource_group_name = local.load_balancer_resource_group_name
}

resource "azurerm_dns_a_record" "aoai_application_gateway_dns_record" {
  count               = local.deploy_domain_name
  name                = "@"
  zone_name           = azurerm_dns_zone.aoai_application_gateway_dns_zone[0].name
  resource_group_name = local.load_balancer_resource_group_name
  ttl                 = 300
  records             = [azurerm_public_ip.load_balancer_front_end_public_ip.ip_address]
}

resource "azurerm_web_application_firewall_policy" "load_balancer_waf_policy" {
  name                = "${local.naming_root}-waf-policy"
  resource_group_name = local.load_balancer_resource_group_name
  location            = local.region
  managed_rules {
    managed_rule_set {
      version = "3.2"
    }
  }

  # Ignoring changes to the policy settings as accepting default values, which in turn causes Terraform to think the resource has changed
  lifecycle {
    ignore_changes = [
      policy_settings
    ]
  }
}

resource "azurerm_application_gateway" "aoai_application_gateway_load_balancer" {
  name                = "${local.naming_root}-agw"
  resource_group_name = local.load_balancer_resource_group_name
  location            = local.region
  firewall_policy_id  = azurerm_web_application_firewall_policy.load_balancer_waf_policy.id

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = local.scale_capacity
  }

  gateway_ip_configuration {
    name      = local.gateway_ip_configuration_name
    subnet_id = azurerm_subnet.load_balancer_front_end_subnet.id
  }

  dynamic "frontend_port" {
    for_each = local.deploy_http_listener
    content {
      name = local.frontend_http_port_name
      port = 80
    }
  }

  dynamic "frontend_port" {
    for_each = local.deploy_https_listener
    content {
      name = local.frontend_https_port_name
      port = 443
    }
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.load_balancer_front_end_public_ip.id
  }

  dynamic "backend_address_pool" {
    for_each = module.openai_instances.openai_model_fqdn_map
    iterator = model
    content {
      name  = "aoai-${model.key}-backend-address-pool"
      fqdns = model.value
    }
  }

  backend_http_settings {
    name                                = local.backend_https_settings_name
    cookie_based_affinity               = "Disabled"
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 300
    pick_host_name_from_backend_address = true
    probe_name                          = local.health_probe_name
  }

  dynamic "ssl_certificate" {
    for_each = local.deploy_https_listener
    content {
      name     = local.ssl_certificate_name
      data     = filebase64(local.ssl_certificate_path)
      password = local.ssl_certificate_password
    }
  }

  dynamic "http_listener" {
    for_each = local.deploy_http_listener
    content {
      name                           = local.http_listener_name
      frontend_ip_configuration_name = local.frontend_ip_configuration_name
      frontend_port_name             = local.frontend_http_port_name
      protocol                       = "Http"
    }
  }

  dynamic "http_listener" {
    for_each = local.deploy_https_listener
    content {
      name                           = local.https_listener_name
      frontend_ip_configuration_name = local.frontend_ip_configuration_name
      frontend_port_name             = local.frontend_https_port_name
      protocol                       = "Https"
      ssl_certificate_name           = local.ssl_certificate_name
    }
  }

  url_path_map {
    name                               = local.url_path_map_name
    default_backend_address_pool_name  = "aoai-gpt-35-turbo-16k-backend-address-pool"
    default_backend_http_settings_name = local.backend_https_settings_name

    dynamic "path_rule" {
      for_each = module.openai_instances.openai_model_fqdn_map
      iterator = model
      content {
        name                       = "${model.key}-path-rule"
        paths                      = ["/openai/deployments/${model.key}/*"]
        backend_address_pool_name  = "aoai-${model.key}-backend-address-pool"
        backend_http_settings_name = local.backend_https_settings_name
      }
    }
  }
  dynamic "request_routing_rule" {
    for_each = local.deploy_https_listener
    content {
      name                       = "aoai-https-request-routing-rule"
      rule_type                  = "PathBasedRouting"
      http_listener_name         = local.https_listener_name
      backend_address_pool_name  = "aoai-gpt-35-turbo-16k-backend-address-pool"
      backend_http_settings_name = local.backend_https_settings_name
      url_path_map_name          = local.url_path_map_name
      priority                   = 100
    }
  }

  dynamic "request_routing_rule" {
    for_each = local.deploy_http_listener
    content {
      name                       = "aoai-http-request-routing-rule"
      rule_type                  = "PathBasedRouting"
      http_listener_name         = local.http_listener_name
      backend_address_pool_name  = "aoai-gpt-35-turbo-16k-backend-address-pool"
      backend_http_settings_name = local.backend_https_settings_name
      url_path_map_name          = local.url_path_map_name
      priority                   = 200
    }
  }

  probe {
    name                                      = local.health_probe_name
    protocol                                  = "Https"
    pick_host_name_from_backend_http_settings = true
    path                                      = "/status-0123456789abcdef"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
  }

  depends_on = [module.openai_instances]
}


module "openai_instances" {
  source                  = "./modules/openai"
  allowed_ip_addresses    = [azurerm_public_ip.load_balancer_front_end_public_ip.ip_address]
  deployment_name         = local.naming_root
  models_to_deploy        = local.models_to_deploy
  model_regions_to_deploy = local.model_regions_to_deploy
  resource_group_name     = azurerm_resource_group.aoai_services_resource_group.name
}
