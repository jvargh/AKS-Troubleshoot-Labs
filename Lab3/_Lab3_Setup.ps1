Step 1: Set up the environment
============================================================================================================
1.	Setup up AKS as outlined in this section.

2.	Create and switch to the newly created namespace
kubectl create ns student
kubectl config set-context --current --namespace=student
# Verify current namespace
kubectl config view --minify --output 'jsonpath={..namespace}' 

3.	Change directory to Lab3 > cd Lab3

4.	Install VM, VM_VNet and Nginx. Create NSG and attach to VM Subnet

# Values required for the below variables can be found in AKS MC Resource Group as seen in below figure.
$resource_group="MC_akslabs_akslabs_eastus" # <- replace only if different from your environment
$vm_vnet="vmlabs-vnet" # <- don’t replace. Use as-is
$vm_name="vmlabs"	   # <- don’t replace. Use as-is
$vm_nsg="vmlabs_nsg"   # <- don’t replace. Use as-is


# Create VNet for WebServer VM
az network vnet create --name $vm_vnet --resource-group $resource_group --address-prefixes 10.0.0.0/16 --subnet-name default --subnet-prefix 10.0.0.0/24

# Create VM in the VNet
az vm create --resource-group $resource_group --name $vm_name --image UbuntuLTS --vnet-name $vm_vnet --subnet default --public-ip-address '""' --size Standard_DS1_v2 --admin-username azureuser --generate-ssh-keys --os-disk-delete-option "Delete" --nic-delete-option "Delete" --data-disk-delete-option "Delete"

# Install nginx on the VM and open port 80 for incoming traffic using the below cmd
az vm extension set --publisher Microsoft.Azure.Extensions --version 2.1 --name CustomScript --vm-name $vm_name --resource-group $resource_group --settings "{'commandToExecute':'sudo apt-get update -y && sudo apt-get install -y nginx'}"

# Install the CustomScript extension on the VM and runs below cmd to install nginx.
az vm open-port --port 80 --resource-group $resource_group --name $vm_name

# Create NSG
az network nsg create -g $resource_group -n $vm_nsg

# Get VM subnet from VNet
$subnet_name=$(az network vnet subnet list -g $resource_group --vnet-name $vm_vnet --query "[0].name")

# Attach NSG to VM subnet
az network vnet subnet update -g $resource_group --vnet-name $vm_vnet -n $subnet_name --network-security-group $vm_nsg

3. Create VNet Peering between AKS_VNet and VM_VNet

# Insert here the AKS and VM VNet names, VM name and Resource Group name, AKS NSG name
$aks_vnet="aks-vnet-18226021"  # <- replace with one from your environment
$aks_nsg="aks-agentpool-18226021-nsg" # <- replace with one from your environment
$vm_ip=$(az vm show -g $resource_group -n $vm_name --show-details --query 'privateIps' -o tsv)
echo $vm_ip

# Get the IDs for AKS_VNet
$aks_vnet_id=$(az network vnet show -g $resource_group -n $aks_vnet --query id --out tsv)
echo $aks_vnet_id
# Get the IDs for VM VNet
$vm_vnet_id=$(az network vnet show -g $resource_group -n $vm_vnet --query id --out tsv)
echo $vm_vnet_id

# Create both halves of the VNet Peer
az network vnet peering create -n peerAKStoVM -g $resource_group --vnet-name $aks_vnet --remote-vnet $vm_vnet_id --allow-forwarded-traffic --allow-vnet-access 

az network vnet peering create -n peerVMtoAKS -g $resource_group --vnet-name $vm_vnet --remote-vnet $aks_vnet_id --allow-forwarded-traffic --allow-vnet-access 

# Check status of the 2 halves of VNet Peer
az network vnet peering show --name peerAKStoVM -g $resource_group --vnet-name $aks_vnet
az network vnet peering show --name peerVMtoAKS -g $resource_group --vnet-name $vm_vnet

# Confirm "allowForwardedTraffic": true, "allowVirtualNetworkAccess": true from below
az network vnet peering show --name peerAKStoVM -g $resource_group --vnet-name $aks_vnet --query '{AllowForwardedTraffic:allowForwardedTraffic, AllowVirtualNetworkAccess:allowVirtualNetworkAccess}'

