$resource_group="MC_akslabs_akslabs_eastus" # <- replace with AKS Resource Group from your environment
$vm_vnet="vmlabs-vnet"
$vm_nsg="vmlabs_nsg"

# Use VM NSG to block Inbound access on port 80
az network nsg rule create -n DenyPort80Inbound `
    -g $resource_group --nsg-name $vm_nsg --destination-port-range 80 `
    --destination-address-prefix * --priority 100 --access deny

# Block peering access on VM end 
# Disable peering from VM Vnet 
az network vnet peering update -n peerVMtoAKS `
    -g $resource_group --vnet-name $vm_vnet `
    --set allowForwardedTraffic=false allowVirtualNetworkAccess=false

    