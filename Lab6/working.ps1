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