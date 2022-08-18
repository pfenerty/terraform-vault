variable "aws_region" {
  type        = string
  description = "AWS Region to create resources in"
}

variable "name_prefix" {
  type        = string
  description = "String to prefix before AWS resource names"
  default     = ""
}

variable "common_tags" {
  type        = map(string)
  description = "Set of common tags to apply to all AWS resources"
  default     = {}
}

variable "vault_replicas" {
  type        = number
  description = "Number of Vault replicas"
  default     = 3
}

variable "vault_ui_enable" {
  type        = bool
  description = "Enable Vault UI"
  default     = true
}

variable "vault_auto_unseal" {
  type        = bool
  description = "Enable Vault Auto Unseal via AWS KMS"
  default     = true
}
