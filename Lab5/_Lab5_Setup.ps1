Step 1: Set up the environment.
============================================================================================================
1.	Setup up AKS as outlined in this section.

2.	Create and switch to the newly created namespace.
kubectl create ns student
kubectl config set-context --current --namespace=student

# Verify current namespace
kubectl config view --minify --output 'jsonpath={..namespace}' 

3.	Enable Cloud Shell within Azure Portal. Select Bash option and set the storage and allow completion. 

From AKS blade > Overview > Connect, run the ‘az account..’ and ‘az aks get-credentials..’ commands in the Cloud Shell. Use kubectl get nodes  to verify it works.

4.	Download kubectl-node-shell using below steps. When executed it creates an Nsenter pod, which will have the advanced privileges to run iptables. This level of access is not available with debug pods to connect to Nodes.

curl -LO https://github.com/kvaps/kubectl-node-shell/raw/master/kubectl-node_shell
$ ./kubectl-node_shell <node-name from above>

5.	From Lab5 deploy PS scripts.  
cd Lab5; .\working.ps1

Scripts setup the deployment with 3 Pod replicas, and service of type Loadbalancer running on port 4000. They are both identical applications, except for the image.

Working
=======
apiVersion: v1
kind: Service
metadata:
  name: working-app-clusterip
spec:
  type: LoadBalancer
  ports:
  - port: 4000
    protocol: TCP
    targetPort: 4000
  selector:
    app: working-app
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: working-app-deployment
  labels:
    app: working-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: working-app
  template:
    metadata:
      labels:
        app: working-app
    spec:
      containers:
      - name: working-app
        image: jvargh/nodejs-app:working
        ports:
        - containerPort: 4000
---

Faulty
======
apiVersion: v1
kind: Service
metadata:
  name: faulty-app-clusterip
spec:
  type: LoadBalancer
  ports:
  - port: 4000
    protocol: TCP
    targetPort: 4000
  selector:
    app: faulty-app
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: faulty-app-deployment
  labels:
    app: faulty-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: faulty-app
  template:
    metadata:
      labels:
        app: faulty-app
    spec:
      containers:
      - name: faulty-app
        image: jvargh/nodejs-app:faulty
        ports:
        - containerPort: 4000
---

3. Make a note of the Cluster and External IPs associated with Faulty and Working apps.
 
4. Create pod for validation within Pod 
kubectl run test-pod --image=nginx --port=80 --restart=Never

5.  Allow Inbound access through Custom NSG
$custom_aks_nsg="custom_aks_nsg" # <- verify
$nsg_list=az network nsg list --query "[?contains(name,'$custom_aks_nsg')].{ ResourceGroup:resourceGroup}" --output json

# Extract NSG Resource Group
$resource_group=$(echo $nsg_list | jq -r '.[].ResourceGroup')
echo $nsg_list, $nsg_name, $resource_group

az network nsg rule create --name AllowHTTPInbound `
--resource-group $resource_group --nsg-name $custom_aks_nsg `
--destination-port-range * --destination-address-prefix * `
--source-address-prefixes Internet --protocol tcp `
--priority 100 --access allow

6.  Validation Test
1. Test internal access within cluster 
kubectl exec -it test-pod -- curl working-app-clusterip:4000  # works
kubectl exec -it test-pod -- curl faulty-app-clusterip:4000	  # fails with Connection refused

7. Test external access to cluster
curl <Working-App-External-IP>:4000  # works
curl <Faulty-App-External-IP>:4000  # fails with `Unable to connect to the remote server`



Step 2: Walk through the Kubernetes view
============================================================================================================
Use this step to confirm that from Internet through to the Pod, Kubernetes setup is configured correctly.
 
1. Curl request hits the Load balancer Public IP assigned to the service. Service IP get added as a Front End IP rule to the existing AKS Loadbalancer. 
2. Service ties into the endpoints by forwarding requests to the pods, and in turn to the Application container.
 

 
Step 3: Verify Loadbalancer Insights and Metrics
============================================================================================================
From LoadBalancer blade, go to AKS LB > Insights. Ensure the Loadbalancer is functional and capturing metrics. Can see from below theres an issue with the backend pool. 

 
From Detailed metrics > ‘Frontend and Backend Availability’ section, you should see the Failing app FE IP is Red for Availability but Working app FE IP is Green for Availability. Change ‘Time Range’ to 5m.
 
 
Step 4: Perform Network trace to the Faulty app
============================================================================================================
Use this step to confirm if the Faulty app is even listening. We should see Working app responding but Faulty app does not.

# IP addresses listed below applies to this example,  for reference only. Replace with your own
test-pod-ip = 10.244.0.61
working-app-svc = 10.0.81.248
faulty-app-svc = 10.0.189.236 
working-pod-IPs = 10.244.0.54, 55, 56
faulty-pod-IPs = 10.244.0.57, 58, 59

1. Get the test-pod IP and destination service IP and run tcpdump on the associated Node of the Pod

2. Working app provides trace
kubectl exec -it test-pod – curl <working-app-svc>:4000

3. From Cloud Shell in Azure Portal, run below command. Get node from ‘kubectl get pods -o wide’.
kubectl-node_shell <Node associated with pods>

