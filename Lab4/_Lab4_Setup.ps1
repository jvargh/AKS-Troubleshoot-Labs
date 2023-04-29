Step 1: Set up the environment.
============================================================================================================
1.	Setup up AKS as outlined in this section.

2.	Create and switch to the newly created namespace
kubectl create ns student
kubectl config set-context --current --namespace=student
# Verify current namespace
kubectl config view --minify --output 'jsonpath={..namespace}' 

3.	Change directory to Lab4 > cd Lab4

4.	Run the following in Powershell. 

cd Lab4; .\working.ps1

Specification in working.ps1 is seen below. 
This sets up the Web Server Pod and Service of type Load Balancer. Theres an External-IP that points to the web server making it accessible from outside cluster. 

$kubectl_apply = @"
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-html
data:
  index.html: |
    ...
    Hello from Websvr
    ...
---
apiVersion: v1
kind: Pod
metadata:
  name: websvr
  labels:
    app: websvr
spec:
  containers:
  - name: websvr
    image: nginx:latest
    ports:
    - containerPort: 8080
    volumeMounts:
    - name: webcontent
      mountPath: /usr/share/nginx/html/index.html
      subPath: index.html
  volumes:
    - name: webcontent
      configMap:
        name: nginx-html
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: websvr
  name: websvr-svc
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 8080
  selector:
    app: websvr
  type: LoadBalancer
"@
$kubectl_apply | kubectl apply -f –

# svc above similar to: k expose pod nginx --name= websvr-svc --port=80 --target-port=8080 --type LoadBalancer

5.	Ensure Websvr is Running. Ensure LB service has an External IP assigned. 
kubectl get po -l app=websvr -o wide
kubectl get svc -l app=websvr -o wide
kubectl get node -o wide
 

Step 2: Create and use a helper pod to troubleshoot.
============================================================================================================
1. Create a helper pod and install the required utilities.

kubectl run helper-pod  --image=nginx
k exec -it helper-pod -- bash

# Install below in bash shell
apt-get update -y
apt-get install -y nmap
exit

2. Make a note of EXTERNAL_IP, CLUSTER_IP, WebsvrPod_IP, Helper_Pod_IP, and Node name. 

$EXTERNAL_IP=$(kubectl get svc websvr-svc -o jsonpath="{.status.loadBalancer.ingress[*].ip}")
$CLUSTER_IP=$(kubectl get svc websvr-svc -o jsonpath="{.spec.clusterIP}")
$WebsvrPod_IP=$(kubectl get pod websvr -o jsonpath="{.status.podIP}")
$Helper_Pod_IP=$(kubectl get pod helper-pod -o jsonpath="{.status.podIP}")
$Node_Name= $(kubectl get node -o jsonpath="{.items[*].status.addresses[?(@.type=='Hostname')].address}")

echo $EXTERNAL_IP   # 52.154.210.193 only in this instance	
echo $CLUSTER_IP    # 10.0.43.186. only in this instance
echo $WebsvrPod_IP  # 10.244.0.24. only in this instance
echo $Helper_Pod_IP # 10.244.0.25. only in this instance
echo $Node_Name     # aks-nodepool1-96643998-vmss000000. only in this instance

Step 3: Verify connectivity to Web Server.
============================================================================================================
1. Check connectivity by attempting to reach the web server using Public IP. This check should fail.

kubectl exec -it helper-pod -- curl -m 7 ${EXTERNAL_IP}:80
 

Step 4: Troubleshoot networking
============================================================================================================
Below is the networking path we need to analyze.
 

1. Do a port scan using ‘nmap’ on Websvr-Service, EXTERNAL_IP, and WebsvrPod_IP. 

kubectl exec -it helper-pod -- nmap -F websvr-svc
kubectl exec -it helper-pod -- nmap -F $EXTERNAL_IP
kubectl exec -it helper-pod -- nmap -F $WebsvrPod_IP
kubectl exec -it helper-pod -- nmap -F $CLUSTER_IP

In cases of External and Service (Cluster IP), we see port 80 is in closed state and refuses to accept incoming connections. However, websvr-pod has port 80 open.
Since curl on the Pod IP port 80 works, this confirms Web Server is running and Pod configuration is valid.

