kubectl delete pod/websvr service/websvr-svc

$kubectl_apply = @"
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
    image: tadeugr/aks-mgmt
    command: ["/bin/bash", "-c"]
    args: ["/start.sh; tail -f /dev/null"]
    ports:
    - containerPort: 8080
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
$kubectl_apply | kubectl apply -f -