4. Setup trace from test-pod and the Pod network.
tcpdump -en -i any src <test-pod IP> and dst net 10.244.0.0/16

5. From another terminal, execute curl to Faulty and Working apps service.
kubectl exec -it test-pod -- curl <faulty-app-svc>:4000
kubectl exec -it test-pod -- curl <working-app-svc>:4000

Working App
<see fig> 

Faulty App
<see fig> 

From trace above, theres only response from Working App pod. No response from Faulty App pod.

Step 5: Advanced tcpdump
============================================================================================================
This section captures to file, copy from nsenter pod to local desktop where Wireshark will visualize the trace. Need two consoles.

1. From Cloud Shell run 'kubectl-node_shell <Node associated with pods>'.  Run below command from /tmp
cd /tmp
tcpdump -nn -s0 -vvv -i any -w capture.cap
where
	-nn: display IP addresses and port numbers in numeric 
	-s0: set snapshot=0 i.e., capture entire packet
	-l: output asap without buffering 
	-vvv: max verbosity

2. From 2nd console run below to view the HTML output
kubectl exec -it <test-pod> -- curl <working-app-pod>

3. On Cloud Shell, break the tcpdump (CTRL+c) and capture.cap should be written to /tmp

4. From 2nd console use below command to download capture.cap. Use ‘k get pod’ to get nsenter pod name.
	kubectl cp <nsenter-pod>:/tmp/capture.cap capture.cap

# Wireshark will need to be installed for next step. See link
https://2.na.dl.wireshark.org/win64/Wireshark-win64-4.0.4.exe 

5. Open capture.cap in Wireshark. Use below filter to refine view. 
ip.addr == <test-pod> # might not need this "and ip.addr == <working-app-pod>"

6. Use Analyze > Follow > HTTP Stream to view the HTTP flow as seen below
<see fig>  

7. For long running traces that need to be saved to storage account, use utility below. Helm install creates storage account and daemonset creates tcpdump Pods on all nodes, that continuously writes capture to storage account.
https://github.com/amjadaljunaidi/tcpdump/blob/main/README.md 
Uninstall Helm chart to stop tracing and capture will be left intact in storage account. 

8. To just focus on one node than all nodes, as above, use Lab5 > tcpdump-pod.yaml.  
Change node name and use below command. Storage account > file share should have tcpdump contents.

kubectl apply -f tcpdump-pod.yaml

View from Storage
<see fig>  

View from Pod
<see fig> 

On completion delete using “kubectl delete -f tcpdump-pod.yaml”. Delete storage account to delete file share.


Step 6: Walk through the Linux Kernel view
============================================================================================================
Use this step to confirm that from Linux Kernel level everything is configured correctly, allowing packets to flow. Also, it is not a Firewall issue since we have Working-App Pods able to be called from the Internet. 

1. Run below command.  This provides higher level privileges on the Node.
kubectl get pods -o wide # gives node name to use below
kubectl-node_shell <Node associated with pods>

2. View faulty apps iptable NAT table and show the KUBE-SERVICES chain, using below command to show the Services Internal and External IPs. 
iptables -t nat -nL KUBE-SERVICES | grep faulty-app

3. Walk down the chain by using below command below, which gives the Endpoints for the Service. Also gives selection probability of the Endpoint. Running this again gives on an Endpoint, gives the Pod IP associated with the Endpoint. 
iptables -t nat -nL <kube-service id>
 

4. Validate the route associated with the Pod network and its eth0 interface.
 

This should validate the route in the route table for the Kubenet networking associated with the AKS.
 

3. Walk through the running containers using below command
 crictl ps | grep faulty 
 
Map this to ‘kubectl get pods -o wide | grep faulty’ to match Pod names.

4. Use the Container ID of one of the faulty app containers. It returns the Process ID.
crictl inspect --output go-template --template '{{.info.pid}}' <container_id>
 

5. Use the Process ID to enter the Pods’ Network namespace using command nsenter. This allows to see Pod IP using linux command ‘ip address show’. Running ‘k get pods’ confirms from the IP that we’re on the right pod.
 

Step 7: Confirm if App is listening. 
============================================================================================================
This step uses lsof (List Open Files) utility using following parameters:
-	The -i parameter is used to display information about network connections. 
-	The -P parameter is used to prevent the conversion of port numbers to port names. When used with the -i parameter, it will display the port number instead of the name.
-	The -n parameter is used to prevent the conversion of network addresses to hostnames. When used with the -i parameter, it will display the IP address instead of the hostname.

Command to use:   nsenter -t <Process ID_Working or Faulty container> -n lsof -i -P -n

From below, working container is listening on ANY IPs i.e., *:4000. 
Faulty container is tied to local loopback or 127.0.0.1 instead of ANY as above. 
 



Step 8: Fixing the issue
============================================================================================================
Issue was in the Docker file where working app was set to bind to 0.0.0.0 or default/Any address, but faulty app was set to bind to a fixed loopback 127.0.0.1 address, as seen below.

Working
<see fig>

Faulty
<see fig>


Step 9: Challenge
============================================================================================================	
From docker-app folder fix the Dockerfile for Faulty app, create a new image, and create new Pod using this image to check if it resolves issue. 


Step 10: Cleanup
============================================================================================================	
k delete ns student
