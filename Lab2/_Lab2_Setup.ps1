Step 1: Set up the environment
============================================================================================================
1.	Setup up AKS as outlined in this section.

2.	Create and switch to the newly created namespace
kubectl create ns student
kubectl config set-context --current --namespace=student
# Verify current namespace
kubectl config view --minify --output 'jsonpath={..namespace}' 

3.	Change directory to Lab2 > cd Lab2

Step 2: Verify DNS Resolution within a Cluster
============================================================================================================
1. Create pod for DNS validation within Pod 

  kubectl run dns-pod --image=nginx --port=80 --restart=Never
  kubectl exec -it dns-pod -- bash 

  # Run these commands at the bash prompt
  apt-get update -y
  apt-get install dnsutils -y
  exit

2. Expose dns-pod with service type Load Balancer. 
    kubectl expose pod dns-pod --name=dns-svc --port=80 --target-port=80 --type LoadBalancer

3. Test and confirm DNS resolution resolves to the correct IP address. Get External-IP and verify HTML page 
  kubectl exec -it dns-pod -- nslookup kubernetes.default.svc.cluster.local
  kubectl get svc > get EXTERNAL-IP 
  From cmd prompt run "curl <EXTERNAL-IP>"

  Step 3: Break DNS resolution 
  ============================================================================================================
  1. From Lab2 apply broken1.yaml
    kubectl apply -f broken1.yaml
  
  2. Confirm below results in ‘connection timed out; no servers could be reached’
      kubectl exec -it dns-pod -- nslookup kubernetes.default.svc.cluster.local
  
  Step 4: Troubleshoot DNS Resolution Failures
  ============================================================================================================
  1. Verify DNS resolution works within the AKS cluster
  kubectl exec -it dns-pod -- nslookup kubernetes.default.svc.cluster.local
  # If response ‘connection timed out; no servers could be reached’ then proceed below with troubleshooting
  
  2. Validate the DNS service which should show port 53 in use
  kubectl get svc kube-dns -n kube-system
  
  3. Check logs for pods associated with kube-dns
  $coredns_pod=$(kubectl get pods -n kube-system -l k8s-app=kube-dns -o=jsonpath='{.items[0].metadata.name}')
  kubectl logs -n kube-system $coredns_pod
  
  4. If a custom ConfigMap is present, verify that the configuration is correct.
  kubectl describe cm coredns-custom -n kube-system
  
  5. Check for networkpolicies currently in effect. If DNS related then describe and confirm no blockers. If network policy is a blocker then have that removed.
  
  kubectl get networkpolicy -A
  NAMESPACE     NAME              	POD-SELECTOR             
  kube-system   block-dns-ingress	k8s-app=kube-dns         
  
  kubectl describe networkpolicy block-dns-ingress -n kube-system
  # should show on Ingress path not allowing DNS traffic to UDP 53
  
  6. Remove the offending policy
  kubectl delete networkpolicy block-dns-ingress -n kube-system
  
  7. Verify DNS resolution works within the AKS cluster. Below is another way to create a Pod to execute task as nslookup and delete on completion
  
  kubectl run -it --rm --restart=Never test-dns --image=busybox --command -- nslookup kubernetes.default.svc.cluster.local
  # If the DNS resolution is working correctly, you should see the correct IP address associated with the domain name
  
  8. Check NSG has any DENY rules that might block port 80. If exists, then have that removed
  # Below CLI steps can also be performed as a lookup on Azure portal under NSG
  
  
  Step 5: Create external access via Loadbalancer
  ============================================================================================================
  1. Expose dns-pod with service type Load Balancer. 
  kubectl expose pod dns-pod --name=dns-svc --port=80 --target-port=80 --type LoadBalancer
  
  2. Confirm allocation of External-IP.
  kubectl get svc
  
  3. Confirm External-IP access works within cluster.  
  kubectl exec -it dns-pod -- curl <EXTERNAL-IP>
  
  4. Confirm from browser that External-IP access fails from internet to cluster.
  curl <EXTERNAL-IP>
  

  Step 6: Troubleshoot broken external access via Loadbalancer
  ============================================================================================================
  1. Check if AKS NSG applied on the VM Scale Set has an Inbound HTTP Allow rule.
  
  2. Check if AKS Custom NSG applied on the Subnet has an ALLOW rule and if none then apply as below.
  $custom_aks_nsg = "custom_aks_nsg" # <- verify
  $nsg_list=az network nsg list --query "[?contains(name,'$custom_aks_nsg')].{Name:name, ResourceGroup:resourceGroup}" --output json
  
  # Extract Custom AKS Subnet NSG name, NSG Resource Group
  $nsg_name=$(echo $nsg_list | jq -r '.[].Name')
  
  $resource_group=$(echo $nsg_list | jq -r '.[].ResourceGroup')
  echo $nsg_list, $nsg_name, $resource_group
  
  $EXTERNAL_IP="<insert>"
  az network nsg rule create --name AllowHTTPInbound `
  --resource-group $resource_group --nsg-name $nsg_name `
  --destination-port-range 80 --destination-address-prefix $EXTERNAL_IP `
  --source-address-prefixes Internet --protocol tcp `
  --priority 100 --access allow
  
  3. After ~60s, confirm from browser that External-IP access succeeds from internet to cluster.
  curl <EXTERNAL-IP>
  
  Step 6: What was in the broken files
  1. Broken1.yaml is a NP that blocks UDP ingress requests on port 53 to all Pods
   
  
  
  Step 7: Cleanup
  ============================================================================================================
  k delete pod/dns-pod
  or 
  k delete ns student
  az network nsg rule delete --name AllowHTTPInbound --resource-group $resource_group --nsg-name $nsg_name
  
  