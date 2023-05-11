locals {

  rg_name                          = "${var.prefix}-rs"
  log_reg_name                     = "${var.prefix}-log-analytics-rs"
  log_analytics_ws_name            = "${var.prefix}-log-analtyic-com"
  appinsights_name                 = "${var.prefix}-tf-appinsights"
  storage_account_name             = "${var.prefix}appservicest10523"
  ase_v3_vnet_name                 = "${var.prefix}-asev3-vnet"
  ase_v3_subnet_name               = "${var.prefix}-asev3-subnet"
  ase_v3_nsg_name                  = "${var.prefix}-asev3-nsg"
  sql_server_name                  = "${var.prefix}-sql-server-10523"
  sql_db_name                      = "${var.prefix}-order-db-10523"
  sql_vnet_rule_name               = "${var.prefix}-sql-vnet-rule"
  ase_v3_name                      = "${var.prefix}asev310523"
  dns_private_name                 = "${var.prefix}asv3dns.appserviceenvironment.net"
  privateDnsZoneName_vnetLink      = "${var.prefix}-vnetLink"
  app_service_plan_name            = "${var.prefix}-asp-10523"
  webui_app_name                   = "${var.prefix}webui10523"
  webapi_app_name                  = "${var.prefix}webapi10523"
  function_app_name                = "${var.prefix}functionapp10523"
  log_analytics_log_categories     = ["AppServiceHTTPLogs", "AppServiceConsoleLogs", "AppServiceAppLogs", "AppServiceAuditLogs", "AppServiceIPSecAuditLogs", "AppServicePlatformLogs"]
  log_analytics_SQL_log_categories = ["SQLSecurityAuditEvents", "SQLInsights", "Errors", "AutomaticTuning"]
  db_connection                    = "Server=${local.sql_server_name}.database.windows.net; Authentication=Active Directory Default; Database=${local.sql_db_name}"
}
# Generate a random integer to create a globally unique name
resource "random_integer" "ri" {
  min = 10000
  max = 99999
}

# Create the resource group
resource "azurerm_resource_group" "rg" {
  name     = local.rg_name
  location = var.resource_group_location
}

resource "azurerm_resource_group" "log_analytics" {
  name     = local.log_reg_name
  location = var.resource_group_location
}

resource "azurerm_log_analytics_workspace" "example" {
  name                = local.log_analytics_ws_name
  location            = azurerm_resource_group.log_analytics.location
  resource_group_name = azurerm_resource_group.log_analytics.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_application_insights" "example" {
  name                = local.appinsights_name
  location            = azurerm_resource_group.log_analytics.location
  resource_group_name = azurerm_resource_group.log_analytics.name
  workspace_id        = azurerm_log_analytics_workspace.example.id
  application_type    = "web"
}


resource "azurerm_storage_account" "example" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}


