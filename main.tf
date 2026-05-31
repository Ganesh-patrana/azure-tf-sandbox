terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116.0"
    }
  }
  
  # THIS IS THE NEW VAULT CONFIGURATION
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "tfstatevault9988" # Must match exactly what you created above!
    container_name       = "tfstate"
    key                  = "sandbox.terraform.tfstate" # The name of the file it will save in Azure
  }
}

provider "azurerm" {
  features {}
}

# The physical infrastructure we want to build
resource "azurerm_resource_group" "lab_rg" {
  name     = "rg-amadeus-tf-sandbox"
  location = "Central India" 
}

# The Virtual Network (The Fortress)
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-amadeus-tf-sandbox"
  # Notice how we don't hardcode the location. 
  # We dynamically pull it from the resource group we created above!
  location            = azurerm_resource_group.lab_rg.location
  resource_group_name = azurerm_resource_group.lab_rg.name
  address_space       = ["10.0.0.0/16"]
}

# The Subnet (The Room for Kubernetes)
resource "azurerm_subnet" "aks_subnet" {
  name                 = "snet-aks-cluster"
  resource_group_name  = azurerm_resource_group.lab_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}
# The Kubernetes Cluster (The Compute Engine)
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-amadeus-sandbox"
  location            = azurerm_resource_group.lab_rg.location
  resource_group_name = azurerm_resource_group.lab_rg.name
  dns_prefix          = "akssandbox"
# Add these two lines to stop Terraform from trying to disable them
  oidc_issuer_enabled       = true
  workload_identity_enabled = true
  # 1. The Node Pool (The VMs)
  default_node_pool {
    name           = "default"
    node_count     = 2 # FinOps: We only need 1 node for testing
    vm_size        = "Standard_D2s_v3" # FinOps: The cheapest burstable VM ($30/mo, covered by free tier)
    
    # 2. The Network Attachment (Plugging it into Day 9's room)
    vnet_subnet_id = azurerm_subnet.aks_subnet.id 
  }

  # 3. The Identity (IAM)
  # This gives the cluster a robot account so it can talk to Azure 
  # (e.g., when it needs to create a public Load Balancer IP)
  identity {
    type = "SystemAssigned"
  }

  # 4. The Enterprise Network Plugin
  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    # We force Kubernetes to use 192.168.x.x internally so it doesn't 
    # fight with our physical 10.0.x.x VNet.
    service_cidr      = "192.168.0.0/16"
    dns_service_ip    = "192.168.0.10"
  }
}

# 5. Build the Azure Container Registry (The Vault)
resource "azurerm_container_registry" "acr" {
  # NOTE: ACR names must be globally unique across all of Azure! 
  # Change the numbers below to something random so it doesn't collide with anyone else.
  name                = "patrana345118" 
  resource_group_name = azurerm_resource_group.lab_rg.name
  location            = azurerm_resource_group.lab_rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

# 6. Give Kubernetes Permission to pull from the Vault
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}