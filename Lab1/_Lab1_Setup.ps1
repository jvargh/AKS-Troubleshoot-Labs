Step 1: Set up the environment
============================================================================================================ 
1.	Setup up AKS as outlined in this section.
2.	Create and switch to the newly created namespace
kubectl create ns student
kubectl config set-context --current --namespace=student

# Verify current namespace
kubectl config view --minify --output 'jsonpath={..namespace}' 
3. Change directory to Lab1 > cd Lab1

Step 2: Create two deployments and respective services
============================================================================================================  
1.	Create a deployment nginx-1 with a simple nginx image:
kubectl create deployment nginx-1 --image=nginx

2.	Expose the deployment as a ClusterIP service:
k expose deployment nginx-1 --name nginx-1-svc --port=80 --target-port=80 --type=ClusterIP

3.	Repeat the above steps to create another deployment and a service:
kubectl create deployment nginx-2 --image=nginx
k expose deployment nginx-2 --name nginx-2-svc --port=80 --target-port=80 --type=ClusterIP

4.	Confirm deployment and service functional. Pods should be running and services listening on Port 80.  
kubectl get all

Step 3: Verify that you can access both services from within the cluster by using Cluster IP addresses
============================================================================================================
# Services returned: nginx-1-svc for pod/nginx-1, nginx-2-svc for pod/nginx-2
kubectl get svc

# Get the value of <nginx-1-pod> and <nginx-2-pod>
kubectl get pods

# below should present HTML page from nginx-2
kubectl exec -it <nginx-1-pod> -- curl nginx-2-svc:80	

# below should present HTML page from nginx-1
kubectl exec -it <nginx-2-pod> -- curl nginx-1-svc:80

# check endpoints for the services
kubectl get ep

Step 4: Backup existing deployments
============================================================================================================
1.	Backup the deployment associated with nginx-2 deployment:
kubectl get deployment.apps/nginx-2 -o yaml > nginx-2-dep.yaml
 
2.	Backup the service associated with nginx-2 service:
kubectl get service/nginx-2-svc -o yaml > nginx-2-svc.yaml

Step 5: Simulate service down
============================================================================================================
1.	Delete nginx-2 deployment 
kubectl delete -f nginx-2-dep.yaml

2.	Apply the broken.yaml deployment file found in Lab1 folder
kubectl apply -f broken.yaml

3.	Confirm all pods are running 
kubectl get all
 
Step 6: Troubleshoot the issue
============================================================================================================
1.	Check the health of the nodes in the cluster to see if there is a node issue
kubectl get nodes

2.	Verify that you can no longer access nginx-2-svc from within the cluster
kubectl exec -it <nginx-1-pod> -- curl nginx-2-svc:80 
# msg Failed to connect to nginx-2-svc port 80: Connection refused

3.	Verify that you can access nginx-1-svc from within the cluster
kubectl exec -it <nginx-1-pod> -- curl nginx-1-svc:80 
# displays HTML page

3.	Check the Endpoints using below cmd. Verify that the right Endpoints line up with their Services. There should be at least 1 Pod associated with a service, but none seem to exist for nginx-2 service but nginx-2 service/pod association is fine.
kubectl get ep

4.	Check label selector used by the Service experiencing issue, using below command. 
    'kubectl describe service <service-name>'
Ensure that it matches the label selector used by its corresponding Deployment using below command
    'kubectl describe deployment <deployment_name>'



Use 'k get svc' and 'k get deployment' to get service and deployment names.

5.	Using the Service label selector from Step3, check that the Pods selected by the Service match the Pods created by the Deployment using the following command: 
    kubectl get pods --selector=<selector_used_by_service>. 

If no results are returned then there must be a label selector mismatch. 
From below selector used by deployment returns pods but not selector used by service.
 

6.	Check service and pod logs and ensure HTTP traffic is seen. Compare nginx-1 pod  and service logs with nginx-2. Latter seems empty suggesting no incoming traffic.
k logs pod/<nginx-2>
k logs pod/<nginx-1>

k logs svc/<nginx-2>
k logs svc/<nginx-1>

Step 7: Restore connectivity
============================================================================================================
1.	Check the label selector the Service is associated with and get associated pods:
# Get label
kubectl describe service nginx-2-svc

# use label from service to get pods
# indicates no resources found or no pods available
kubectl describe pods -l app=nginx-2	

2.	Update deployment and apply changes.

kubectl delete -f nginx-2-dep.yaml

In broken.yaml,
•	Update labels > app: nginx-02, to app: nginx-2
 

kubectl apply -f broken.yaml # or apply dep-nginx-2.yaml

k describe pod <nginx-2>
k get ep # nginx-2 svc should have pods unlike before


3.	Verify that you can now access the newly created service from within the cluster:

# Should return HTML page from nginx-2-svc
kubectl exec -it <nginx-1 pod> -- curl nginx-2-svc:80	

# Confirm from logs
k logs pod/<nginx-2>	


Step 8: Using Custom Domain Names
============================================================================================================
Currently Services in your namespace 'student' will resolve using <service name>.<namespace>.svc.cluster.local. 
Below command should return web page.

k exec -it <nginx-1 pod> -- curl nginx-2-svc.student.svc.cluster.local

1. Apply broken2.yaml in Lab1 folder and restart coredns
kubectl apply -f broken2.yaml
kubectl delete pods -l=k8s-app=kube-dns -n kube-system
# Monitor to ensure pods are running
kubectl get pods -l=k8s-app=kube-dns -n kube-system

2. Validate if DNS resolution works and it should fail wit 'curl: (6) Could not resolve host:'
k exec -it <nginx-1 pod> -- curl nginx-2-svc.student.svc.cluster.local

3. Check the DNS configuration files in kube-system which shows the configmaps, as below. 
k get cm -A -n kube-system | grep dns

4. Describe each of the ones found above and look for inconsistencies
k describe cm coredns -n kube-system
k describe cm coredns-autoscaler -n kube-system
k describe cm coredns-custom -n kube-system

5. Since the custom DNS file holds the breaking changes, either edit coredns-custom (to remove data section) or delete configmap and restart DNS.  
k delete cm coredns-custom -n kube-system
kubectl delete pods -l=k8s-app=kube-dns -n kube-system
# Monitor to ensure pods are running
kubectl get pods -l=k8s-app=kube-dns -n kube-system

6. Confirm DNS resolution now works as before.
k exec -it <nginx-1 pod> -- curl nginx-2-svc.student.svc.cluster.local


Challenge lab: Resolve aks.com as below 
k exec -it <nginx-1 pod> -- curl nginx-2-svc.aks.com  

# Solution
k apply -f working2.yaml
kubectl delete pods -l=k8s-app=kube-dns -n kube-system
# Monitor to ensure pods are running
kubectl get pods -l=k8s-app=kube-dns -n kube-system

# Confirm working > k exec -it <nginx-1 pod> -- curl nginx-2-svc.aks.com  
# Bring back to default
k delete cm coredns-custom -n kube-system
kubectl delete pods -l=k8s-app=kube-dns -n kube-system
# Monitor to ensure pods are running
kubectl get pods -l=k8s-app=kube-dns -n kube-system

Step 10: Cleanup
============================================================================================================
k delete deployment/nginx-1 deployment/nginx-2 service/nginx-1-svc service/nginx-2-svc
or just delete namespace > 
k delete ns student
