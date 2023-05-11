variable "resource_group_location" {
  default     = "westeurope"
  description = "Location of the resource group."
}

variable "prefix" {
  default     = "lcf"
  description = "Prefix of the resorce name is unique in your Azure subscription."
}

variable "action_group_mail" {
  default     = "test@test.com"
  description = "action_group_mail."
}

variable "sql_ad_admin_id" {
  description = "sql admin ad id."
  type        = string
  sensitive   = true
}


variable "db_username" {
  description = "The username for the DB master user"
  type        = string
  sensitive   = true
}
variable "db_password" {
  description = "The password for the DB master user"
  type        = string
  sensitive   = true
}
