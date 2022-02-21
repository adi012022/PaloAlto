# Resource group to hold all the resources.
resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
}

# Generate a random password for VM-Series.
resource "random_password" "this" {
  length           = 16
  min_lower        = 16 - 4
  min_numeric      = 1
  min_special      = 1
  min_upper        = 1
  override_special = "_%@"
}


data "azurerm_virtual_network" "pa_vnet" {
  name                = "VNET-CORE-PRD-AUSE-01"
  resource_group_name = "RG-CORE-PRD-VNET-HUB"
}

data "azurerm_subnet" "pa_subnets" {
  for_each             = toset(data.azurerm_virtual_network.pa_vnet.subnets)
  name                 = each.value
  virtual_network_name = "VNET-CORE-PRD-AUSE-01"
  resource_group_name  = "RG-CORE-PRD-VNET-HUB"
}

data "azurerm_subnet" "subnet2" {
  # name = "SNET01-HUB-CORE-PRD-AUSE-01"
  name                 = "SNET02-PAN-HUB-CORE-PRD-AUSE-01"
  virtual_network_name = "VNET-CORE-PRD-AUSE-01"
  resource_group_name  = "RG-CORE-PRD-VNET-HUB"
}

data "azurerm_subnet" "subnet3" {
  # name = "SNET01-HUB-CORE-PRD-AUSE-01"
  name                 = "SNET03-PAN-HUB-CORE-PRD-AUSE-01"
  virtual_network_name = "VNET-CORE-PRD-AUSE-01"
  resource_group_name  = "RG-CORE-PRD-VNET-HUB"
}

data "azurerm_subnet" "subnet4" {
  # name = "SNET01-HUB-CORE-PRD-AUSE-01"
  name                 = "SNET04-PAN-HUB-CORE-PRD-AUSE-01"
  virtual_network_name = "VNET-CORE-PRD-AUSE-01"
  resource_group_name  = "RG-CORE-PRD-VNET-HUB"
}

output "subnet_ids" {
  description = "The identifiers of the created Subnets."
  value = {
    for k, v in data.azurerm_subnet.pa_subnets : k => v.id
  }
}


locals {
  # for_each = { for k, v in data.azurerm_subnet.pa_subnets : k => v.id }
  # [for k, v in data.azurerm_subnet.pa_subnets]
  interfaces = [
    [
    {
      name      = "SNET02"
      # name      = k
      # subnet_id = lookup(subnet_ids, "GatewatSubnet", null)
      subnet_id        = data.azurerm_subnet.subnet2.id
      create_public_ip = true
    },
        {
      name      = "SNET03"
      # name      = k
      # subnet_id = lookup(subnet_ids, "GatewatSubnet", null)
      subnet_id        = data.azurerm_subnet.subnet3.id
      # create_public_ip = true
    },
        {
      name      = "SNET04"
      # name      = k
      # subnet_id = lookup(subnet_ids, "GatewatSubnet", null)
      subnet_id        = data.azurerm_subnet.subnet4.id
      # create_public_ip = true
    },
  ],
    [
    {
      name      = "SNET02"
      # name      = k
      # subnet_id = lookup(subnet_ids, "GatewatSubnet", null)
      subnet_id        = data.azurerm_subnet.subnet2.id
      create_public_ip = true
    },
        {
      name      = "SNET03"
      # name      = k
      # subnet_id = lookup(subnet_ids, "GatewatSubnet", null)
      subnet_id        = data.azurerm_subnet.subnet3.id
      # create_public_ip = true
    },
        {
      name      = "SNET04"
      # name      = k
      # subnet_id = lookup(subnet_ids, "GatewatSubnet", null)
      subnet_id        = data.azurerm_subnet.subnet4.id
      # create_public_ip = true
    },
  ],
  #   [
  #   {
  #     name      = "SNET02"
  #     # name      = k
  #     # subnet_id = lookup(subnet_ids, "GatewatSubnet", null)
  #     subnet_id        = data.azurerm_subnet.subnet2.id
  #     create_public_ip = true
  #   },
  #       {
  #     name      = "SNET03"
  #     # name      = k
  #     # subnet_id = lookup(subnet_ids, "GatewatSubnet", null)
  #     subnet_id        = data.azurerm_subnet.subnet3.id
  #     # create_public_ip = true
  #   },
  #       {
  #     name      = "SNET04"
  #     # name      = k
  #     # subnet_id = lookup(subnet_ids, "GatewatSubnet", null)
  #     subnet_id        = data.azurerm_subnet.subnet4.id
  #     # create_public_ip = true
  #   },
  # ],
  
  ]
  # ]
}

output "local_interfaces" {
  value = local.interfaces[0]
}

output "pa_subnet" {
  value = data.azurerm_subnet.pa_subnets
}

