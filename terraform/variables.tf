variable "subscription_id" {
  description = "Azure subscription ID for the target account/subscription. Set with TF_VAR_subscription_id or terraform.tfvars."
  type        = string

  validation {
    condition     = length(trimspace(var.subscription_id)) > 0
    error_message = "subscription_id is required for portable azurerm v4 usage."
  }
}

variable "prefix" {
  description = "Short lowercase prefix used for Azure resource names."
  type        = string
  default     = "proxy"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}[a-z0-9]$", var.prefix))
    error_message = "prefix must be 3-22 lowercase letters, numbers, or hyphens, starting with a letter and ending with a letter or number."
  }
}

variable "resource_group_name" {
  description = "Optional existing-style resource group name. Defaults to <prefix>-rg."
  type        = string
  default     = null
}

variable "vm_name" {
  description = "Optional VM name. Defaults to <prefix>-vm."
  type        = string
  default     = null
}

variable "location" {
  description = "Azure region. Use a region close to the target users for lower latency."
  type        = string
  default     = "westus2"
}

variable "admin_username" {
  description = "Linux admin username."
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key used for VM login."
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "vm_size" {
  description = "VM SKU. Standard_B2ms gives 8 GiB RAM; reduce only if 3X-UI and tooling memory pressure is acceptable."
  type        = string
  default     = "Standard_B2ms"
}

variable "use_spot" {
  description = "Use Azure Spot capacity. Keep false for a stable proxy because Spot VMs can be evicted."
  type        = bool
  default     = false
}

variable "spot_eviction_policy" {
  description = "Spot eviction policy when use_spot is true."
  type        = string
  default     = "Deallocate"
}

variable "spot_max_bid_price" {
  description = "Spot max bid price. -1 means pay up to on-demand price."
  type        = number
  default     = -1
}

variable "os_disk_type" {
  description = "Managed OS disk type."
  type        = string
  default     = "Standard_LRS"
}

variable "vnet_cidr" {
  description = "Virtual network CIDR."
  type        = string
  default     = "10.3.0.0/16"
}

variable "subnet_cidr" {
  description = "Subnet CIDR."
  type        = string
  default     = "10.3.0.0/24"
}

variable "allowed_admin_cidrs" {
  description = "CIDRs allowed to reach SSH and the 3X-UI panel. Replace * with your own IP/CIDR for production."
  type        = list(string)
  default     = ["*"]

  validation {
    condition     = length(var.allowed_admin_cidrs) > 0
    error_message = "allowed_admin_cidrs must contain at least one CIDR or *."
  }
}

variable "proxy_allowed_cidrs" {
  description = "CIDRs allowed to reach public proxy ports."
  type        = list(string)
  default     = ["*"]

  validation {
    condition     = length(var.proxy_allowed_cidrs) > 0
    error_message = "proxy_allowed_cidrs must contain at least one CIDR or *."
  }
}

variable "subscription_allowed_cidrs" {
  description = "CIDRs allowed to reach the subscription service."
  type        = list(string)
  default     = ["*"]

  validation {
    condition     = length(var.subscription_allowed_cidrs) > 0
    error_message = "subscription_allowed_cidrs must contain at least one CIDR or *."
  }
}

variable "vless_port" {
  description = "VLESS + REALITY TCP port."
  type        = number
  default     = 443
}

variable "hysteria2_port" {
  description = "Hysteria2 UDP port."
  type        = number
  default     = 4443
}

variable "panel_port" {
  description = "3X-UI panel TCP port."
  type        = number
  default     = 2053
}

variable "subscription_port" {
  description = "3X-UI subscription TCP port."
  type        = number
  default     = 2096
}

variable "udp_buffer_bytes" {
  description = "Linux UDP/TCP socket buffer ceiling applied through sysctl."
  type        = number
  default     = 16777216
}

variable "hysteria_cert_cn" {
  description = "Common Name and DNS SAN for the self-signed Hysteria2 certificate created by cloud-init."
  type        = string
  default     = "bing.com"
}

variable "install_3x_ui" {
  description = "Install 3X-UI during first boot. This bootstraps the panel, but inbounds still need to be created/restored."
  type        = bool
  default     = true
}

variable "install_workspace_tools" {
  description = "Install optional Node.js AI CLI tooling. Disabled by default because it is unrelated to proxy recovery."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Extra tags applied to Azure resources."
  type        = map(string)
  default     = {}
}
