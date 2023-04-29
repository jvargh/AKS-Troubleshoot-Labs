##################################################################
# Add Network Security Group (NSG) Inbound rule to block HTTP 80 #
##################################################################

# Get NSG name, resourceGroup for AKS
$nsg_list= az network nsg list `
 --query "[?contains(resourceGroup,'$aks_name')].{Name:name, ResourceGroup:resourceGroup}" `
 --output json

# Extract NSG name, NSG ResourceGroup
$nsg_name=$(echo $nsg_list | jq -r '.[].Name')
$resource_group=$(echo $nsg_list | jq -r '.[].ResourceGroup')
echo $nsg_list, $nsg_name, $resource_group

# Create NSG rule in NSG
az network nsg rule create --name DenyInbound --resource-group $resource_group `
--nsg-name $nsg_name --destination-port-range 80 `
--destination-address-prefix * --priority 100 --access deny