resource "azurerm_public_ip" "this" {
  # count = 1
  # localinterface=local.interfaces[0]
  for_each = { for k, v in local.interfaces[0] : k => v if try(v.create_public_ip, false) }

  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  name                = each.value.name
  allocation_method   = "Static"
  sku                 = "Standard"
  availability_zone = try(
    each.value.availability_zone,
    # For the default, first consider using avzone if only possible. Otherwise fall back to enable_zones.
    var.enable_zones && var.avzone != null && var.avzone != ""
    ?
    var.avzone
    :
    (var.enable_zones ? "Zone-Redundant" : "No-Zone")
  )
  tags = try(each.value.tags, var.tags)
}

resource "azurerm_network_interface" "this" {
  count = length(local.interfaces[0])

  name                          = local.interfaces[0][count.index].name
  location                      = var.location
  resource_group_name           = azurerm_resource_group.this.name
  enable_accelerated_networking = count.index == 0 ? false : var.accelerated_networking # for interface 0 it is unsupported by PAN-OS
  enable_ip_forwarding          = count.index == 0 ? false : true                       # for interface 0 use false per Reference Arch
  tags                          = try(local.interfaces[0][count.index].tags, var.tags)

  ip_configuration {
    name                          = "primary"
    subnet_id                     = local.interfaces[0][count.index].subnet_id
    private_ip_address_allocation = try(local.interfaces[0][count.index].private_ip_address, null) != null ? "static" : "dynamic"
    private_ip_address            = try(local.interfaces[0][count.index].private_ip_address, null)
    public_ip_address_id          = try(azurerm_public_ip.this[0][count.index].id, local.interfaces[0][count.index].public_ip_address_id, null)
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "this" {
  # count = 1

  # localinterface=local.interfaces[0]
  for_each = { for k, v in local.interfaces[0] : k => v if try(v.enable_backend_pool, false) }

  backend_address_pool_id = each.value.lb_backend_pool_id
  ip_configuration_name   = azurerm_network_interface.this[each.key].ip_configuration[0].name
  network_interface_id    = azurerm_network_interface.this[each.key].id
}

resource "azurerm_virtual_machine" "this" {
  count = 1
  name                         = var.name[count.index]
  location                     = var.location
  resource_group_name          = azurerm_resource_group.this.name
  tags                         = var.tags
  vm_size                      = var.vm_size
  zones                        = var.enable_zones && var.avzone != null && var.avzone != "" ? [var.avzone] : null
  availability_set_id          = var.avset_id
  primary_network_interface_id = azurerm_network_interface.this[0].id

  network_interface_ids = [for k, v in azurerm_network_interface.this : v.id]

  storage_image_reference {
    id        = var.custom_image_id
    publisher = var.custom_image_id == null ? var.img_publisher : null
    offer     = var.custom_image_id == null ? var.img_offer : null
    sku       = var.custom_image_id == null ? var.img_sku : null
    version   = var.custom_image_id == null ? var.img_version : null
  }

  dynamic "plan" {
    for_each = var.enable_plan ? ["one"] : []

    content {
      name      = var.img_sku
      publisher = var.img_publisher
      product   = var.img_offer
    }
  }

  storage_os_disk {
    create_option     = "FromImage"
    name              = coalesce(var.os_disk_name, "${var.name[count.index]}-vhd")
    managed_disk_type = var.managed_disk_type
    os_type           = "Linux"
    caching           = "ReadWrite"
  }

  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  os_profile {
    computer_name  = var.name[count.index]
    admin_username = var.username
    admin_password = var.password
    custom_data = var.bootstrap_share_name == null ? null : join(
      ",",
      [
        "storage-account=${var.bootstrap_storage_account.name}",
        "access-key=${var.bootstrap_storage_account.primary_access_key}",
        "file-share=${var.bootstrap_share_name}",
        "share-directory=None"
      ]
    )
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  # After converting to azurerm_linux_virtual_machine, an empty block boot_diagnostics {} will use managed storage. Want.
  # 2.36 in required_providers per https://github.com/terraform-providers/terraform-provider-azurerm/pull/8917
  dynamic "boot_diagnostics" {
    for_each = var.bootstrap_storage_account != null ? ["one"] : []

    content {
      enabled     = true
      storage_uri = var.bootstrap_storage_account.primary_blob_endpoint
    }
  }

  identity {
    type         = var.identity_type
    identity_ids = var.identity_ids
  }
}

# resource "azurerm_lb" "example" {
#   for_each = { for k, v in local.interfaces[0] : k => v if try(v.create_public_ip, false) }
#   name                = "TestLoadBalancer"
#   location            = var.location
#   resource_group_name = azurerm_resource_group.this.name

#   frontend_ip_configuration {
#     name                 = "PublicIPAddress"
#     public_ip_address_id = azurerm_public_ip.this[each.key].id
#   }
# }