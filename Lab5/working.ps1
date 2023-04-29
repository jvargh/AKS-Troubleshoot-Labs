$kubectl_apply = @"
---
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
"@
$kubectl_apply | kubectl apply -f -