Step 2: Setup Test pod and verify that the VM web server is accessible
============================================================================================================
# Create test-pod
kubectl run test-pod --image=nginx --port=80 --restart=Never
kubectl exec -it test-pod -- bash
# Run below on test-pod bash shell
apt-get update -y
apt-get install traceroute -y
exit

# End-to-End test: Curl should return HTML page
kubectl exec -it test-pod -- curl -m 5 $vm_ip	

Step 3: Break Networking 
============================================================================================================
From Lab3, run broken1.ps1
cd Lab3; .\broken1.ps1
  
Step 4: Troubleshoot connectivity issue
============================================================================================================
1.	Assume the VM Web Server is functional and web application is running, theres no need to SSH and validate.
-	If testing is needed options are, create public VM in same VNet and curl test. 
-	Bastion VM is another option or Associate a newly created Public IP with VM instance

2.	Validate peering is setup right: Steps to setting up VNet peering

3.	Check curl connectivity which should result in connection timeout after 5s
kubectl exec -it test-pod -- curl -m 5 $vm_ip	

4.	Check if NSG on the AKS or VM subnets have any DENY rules that might block incoming/outgoing traffic. Check link on custom network security group blocking traffic.
az network nsg rule list -g $resource_group --nsg-name $aks_nsg 
az network nsg rule list -g $resource_group --nsg-name $vm_nsg

# From VM NSG, below should return "access": "Deny"
az network nsg rule list -g $resource_group --nsg-name $vm_nsg --query "[?destinationPortRange== '80']" --query "[0].{access:access}"

5.	Check if Peering setup is Connected and up from both ends. Check link on peering in same subscription.
# Specifically check the "allowForwardedTraffic" and "allowGatewayTransit" values are enabled.
az network vnet peering show --name peerAKStoVM -g $resource_group --vnet-name $aks_vnet
az network vnet peering show --name peerVMtoAKS -g $resource_group --vnet-name $vm_vnet

# Below should return false
az network vnet peering show --name peerVMtoAKS -g $resource_group --vnet-name $vm_vnet --query "{allowForwardedTraffic:allowForwardedTraffic,allowGatewayTransit:allowGatewayTransit}"

Step 5: Restore service
============================================================================================================
1. Enable peering on VM VNet
az network vnet peering update -n peerVMtoAKS -g $resource_group --vnet-name $vm_vnet --set allowForwardedTraffic=true allowVirtualNetworkAccess=true

2. Check curl connectivity which should result in connection timeout after 5s. Issue persists.
kubectl exec -it test-pod -- curl -m 5 $vm_ip	

3. Remove NSG rule to Allow web traffic on port 80.
az network nsg rule delete -n DenyPort80Inbound -g $resource_group --nsg-name $vm_nsg 

Step 6: Validate connectivity
============================================================================================================
After 60s, check curl connectivity which should return HTML page from Web Server on hosted VM. 
kubectl exec -it test-pod -- curl -m 5 $vm_ip	

Step 7: What was in the broken files
============================================================================================================
Broken1.ps1 was used to 
1.	Create a rule on VM NSG to deny access to HTTP traffic
2.	Disable critical peering parameters i.e., Block Traffic Forwarding and Block remote VNet access
 

Step 8: Cleanup
============================================================================================================
kubectl delete pod/test-pod

az network vnet peering delete -n peerAKStoVM -g $resource_group --vnet-name $aks_vnet 
az network vnet peering delete -n peerVMtoAKS -g $resource_group --vnet-name $vm_vnet 

# DETACH VM NSG from VM subnet and DELETE NSG 
az network vnet subnet update -n $subnet_name -g $resource_group --vnet-name $vm_vnet -n $subnet_name --network-security-group '""'
az network nsg delete -g $resource_group -n $vm_nsg

# Delete VM, NSG and it VNet
az vm delete --resource-group $resource_group --name $vm_name -y
az network vnet delete --name $vm_vnet --resource-group $resource_group
az network nsg delete -g $resource_group -n $vm_name"NSG"

k delete ns student