resource "azurerm_virtual_network" "example" {
  name                = local.ase_v3_vnet_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "example" {
  name                 = local.ase_v3_subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoints    = ["Microsoft.Sql"]

  delegation {
    name = "Microsoft.Web.hostingEnvironments"
    service_delegation {
      name    = "Microsoft.Web/hostingEnvironments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_network_security_group" "example" {
  name                = local.ase_v3_nsg_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowTagCustom80443Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "10.0.2.0/24"
  }
  security_rule {
    name                       = "AllowTagCustom8042Inbound"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "10.0.2.0/24"
  }
  security_rule {
    name                       = "AllowTagCustom80Inbound"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "10.0.2.0/24"
  }
}

resource "azurerm_subnet_network_security_group_association" "example" {
  subnet_id                 = azurerm_subnet.example.id
  network_security_group_id = azurerm_network_security_group.example.id
}

resource "azurerm_mssql_server" "example" {
  name                         = local.sql_server_name
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = var.db_username
  administrator_login_password = var.db_password
  azuread_administrator {
    login_username = "AzureAD Admin"
    object_id      = var.sql_ad_admin_id
  }
}

resource "azurerm_mssql_database" "test" {
  name           = local.sql_db_name
  server_id      = azurerm_mssql_server.example.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  read_scale     = false
  sku_name       = "S0"
  zone_redundant = false

  tags = {
  }
}

resource "azurerm_mssql_virtual_network_rule" "example" {
  name      = local.sql_vnet_rule_name
  server_id = azurerm_mssql_server.example.id
  subnet_id = azurerm_subnet.example.id
}

resource "azurerm_app_service_environment_v3" "example" {
  name                = local.ase_v3_name
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.example.id

  internal_load_balancing_mode = "Web, Publishing"

  cluster_setting {
    name  = "DisableTls1.0"
    value = "1"
  }

  cluster_setting {
    name  = "InternalEncryption"
    value = "true"
  }

  cluster_setting {
    name  = "FrontEndSSLCipherSuiteOrder"
    value = "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
  }

  tags = {
  }
}

# Create private dns zone for the ASE
resource "azurerm_private_dns_zone" "privateDnsZone" {
  name                = local.dns_private_name
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "privateDnsZoneName_vnetLink" {
  name                  = local.privateDnsZoneName_vnetLink
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.privateDnsZone.name
  virtual_network_id    = azurerm_virtual_network.example.id
  registration_enabled  = false
}

resource "azurerm_private_dns_a_record" "privateDnsZoneName_all" {
  name                = "*"
  zone_name           = azurerm_private_dns_zone.privateDnsZone.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 3600
  records             = azurerm_app_service_environment_v3.example.internal_inbound_ip_addresses
}

resource "azurerm_private_dns_a_record" "privateDnsZoneName_scm" {
  name                = "*.scm"
  zone_name           = azurerm_private_dns_zone.privateDnsZone.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 3600
  records             = azurerm_app_service_environment_v3.example.internal_inbound_ip_addresses
}

resource "azurerm_private_dns_a_record" "privateDnsZoneName_Amp" {
  name                = "@"
  zone_name           = azurerm_private_dns_zone.privateDnsZone.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 3600
  records             = azurerm_app_service_environment_v3.example.internal_inbound_ip_addresses
}




# Create the Linux App Service Plan
resource "azurerm_service_plan" "appserviceplan" {
  name                       = local.app_service_plan_name
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  os_type                    = "Linux"
  sku_name                   = "I2v2"
  app_service_environment_id = azurerm_app_service_environment_v3.example.id
}

# Create the web app node, pass in the App Service Plan ID
resource "azurerm_linux_web_app" "webapp" {
  name                = local.webui_app_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.appserviceplan.id
  https_only          = true
  site_config {
    minimum_tls_version = "1.2"
    application_stack {
      node_version = "16-lts"
    }
  }
  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY"                  = azurerm_application_insights.example.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING"           = azurerm_application_insights.example.connection_string
    "APPINSIGHTS_PROFILERFEATURE_VERSION"             = "1.0.0"
    "APPINSIGHTS_SNAPSHOTFEATURE_VERSION"             = "1.0.0"
    "ApplicationInsightsAgent_EXTENSION_VERSION"      = "~3"
    "DiagnosticServices_EXTENSION_VERSION"            = "~3"
    "InstrumentationEngine_EXTENSION_VERSION"         = "disabled"
    "SnapshotDebugger_EXTENSION_VERSION"              = "disabled"
    "WEBSITE_HEALTHCHECK_MAXPINGFAILURES"             = "10"
    "XDT_MicrosoftApplicationInsights_BaseExtensions" = "disabled"
    "MSDEPLOY_RENAME_LOCKED_FILES"                    = "1"
    "XDT_MicrosoftApplicationInsights_Mode"           = "recommended"
    "XDT_MicrosoftApplicationInsights_PreemptSdk"     = "disabled"
    "XDT_MicrosoftApplicationInsights_PreemptSdk"     = "disabled"

  }
  identity {
    type = "SystemAssigned"
  }
}

# Create a .net webapi# web app api, pass in the App Service Plan ID
resource "azurerm_linux_web_app" "webapi" {
  name                = local.webapi_app_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.appserviceplan.id
  https_only          = true
  site_config {
    minimum_tls_version = "1.2"
    application_stack {
      dotnet_version = "6.0"
    }
  }
  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY"                  = azurerm_application_insights.example.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING"           = azurerm_application_insights.example.connection_string
    "APPINSIGHTS_PROFILERFEATURE_VERSION"             = "1.0.0"
    "APPINSIGHTS_SNAPSHOTFEATURE_VERSION"             = "1.0.0"
    "ApplicationInsightsAgent_EXTENSION_VERSION"      = "~3"
    "DiagnosticServices_EXTENSION_VERSION"            = "~3"
    "InstrumentationEngine_EXTENSION_VERSION"         = "disabled"
    "SnapshotDebugger_EXTENSION_VERSION"              = "disabled"
    "WEBSITE_HEALTHCHECK_MAXPINGFAILURES"             = "10"
    "XDT_MicrosoftApplicationInsights_BaseExtensions" = "disabled"
    "MSDEPLOY_RENAME_LOCKED_FILES"                    = "1"
    "XDT_MicrosoftApplicationInsights_Mode"           = "recommended"
    "XDT_MicrosoftApplicationInsights_PreemptSdk"     = "disabled"
    "XDT_MicrosoftApplicationInsights_PreemptSdk"     = "disabled"
  }
  connection_string {
    name  = "testDatabase"
    type  = "SQLAzure"
    value = local.db_connection
  }
  identity {
    type = "SystemAssigned"
  }
}


# add a c# function app to the app service plan
resource "azurerm_linux_function_app" "functionapp" {
  name                = local.function_app_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  storage_account_name       = azurerm_storage_account.example.name
  storage_account_access_key = azurerm_storage_account.example.primary_access_key
  service_plan_id            = azurerm_service_plan.appserviceplan.id

  site_config {
    application_stack {
      dotnet_version = "6.0"
    }
  }
  app_settings = {
    "FUNCTIONS_EXTENSION_VERSION"           = "~4"
    "FUNCTIONS_WORKER_RUNTIME"              = "dotnet"
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = azurerm_application_insights.example.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.example.connection_string
  }
  connection_string {
    name  = "testDatabase"
    type  = "SQLAzure"
    value = local.db_connection
  }
  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_monitor_diagnostic_setting" "diag_settings" {
  name                       = "diagnostic-rule"
  target_resource_id         = azurerm_linux_web_app.webapp.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.example.id

  dynamic "log" {
    iterator = entry
    for_each = local.log_analytics_log_categories
    content {
      category = entry.value
      enabled  = true

      retention_policy {
        enabled = false
      }
    }

  }

  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = false
      days    = 30
    }
  }

}

resource "azurerm_monitor_diagnostic_setting" "db_diag_settings" {
  name                       = "db_diagnostic-rule"
  target_resource_id         = azurerm_mssql_database.test.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.example.id

  dynamic "log" {
    iterator = entry
    for_each = local.log_analytics_SQL_log_categories
    content {
      category = entry.value
      enabled  = true

      retention_policy {
        enabled = false
      }
    }

  }

  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = false
      days    = 30
    }
  }

}

# creat alert ction group 
resource "azurerm_monitor_action_group" "example" {
  name                = "TF-action-group"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "action-group"
  email_receiver {
    name          = "email"
    email_address = var.action_group_mail
  }

}
# create alert rule for app service using the action group
resource "azurerm_monitor_metric_alert" "example" {
  name                = "TF-alert-rule"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_linux_web_app.webapp.id]
  description         = "Action will be triggered when Requests count is greater than 10 for 5 minutes on webapp-54168"
  severity            = 2
  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Requests"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 10
  }

  action {
    action_group_id = azurerm_monitor_action_group.example.id
  }
}
