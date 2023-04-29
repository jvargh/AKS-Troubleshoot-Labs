Step 1: Set up the environment.
============================================================================================================
1.	Setup up AKS as outlined in this section.

2.	Create and switch to the newly created namespace.
kubectl create ns student
kubectl config set-context --current --namespace=student
# Verify current namespace
kubectl config view --minify --output 'jsonpath={..namespace}' 

3.	Confirm Container Insights has been set up. This was setup during AKS cluster creation in Lab setup section. 
From AKS blade in portal > Monitor > Insights, confirm metrics collection.

Step 2: Deploy and Monitor apps that spike CPU/Memory utilization
============================================================================================================
1. Assuming namespace ‘student’ still exists, deploy below to turn on the CPU and Memory load
$kubectl_apply = @"
---
# deployment to generate high cpu
apiVersion: apps/v1
kind: Deployment 
metadata:
    name: openssl-loop 
    namespace: student
spec:
    replicas: 3 
    selector: 
      matchLabels:
        app: openssl-loop 
    template: 
      metadata: 
        labels:
          app: openssl-loop 
      spec:
        containers:	
        - args:
          - |
            while true; do
              openssl speed >/dev/null; 
            done 
          command:
          - /bin/bash
          - -c
          image: polinux/stress 
          name: openssl-loop
---
# deployment to generate high memory
apiVersion: apps/v1
kind: Deployment 
metadata:
    name: stress-memory
    namespace: student
spec:
    replicas: 3 
    selector: 
      matchLabels:
        app: stress-memory
    template: 
      metadata: 
        labels:
          app: stress-memory
      spec:
        containers:	
        - image: polinux/stress
          name: stress-memory-container
          resources:
            requests:
              memory: 50Mi          
            limits:
              memory: 50Mi          
          command: ["stress"]
          args: ["--vm", "1", "--vm-bytes", "250M", "--vm-hang", "1"]
---
"@
$kubectl_apply | kubectl apply -f -

‘kubectl get pods’ should have stress-memory pods in ‘CrashLoopBackOff’ and empty-loop pods in ‘Pending’.

2. From Insights tab, validate the CPU/Memory consumption
 
From Nodes tab, see if the top consuming Pods match those deployed.
 

Step 3: View container logs and generate an alert resulting in email
============================================================================================================
1. From Logs, search and select KubeEvents and run the below query to get the Pod results.
 

KubePodInventory
| where TimeGenerated > ago(2h)
| where ContainerStatusReason == "CrashLoopBackOff"
| where Namespace == "student"
| project TimeGenerated, Name, ContainerStatus, ContainerStatusReason

 

2. Create an alert as highlighted above. Confirm Email has been received on next alert. 
•	Set threshold to 0. 
•	In ‘Actions’ create an Action group with Email ID if it doesnt exist. 
•	Set Alert rule name and create Alert.

3. Confirm email receipt on next occurrence of the threshold. 


Step 4: Search Diagnostics logs
============================================================================================================
1. Ensure AzureDiagnostics section is seen in Logs. If available, run below commands to Create and Delete objects. This should generate additional log data.
  
k create ns test-diag
k create deploy deploy-diag-alert --image busybox -n test-diag
k delete deploy deploy-diag-alert -n test-diag

Queries section should lead to the Query finder to get AzureDiagnostics logs if it exists.
 

3. Run the below queries to view log data. Log details are found in log_s. 
Using parse_json() you can drill down to display content of embedded fields, objects, or arrays.

AzureDiagnostics 
| where Category contains "kube-audit"  
| extend log=parse_json(log_s)
| extend verb=log.verb
| extend resource=log.objectRef.resource
| extend ns=log.objectRef.namespace
| extend name=log.objectRef.name
| where resource == "pods"
| where ns=="test-diag"
| project TimeGenerated, verb, resource, name, log_s 

To get graphical view, run below. This gets line chart of all the created pods in ns ‘test-diag’

AzureDiagnostics 
| where Category contains "kube-audit"  
| extend log=parse_json(log_s)
| extend verb=log.verb
| extend resource=log.objectRef.resource
| extend name=log.objectRef.name
| extend ns=log.objectRef.namespace
| where resource == "pods"
| where verb=="create"
| where ns=="test-diag"
| summarize count() by bin(TimeGenerated, 1m), tostring(name), tostring(verb)
| render timechart


Step 5: Challenge
============================================================================================================	
Repeat labs 1 to 5 and use the Logs section above to query and analyze the logs.


Step 6: Final cleanup
============================================================================================================
az group delete -n <aksrg> -y 
