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
$kubectl_apply | kubectl apply -f -