Step 5: Run network capture from Node running Web Server Pod and Helper Pod.
============================================================================================================
Get below which will be needed for tcpdump
echo $Helper_Pod_IP
10.244.0.25 # this is only an example.
echo $WebsvrPod_IP
10.244.0.24 # this is only an example.
echo $Node_Name
aks-nodepool1-96643998-vmss000000 # this is only an example.

1. Open a new terminal. Running below creates a debug Pod on Node running Web Server Pod. 
Install tcpdump on the debug Pod as shown below. Aside from Node-Name above, you can also use ‘kubectl get nodes’

kubectl debug node/<Node-Name> -it --image=mcr.microsoft.com/dotnet/runtime-deps:6.0

# Install below
apt-get update -y; apt-get install tcpdump -y

2. From Step 1, run tcpdump using SRC IP (Helper pod in Step 3) and DST IP (Web server pod in Step 1)
Order is important. Src=Helper-Pod and Dst=Websvr-Pod
tcpdump -en -i any src <HELPER_POD_IP> and dst <WEBSVR_POD_IP>

 
3. On the original terminal. Generate traffic to capture output by running below from Helper pod terminal. 
kubectl exec -it helper-pod -- curl websvr-svc
 

Based on the trace provided, the helper-pods IP address establishes a connection with websvr-svc, utilizing the Cluster IP address. 
This subsequently redirects the connection to the IP address of Websvr. However, the connection is made using port number 8080.
Looking at the Web Server Pod YAML, it has containerPort set to 8080.
Service definition targetPort also set to 8080. 

From port scan earlier, we found that the Websvr application was listening on port 80. 
This means the Websvr-svc target port configuration is incorrect and the configuration of the Websvr container Port does not make any difference.

Step 6: Fixing the issue.
============================================================================================================
1. To fix this issue, we must update websvr-svc targetPort and set it to 80. 

Use ‘kubectl edit svc websvr-svc’ to update targetPort to 80.
Before					
<see fig> 
After
<see fig>   

Use ‘kubectl get ep’ to confirm its pointing to port 80 on web server Pod.

2. Once done, the web server should be reachable over the External IP as well as the internal service Cluster IP.
kubectl exec -it helper-pod -- nmap -F websvr-svc
kubectl exec -it helper-pod -- nmap -F $EXTERNAL_IP
kubectl exec -it helper-pod -- nmap -F $CLUSTER_IP
 

kubectl exec -it helper-pod -- curl websvr-svc
kubectl exec -it helper-pod -- curl $EXTERNAL_IP
 

The traffic flow between the external client and the application pods is managed by the targetPort and containerPort fields of the service definition.

The targetPort is the port used by the Service to route traffic to the Application pods. The containerPort is the port on which the application listens in the pods.

When a client sends a request to the external IP address of the LoadBalancer service, the request is directed to the targetPort on the pods. 
The service routes the traffic to the correct pod based on the rules defined in the services selector. The traffic then reaches the container listening on the containerPort and is processed by the application.  
In this way, the targetPort and containerPort fields ensure that external traffic is correctly mapped to the correct pods and processed by the correct container within the pod.

Step 7: Challenge
============================================================================================================
In the above example, image nginx only listens on port 80. Test this web server image tadeugr/aks-mgmt, which listens on 80 and 8080 using Pod sample as shown. 
Hence if you edit Service, targetPort to 80 and 8080 both ports should work. 

Run 
kubectl delete pod/websvr service/websvr-svc
cd Lab4; .\working2.ps1

# below should work now, even though container and targetPort=8080, since app listens on 8080 and 80 
kubectl exec -it helper-pod -- curl websvr-svc

# confirmed that app listens on both 80/8080 by below. 
kubectl get pod -o wide # get pod-ip
kubectl exec -it helper-pod -- curl <pod-ip>:8080
kubectl exec -it helper-pod -- curl <pod-ip>:80

# what this new image looks like in working2.ps1
apiVersion: v1
kind: Pod
metadata:
  name: websvr
  labels:
    app: websvr
spec:
  containers:
  - name: websvr
    image: tadeugr/aks-mgmt
	command: ["/bin/bash", "-c"]
	args: ["/start.sh; tail -f /dev/null"]
    ports:
    - containerPort: 8080

Step 8: Cleanup
============================================================================================================
kubectl delete pod/helper-pod pod/websvr service/websvr-svc pod/node-debugger-aks-systempool-24510098-vmss000003-lqrvr
