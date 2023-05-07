Lab setup instructions
======================

1. Run below commands to initialize the Setup process.

az login
az account set --subscription "Azure Pass - Sponsorship"
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Monitor
az provider register --namespace Microsoft.ManagedIdentity
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.OperationsManagement
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Kubernetes

From 'portal.azure.com' > Subscriptions > Select your Azure subscription > select 'Resource Providers' > Refresh and confirm all providers in Registered state.
Or use 
az provider list --query "[?registrationState=='Registered'].namespace"


2. Build out Resource Group and Setup Log Analytics Workspace for AKS cluster

# Build out Resource Groups and AKS Cluster
# Don’t replace any of below. Use as-is
$resource_group="akslabs" 		
$aks_name="akslabs"			
$location="eastus"				
$aks_vnet=$aks_name+"-vnet"		
$aks_subnet=$aks_name+"-subnet"	
$log_analytics_workspace_name=$aks_name+"-log-analytics-workspace"

echo $resource_group
echo $aks_name
echo $aks_vnet
echo $aks_subnet
echo $location
echo $log_analytics_workspace_name

az group create --name $resource_group --location $location

# Create log analytics workspace and save its Resource Id to use in aks create
az monitor log-analytics workspace create `
    --resource-group $resource_group `
    --workspace-name $log_analytics_workspace_name `
    --location $location --no-wait

$log_analytics_workspace_resource_id=az monitor log-analytics workspace show `
    --resource-group $resource_group `
    --workspace-name $log_analytics_workspace_name `
    --query id --output tsv
echo $log_analytics_workspace_resource_id


3. Create custom AKS VNet and Subnet

az network vnet create `
  --resource-group $resource_group `
  --name $aks_vnet `
  --address-prefixes 10.224.0.0/12 `
  --subnet-name $aks_subnet `
  --subnet-prefixes 10.224.0.0/16

$vnet_subnet_id=az network vnet subnet show `
    --resource-group $resource_group `
    --vnet-name $aks_vnet  `
    --name $aks_subnet `
    --query id --output tsv
echo $vnet_subnet_id

4. Create AKS cluster using custom VNet subnet.

az aks create `
    --resource-group $resource_group `
    --name $aks_name `
    --node-count 1 `
    --node-vm-size standard_ds2_v2 `
    --network-plugin kubenet `
	--vnet-subnet-id $vnet_subnet_id `
    --enable-managed-identity `
    --network-policy calico `
    --enable-addons monitoring `
    --generate-ssh-keys `
    --workspace-resource-id $log_analytics_workspace_resource_id

5. Setup kubectl alias:
# Bash
alias k='kubectl'
# Powershell 
set-alias -Name k -Value kubectl

# Install the latest k8s-configuration and k8s-extension CLI extension packages
az extension add -n k8s-configuration # or use update 
az extension add -n k8s-extension # or use update
az extension list -o table

6. Setup credentials:
az aks get-credentials -g $resource_group -n $aks_name --overwrite-existing

7. Switch to the newly created namespace

kubectl create ns student
kubectl config set-context --current --namespace=student
# Verify current namespace
kubectl config view --minify --output 'jsonpath={..namespace}' 
# Confirm ability to view 
kubectl get pods -A

8. If jq and curl isnt installed, open a Powershell as Admin, and run below commands:

choco install jq -y
choco install curl -y
choco install grep -y

9. Enable AKS Diagnostics logging using CLI as shown. 

$aks_resource_id=az aks show `
    --resource-group $resource_group `
    --name $aks_name `
    --query id `
    --output tsv
echo $aks_resource_id

az monitor diagnostic-settings create `
    --name aks_diagnostics `
    --resource $aks_resource_id `
    --logs '[{"category":"kube-apiserver","enabled":true},{"category":"kube-controller-manager","enabled":true},{"category":"kube-scheduler","enabled":true},{"category":"kube-audit","enabled":true},{"category":"cloud-controller-manager","enabled":true},{"category":"cluster-autoscaler","enabled":true},{"category":"kube-audit-admin","enabled":true}]' `
    --metrics '[{"category":"AllMetrics","enabled":true}]' `
	--workspace $log_analytics_workspace_resource_id

# This should be visible from Portal in AKS > Diagnostics settings. After some time, AzureDiagnostics should appear in Monitoring > Logs as shown in doc.
	  

 

