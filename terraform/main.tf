terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
}

locals {
  resource_group_name = coalesce(var.resource_group_name, "${var.prefix}-rg")
  vm_name             = coalesce(var.vm_name, "${var.prefix}-vm")

  common_tags = merge(var.tags, {
    managed_by = "terraform"
    workload   = "3x-ui-proxy"
  })
}

resource "azurerm_resource_group" "this" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_virtual_network" "this" {
  name                = "${var.prefix}-vnet"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.common_tags
}

resource "azurerm_subnet" "this" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_cidr]
}

resource "azurerm_public_ip" "this" {
  name                = "${var.prefix}-pip"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_network_security_group" "this" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.common_tags

  security_rule {
    name                         = "Allow-SSH-Admin"
    priority                     = 100
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_range       = "22"
    source_address_prefix        = length(var.allowed_admin_cidrs) == 1 ? var.allowed_admin_cidrs[0] : null
    source_address_prefixes      = length(var.allowed_admin_cidrs) > 1 ? var.allowed_admin_cidrs : null
    destination_address_prefix   = "*"
  }

  security_rule {
    name                         = "Allow-3X-UI-Panel-Admin"
    priority                     = 110
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_range       = tostring(var.panel_port)
    source_address_prefix        = length(var.allowed_admin_cidrs) == 1 ? var.allowed_admin_cidrs[0] : null
    source_address_prefixes      = length(var.allowed_admin_cidrs) > 1 ? var.allowed_admin_cidrs : null
    destination_address_prefix   = "*"
  }

  security_rule {
    name                         = "Allow-VLESS-Reality"
    priority                     = 120
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_range       = tostring(var.vless_port)
    source_address_prefix        = length(var.proxy_allowed_cidrs) == 1 ? var.proxy_allowed_cidrs[0] : null
    source_address_prefixes      = length(var.proxy_allowed_cidrs) > 1 ? var.proxy_allowed_cidrs : null
    destination_address_prefix   = "*"
  }

  security_rule {
    name                         = "Allow-Hysteria2"
    priority                     = 130
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "Udp"
    source_port_range            = "*"
    destination_port_range       = tostring(var.hysteria2_port)
    source_address_prefix        = length(var.proxy_allowed_cidrs) == 1 ? var.proxy_allowed_cidrs[0] : null
    source_address_prefixes      = length(var.proxy_allowed_cidrs) > 1 ? var.proxy_allowed_cidrs : null
    destination_address_prefix   = "*"
  }

  security_rule {
    name                         = "Allow-Subscription"
    priority                     = 140
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_range       = tostring(var.subscription_port)
    source_address_prefix        = length(var.subscription_allowed_cidrs) == 1 ? var.subscription_allowed_cidrs[0] : null
    source_address_prefixes      = length(var.subscription_allowed_cidrs) > 1 ? var.subscription_allowed_cidrs : null
    destination_address_prefix   = "*"
  }
}

resource "azurerm_network_interface" "this" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.this.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.this.id
  }
}

resource "azurerm_network_interface_security_group_association" "this" {
  network_interface_id      = azurerm_network_interface.this.id
  network_security_group_id = azurerm_network_security_group.this.id
}

resource "azurerm_linux_virtual_machine" "this" {
  name                            = local.vm_name
  resource_group_name             = azurerm_resource_group.this.name
  location                        = azurerm_resource_group.this.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.this.id]
  priority                        = var.use_spot ? "Spot" : "Regular"
  eviction_policy                 = var.use_spot ? var.spot_eviction_policy : null
  max_bid_price                   = var.use_spot ? var.spot_max_bid_price : null
  custom_data = base64encode(templatefile("${path.module}/cloud-init.sh.tftpl", {
    hysteria_cert_cn        = var.hysteria_cert_cn
    install_3x_ui           = var.install_3x_ui
    install_workspace_tools = var.install_workspace_tools
    udp_buffer_bytes        = var.udp_buffer_bytes
  }))
  tags = local.common_tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  boot_diagnostics {}
}
