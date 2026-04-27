#!/bin/bash
set -euo pipefail

echo "Rebuilding CKAD exam simulator..."
rm -rf questions run.sh reset-all.sh README.md
mkdir -p questions

cat > run.sh <<'EOF'
#!/bin/bash
set -euo pipefail
QUESTION="${1:-}"
if [ -z "$QUESTION" ]; then
  echo "Usage: ./run.sh q01"
  echo "Available:"
  find questions -maxdepth 1 -type d | sort | sed 's#questions/##'
  exit 1
fi
MATCH="$(find questions -maxdepth 1 -type d -name "${QUESTION}-*" | sort | head -n 1)"
if [ -z "$MATCH" ]; then
  echo "Question not found: $QUESTION"
  exit 1
fi
chmod +x "$MATCH/setup.sh" "$MATCH/reset.sh"
"$MATCH/setup.sh"
echo
echo "======================"
echo "QUESTION"
echo "======================"
cat "$MATCH/question.md"
EOF
chmod +x run.sh

cat > reset-all.sh <<'EOF'
#!/bin/bash
set +e
for d in questions/*; do
  [ -f "$d/reset.sh" ] && chmod +x "$d/reset.sh" && "$d/reset.sh"
done
echo "All labs reset completed."
EOF
chmod +x reset-all.sh

cat > README.md <<'EOF'
# CKAD Exam Simulator

## Fresh install / rebuild
```bash
git clone <repo-url>
cd exam-simulator
chmod +x create-labs.sh
./create-labs.sh
```

## Run any lab
```bash
./run.sh q01
./run.sh q09
./run.sh q19
```

## Reset all labs
```bash
./reset-all.sh
```
EOF

make_q() {
  mkdir -p "questions/$1"
  cat > "questions/$1/question.md"
}

make_setup() {
  cat > "questions/$1/setup.sh"
  chmod +x "questions/$1/setup.sh"
}

make_reset() {
  cat > "questions/$1/reset.sh"
  chmod +x "questions/$1/reset.sh"
}

# Q01
mkdir -p questions/q01-rbac-scraper
cat > questions/q01-rbac-scraper/question.md <<'EOF'
# Q01 - RBAC Scraper

1. Identify required RBAC permissions for Deployment `scraper` in namespace `cute-panda`.
2. Create ServiceAccount `scraper` in namespace `cute-panda`.
3. Check existing Roles and bind the most appropriate Role to ServiceAccount `scraper`.
4. Update Deployment `scraper` to use ServiceAccount `scraper`.
EOF
cat > questions/q01-rbac-scraper/setup.sh <<'EOF'
#!/bin/bash
set -e
NS=cute-panda
kubectl delete ns $NS --ignore-not-found=true >/dev/null 2>&1 || true
kubectl create ns $NS
kubectl create configmap app-config -n $NS --from-literal=mode=exam
cat <<YAML | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {name: pod-reader, namespace: cute-panda}
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get","list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {name: scraper-role, namespace: cute-panda}
rules:
- apiGroups: [""]
  resources: ["pods","configmaps"]
  verbs: ["get","list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {name: secret-admin, namespace: cute-panda}
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["*"]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: scraper, namespace: cute-panda}
spec:
  replicas: 1
  selector: {matchLabels: {app: scraper}}
  template:
    metadata: {labels: {app: scraper}}
    spec:
      containers:
      - name: scraper
        image: bitnami/kubectl:latest
        command: ["/bin/sh","-c"]
        args:
        - |
          while true; do
            echo "Trying to access cluster..."
            kubectl get pods -n cute-panda
            kubectl get configmaps -n cute-panda
            sleep 10
          done
YAML
kubectl rollout status deployment/scraper -n $NS
echo "Start: kubectl logs -n cute-panda deploy/scraper"
EOF
cat > questions/q01-rbac-scraper/reset.sh <<'EOF'
#!/bin/bash
kubectl delete ns cute-panda --ignore-not-found=true
EOF

# Q02
mkdir -p questions/q02-cronjob-pi
cat > questions/q02-cronjob-pi/question.md <<'EOF'
# Q02 - CronJob PI

Create CronJob `ppi`:
- container name `pi`
- image `perl:5`
- command: `["perl","-Mbignum=bpi","-wle","print bpi(2000)"]`
- run every 5 minutes
- retain 2 successful Jobs
- retain 4 failed Jobs
- never restart Pod
- terminate Pod after 8 seconds
EOF
cat > questions/q02-cronjob-pi/setup.sh <<'EOF'
#!/bin/bash
set -e
kubectl delete cronjob ppi --ignore-not-found=true
echo "Default namespace is ready. Create CronJob ppi."
EOF
cat > questions/q02-cronjob-pi/reset.sh <<'EOF'
#!/bin/bash
kubectl delete cronjob ppi --ignore-not-found=true
EOF

# Q03
mkdir -p questions/q03-update-deployment-labels-service
cat > questions/q03-update-deployment-labels-service/question.md <<'EOF'
# Q03 - Update Deployment Labels and Expose Service

1. Update Deployment `ckad00017-deployment` in namespace `ckad00017`:
   - scale to 3 replicas
   - add Pod label `tier=dmz`
2. Create NodePort Service `rover` in namespace `ckad00017` exposing TCP port 81.
EOF
cat > questions/q03-update-deployment-labels-service/setup.sh <<'EOF'
#!/bin/bash
set -e
NS=ckad00017
kubectl delete ns $NS --ignore-not-found=true >/dev/null 2>&1 || true
kubectl create ns $NS
kubectl create deployment ckad00017-deployment --image=nginx:1.16 -n $NS
kubectl rollout status deploy/ckad00017-deployment -n $NS
EOF
cat > questions/q03-update-deployment-labels-service/reset.sh <<'EOF'
#!/bin/bash
kubectl delete ns ckad00017 --ignore-not-found=true
EOF

# Q04
mkdir -p questions/q04-container-security-context
cat > questions/q04-container-security-context/question.md <<'EOF'
# Q04 - Container Security Context

Modify Deployment `broker-deployment` in namespace `quetzal` so container:
- runs as user `30000`
- disables privilege escalation
- adds capability `NET_BIND_SERVICE`

Manifest path: `/ckad/daring-moccasin/broker-deployment.yaml`
EOF
cat > questions/q04-container-security-context/setup.sh <<'EOF'
#!/bin/bash
set -e
NS=quetzal
kubectl delete ns $NS --ignore-not-found=true >/dev/null 2>&1 || true
kubectl create ns $NS
mkdir -p /ckad/daring-moccasin
cat > /ckad/daring-moccasin/broker-deployment.yaml <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: broker-deployment
  namespace: quetzal
spec:
  replicas: 1
  selector:
    matchLabels: {app: broker}
  template:
    metadata:
      labels: {app: broker}
    spec:
      containers:
      - name: broker
        image: nginx:1.16
YAML
kubectl apply -f /ckad/daring-moccasin/broker-deployment.yaml
kubectl rollout status deploy/broker-deployment -n $NS
EOF
cat > questions/q04-container-security-context/reset.sh <<'EOF'
#!/bin/bash
kubectl delete ns quetzal --ignore-not-found=true
rm -rf /ckad/daring-moccasin
EOF

# Q05
mkdir -p questions/q05-fix-api-deprecation
cat > questions/q05-fix-api-deprecation/question.md <<'EOF'
# Q05 - Run Legacy Applications

1. Fix API deprecation issues in `/ckad/credible-mite/www.yaml`.
2. Deploy the application in namespace `garfish`.
EOF
cat > questions/q05-fix-api-deprecation/setup.sh <<'EOF'
#!/bin/bash
set -e
NS=garfish
kubectl delete ns $NS --ignore-not-found=true >/dev/null 2>&1 || true
kubectl create ns $NS
mkdir -p /ckad/credible-mite
cat > /ckad/credible-mite/www.yaml <<YAML
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: www
  namespace: garfish
spec:
  replicas: 2
  selector:
    matchLabels: {app: www}
  template:
    metadata:
      labels: {app: www}
    spec:
      containers:
      - name: www
        image: nginx:1.16
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: www
  namespace: garfish
spec:
  selector: {app: www}
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: www
  namespace: garfish
spec:
  backend:
    serviceName: www
    servicePort: 80
YAML
echo "Legacy manifest ready: /ckad/credible-mite/www.yaml"
EOF
cat > questions/q05-fix-api-deprecation/reset.sh <<'EOF'
#!/bin/bash
kubectl delete ns garfish --ignore-not-found=true
rm -rf /ckad/credible-mite
EOF

# Q06
mkdir -p questions/q06-limit-cpu-memory-requests
cat > questions/q06-limit-cpu-memory-requests/question.md <<'EOF'
# Q06 - Limit CPU and Memory Requests

Modify Deployment `nginx-resources` in namespace `pod-resources`:
- request CPU `20m`
- request memory `26Mi`
- set CPU and memory limits to twice their requests
- ensure total Pod resources match namespace limits
EOF
cat > questions/q06-limit-cpu-memory-requests/setup.sh <<'EOF'
#!/bin/bash
set -e
NS=pod-resources
kubectl delete ns $NS --ignore-not-found=true >/dev/null 2>&1 || true
kubectl create ns $NS
cat <<YAML | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: quota
  namespace: pod-resources
spec:
  hard:
    requests.cpu: "60m"
    requests.memory: "78Mi"
    limits.cpu: "120m"
    limits.memory: "156Mi"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-resources
  namespace: pod-resources
spec:
  replicas: 3
  selector:
    matchLabels: {app: nginx-resources}
  template:
    metadata:
      labels: {app: nginx-resources}
    spec:
      containers:
      - name: nginx
        image: nginx:1.16
YAML
EOF
cat > questions/q06-limit-cpu-memory-requests/reset.sh <<'EOF'
#!/bin/bash
kubectl delete ns pod-resources --ignore-not-found=true
EOF

# Q07
mkdir -p questions/q07-readiness-probe
cat > questions/q07-readiness-probe/question.md <<'EOF'
# Q07 - Readiness Probe

Modify Deployment `probe-http` in namespace `prod27`:
- readinessProbe path `/healthz/return200`
- initialDelaySeconds `15`
- periodSeconds `20`
EOF
cat > questions/q07-readiness-probe/setup.sh <<'EOF'
#!/bin/bash
set -e
NS=prod27
kubectl delete ns $NS --ignore-not-found=true >/dev/null 2>&1 || true
kubectl create ns $NS
cat <<YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: probe-http
  namespace: prod27
spec:
  replicas: 1
  selector:
    matchLabels: {app: probe-http}
  template:
    metadata:
      labels: {app: probe-http}
    spec:
      containers:
      - name: web
        image: nginx:1.16
        ports:
        - containerPort: 80
YAML
kubectl rollout status deploy/probe-http -n $NS
EOF
cat > questions/q07-readiness-probe/reset.sh <<'EOF'
#!/bin/bash
kubectl delete ns prod27 --ignore-not-found=true
EOF

# Q08
mkdir -p questions/q08-upgrade-rollback
cat > questions/q08-upgrade-rollback/question.md <<'EOF'
# Q08 - Upgrade and Rollback

1. Update Deployment `webapp` in namespace `ckad00015`:
   - maxSurge `5%`
   - maxUnavailable `5%`
2. Update image to `lfccncf/nginx:1.13.7`.
3. Roll back Deployment `webapp` to previous version.
EOF
cat > questions/q08-upgrade-rollback/setup.sh <<'EOF'
#!/bin/bash
set -e
NS=ckad00015
kubectl delete ns $NS --ignore-not-found=true >/dev/null 2>&1 || true
kubectl create ns $NS
kubectl create deployment webapp --image=nginx:1.16 -n $NS
kubectl scale deploy/webapp --replicas=4 -n $NS
kubectl rollout status deploy/webapp -n $NS
EOF
cat > questions/q08-upgrade-rollback/reset.sh <<'EOF'
#!/bin/bash
kubectl delete ns ckad00015 --ignore-not-found=true
EOF

# Q09
mkdir -p questions/q09-create-ingress
cat > questions/q09-create-ingress/question.md <<'EOF'
# Q09 - Create Ingress

Create Ingress `web-app-ingress`:
- namespace `external`
- host `external.sterling-bengal.local`
- path `/` routes to Service `web-app`
- service port `8080`

Test: `curl -L external.sterling-bengal.local`
EOF
cat > questions/q09-create-ingress/setup.sh <<'EOF'
#!/bin/bash
set -e
NS=external
kubectl delete ns $NS --ignore-not-found=true >/dev/null 2>&1 || true
kubectl create ns $NS
kubectl create deployment web-app --image=nginx:1.16 -n $NS
kubectl expose deployment web-app --port=8080 --target-port=80 -n $NS
grep -q "external.sterling-bengal.local" /etc/hosts || echo "127.0.0.1 external.sterling-bengal.local" >> /etc/hosts || true
kubectl rollout status deploy/web-app -n $NS
EOF
cat > questions/q09-create-ingress/reset.sh <<'EOF'
#!/bin/bash
kubectl delete ns external --ignore-not-found=true
EOF

# Q10
mkdir -p questions/q10-rbac-authorization
cat > questions/q10-rbac-authorization/question.md <<'EOF'
# Q10 - RBAC Authorization

1. View logs for Deployment `honeybee-deployment` in namespace `gorilla`.
2. Fix RBAC so Pod can list `serviceaccounts`.

Manifest path: `/ckad/prompt-escargot/honeybee-deployment.yaml`
EOF
cat > questions/q10-rbac-authorization/setup.sh <<'EOF'
#!/bin/bash
set -e
NS=gorilla
kubectl delete ns $NS --ignore-not-found=true >/dev/null 2>&1 || true
kubectl create ns $NS
mkdir -p /ckad/prompt-escargot
cat > /ckad/prompt-escargot/honeybee-deployment.yaml <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: honeybee-deployment
  namespace: gorilla
spec:
  replicas: 1
  selector:
    matchLabels: {app: honeybee}
  template:
    metadata:
      labels: {app: honeybee}
    spec:
      containers:
      - name: honeybee
        image: bitnami/kubectl:latest
        command: ["/bin/sh","-c"]
        args:
        - |
          while true; do
            kubectl get serviceaccounts -n gorilla
            sleep 10
          done
YAML
kubectl apply -f /ckad/prompt-escargot/honeybee-deployment.yaml
kubectl rollout status deploy/honeybee-deployment -n $NS
echo "Start: kubectl logs -n gorilla deploy/honeybee-deployment"
EOF
cat > questions/q10-rbac-authorization/reset.sh <<'EOF'
#!/bin/bash
kubectl delete ns gorilla --ignore-not-found=true
rm -rf /ckad/prompt-escargot
EOF

# Q11
mkdir -p questions/q11-dockerfile-build-export
cat > questions/q11-dockerfile-build-export/question.md <<'EOF'
# Q11 - Dockerfile Build Export

1. Build image `centos:8.2` using `/ckad/DF/Dockerfile`.
2. Export image in OCI/tar format to `/ckad/DF/centos-8.2.tar`.
3. Do not push or run the image.
EOF
cat > questions/q11-dockerfile-build-export/setup.sh <<'EOF'
#!/bin/bash
set -e
mkdir -p /ckad/DF
cat > /ckad/DF/Dockerfile <<'YAML'
FROM busybox:1.36
CMD ["sh", "-c", "echo CKAD image build practice && sleep 3600"]
YAML
rm -f /ckad/DF/centos-8.2.tar
echo "Dockerfile ready: /ckad/DF/Dockerfile"
EOF
cat > questions/q11-dockerfile-build-export/reset.sh <<'EOF'
#!/bin/bash
rm -rf /ckad/DF
EOF

# Q12
mkdir -p questions/q12-secret-postgres
cat > questions/q12-secret-postgres/question.md <<'EOF'
# Q12 - Secret Postgres

1. Create Secret `postgres` in namespace `relaxed-shark` containing the current hardcoded env values from Deployment `postgres`:
   - `username`
   - `database`
   - `password`
2. Modify Deployment `postgres` so env vars use values from the Secret.
EOF
cat > questions/q12-secret-postgres/setup.sh <<'EOF'
#!/bin/bash
set -e
NS=relaxed-shark
kubectl delete ns $NS --ignore-not-found=true >/dev/null 2>&1 || true
kubectl create ns $NS
cat <<YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: relaxed-shark
spec:
  replicas: 1
  selector:
    matchLabels: {app: postgres}
  template:
    metadata:
      labels: {app: postgres}
    spec:
      containers:
      - name: postgres
        image: postgres:13
        env:
        - name: POSTGRES_USER
          value: appuser
        - name: POSTGRES_DB
          value: appdb
        - name: POSTGRES_PASSWORD
          value: supersecret
YAML
EOF
cat > questions/q12-secret-postgres/reset.sh <<'EOF'
#!/bin/bash
kubectl delete ns relaxed-shark --ignore-not-found=true
EOF

# Q13
mkdir -p questions/q13-ingress-troubleshooting
cat > questions/q13-ingress-troubleshooting/question.md <<'EOF'
# Q13 - Ingress Troubleshooting

Fix Ingress `nginx-ingress-test` in namespace `ingress-ckad`.
- Deployment `nginx-dm` is correct. Do NOT modify it.
- Fix Service/Ingress issue.
- Test: `curl -L http://ckad-ingress-test.local`
EOF
cat > questions/q13-ingress-troubleshooting/setup.sh <<'EOF'
#!/bin/bash
set -e
NS=ingress-ckad
kubectl delete ns $NS --ignore-not-found=true >/dev/null 2>&1 || true
kubectl create ns $NS
mkdir -p /ckad/CKAD202206
cat <<YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-dm
  namespace: ingress-ckad
spec:
  replicas: 1
  selector:
    matchLabels: {app: nginx-dm}
  template:
    metadata:
      labels: {app: nginx-dm}
    spec:
      containers:
      - name: nginx
        image: nginx:1.16
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-svc
  namespace: ingress-ckad
spec:
  selector:
    app: wrong-label
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress-test
  namespace: ingress-ckad
spec:
  rules:
  - host: ckad-ingress-test.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-svc
            port:
              number: 80
YAML
grep -q "ckad-ingress-test.local" /etc/hosts || echo "127.0.0.1 ckad-ingress-test.local" >> /etc/hosts || true
kubectl rollout status deploy/nginx-dm -n $NS
EOF
cat > questions/q13-ingress-troubleshooting/reset.sh <<'EOF'
#!/bin/bash
kubectl delete ns ingress-ckad --ignore-not-found=true
rm -rf /ckad/CKAD202206
EOF

# Q14
mkdir -p questions/q14-networkpolicy-existing
cat > questions/q14-networkpolicy-existing/question.md <<'EOF'
# Q14 - NetworkPolicy Existing

Update Pod `ckad00018-newpod` in namespace `ckad00018`:
- allow traffic only with Pods `front` and `db`
- use existing NetworkPolicies only
- do NOT create, modify, or delete NetworkPolicies
EOF
cat > questions/q14-networkpolicy-existing/setup.sh <<'EOF'
#!/bin/bash
set -e
NS=ckad00018
kubectl delete ns $NS --ignore-not-found=true >/dev/null 2>&1 || true
kubectl create ns $NS
cat <<YAML | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: front
  namespace: ckad00018
  labels: {role: front}
spec:
  containers:
  - name: nginx
    image: nginx:1.16
---
apiVersion: v1
kind: Pod
metadata:
  name: db
  namespace: ckad00018
  labels: {role: db}
spec:
  containers:
  - name: nginx
    image: nginx:1.16
---
apiVersion: v1
kind: Pod
metadata:
  name: ckad00018-newpod
  namespace: ckad00018
  labels: {role: open}
spec:
  containers:
  - name: nginx
    image: nginx:1.16
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-front-db
  namespace: ckad00018
spec:
  podSelector:
    matchLabels: {access: restricted}
  policyTypes: ["Ingress"]
  ingress:
  - from:
    - podSelector:
        matchLabels: {role: front}
    - podSelector:
        matchLabels: {role: db}
YAML
EOF
cat > questions/q14-networkpolicy-existing/reset.sh <<'EOF'
#!/bin/bash
kubectl delete ns ckad00018 --ignore-not-found=true
EOF

# Q15
mkdir -p questions/q15-memory-request-limit
cat > questions/q15-memory-request-limit/question.md <<'EOF'
# Q15 - Memory Request and Limit

Fix Deployment `nosql` in namespace `haddock`:
- request `15Mi` memory
- set memory limit to half of namespace maximum memory capacity

Manifest path: `/ckad/chief-cardinal/nosql.yaml`
EOF
cat > questions/q15-memory-request-limit/setup.sh <<'EOF'
#!/bin/bash
set -e
NS=haddock
kubectl delete ns $NS --ignore-not-found=true >/dev/null 2>&1 || true
kubectl create ns $NS
mkdir -p /ckad/chief-cardinal
cat <<YAML | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: haddock-limitrange
  namespace: haddock
spec:
  limits:
  - type: Container
    max:
      memory: 128Mi
    min:
      memory: 10Mi
YAML
cat > /ckad/chief-cardinal/nosql.yaml <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nosql
  namespace: haddock
spec:
  replicas: 2
  selector:
    matchLabels: {app: nosql}
  template:
    metadata:
      labels: {app: nosql}
    spec:
      containers:
      - name: nosql
        image: nginx:1.16
        resources:
          requests:
            memory: 200Mi
          limits:
            memory: 256Mi
YAML
kubectl apply -f /ckad/chief-cardinal/nosql.yaml || true
echo "Manifest ready: /ckad/chief-cardinal/nosql.yaml"
EOF
cat > questions/q15-memory-request-limit/reset.sh <<'EOF'
#!/bin/bash
kubectl delete ns haddock --ignore-not-found=true
rm -rf /ckad/chief-cardinal
EOF

# Q16
mkdir -p questions/q16-modify-container-name-image
cat > questions/q16-modify-container-name-image/question.md <<'EOF'
# Q16 - Modify Container Name and Image

Update existing Deployment `busybox` in namespace `rapid-goat`:
- change container name to `musl`
- change image to `busybox:musl`
- do NOT delete Deployment
EOF
cat > questions/q16-modify-container-name-image/setup.sh <<'EOF'
#!/bin/bash
set -e
NS=rapid-goat
kubectl delete ns $NS --ignore-not-found=true >/dev/null 2>&1 || true
kubectl create ns $NS
cat <<YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: busybox
  namespace: rapid-goat
spec:
  replicas: 1
  selector:
    matchLabels: {app: busybox}
  template:
    metadata:
      labels: {app: busybox}
    spec:
      containers:
      - name: busybox
        image: busybox:1.36
        command: ["sh","-c","sleep 3600"]
YAML
EOF
cat > questions/q16-modify-container-name-image/reset.sh <<'EOF'
#!/bin/bash
kubectl delete ns rapid-goat --ignore-not-found=true
EOF

# Q17
mkdir -p questions/q17-canary-deployment
cat > questions/q17-canary-deployment/question.md <<'EOF'
# Q17 - Canary Deployment

Service `chipmunk-service` in namespace `goshawk` points to 5 Pods from Deployment `current-chipmunk-deployment`.

1. Create identical Deployment `canary-chipmunk-deployment`.
2. Modify Deployments so:
   - max Pods in namespace `goshawk` is 10
   - 40% traffic to `chipmunk-service` routes to canary Pods

Manifest path: `/ckad/goshawk/current-chipmunk-deployment.yaml`
EOF
cat > questions/q17-canary-deployment/setup.sh <<'EOF'
#!/bin/bash
set -e
NS=goshawk
kubectl delete ns $NS --ignore-not-found=true >/dev/null 2>&1 || true
kubectl create ns $NS
mkdir -p /ckad/goshawk
cat > /ckad/goshawk/current-chipmunk-deployment.yaml <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: current-chipmunk-deployment
  namespace: goshawk
spec:
  replicas: 5
  selector:
    matchLabels:
      app: chipmunk
      track: current
  template:
    metadata:
      labels:
        app: chipmunk
        track: current
    spec:
      containers:
      - name: chipmunk
        image: nginx:1.16
        ports:
        - containerPort: 80
YAML
kubectl apply -f /ckad/goshawk/current-chipmunk-deployment.yaml
cat <<YAML | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: chipmunk-service
  namespace: goshawk
spec:
  selector:
    app: chipmunk
  ports:
  - port: 80
    targetPort: 80
YAML
kubectl rollout status deploy/current-chipmunk-deployment -n $NS
EOF
cat > questions/q17-canary-deployment/reset.sh <<'EOF'
#!/bin/bash
kubectl delete ns goshawk --ignore-not-found=true
rm -rf /ckad/goshawk
EOF

# Q18
mkdir -p questions/q18-secret-env
cat > questions/q18-secret-env/question.md <<'EOF'
# Q18 - Secret Env

1. Create Secret `another-secret` in namespace `default`:
   - `key1=value2`
2. Create Pod `nginx-secret` in namespace `default`:
   - image `nginx:1.16`
   - env var `COOL_VARIABLE` from Secret key `key1`
EOF
cat > questions/q18-secret-env/setup.sh <<'EOF'
#!/bin/bash
set -e
kubectl delete pod nginx-secret --ignore-not-found=true
kubectl delete secret another-secret --ignore-not-found=true
echo "Default namespace ready."
EOF
cat > questions/q18-secret-env/reset.sh <<'EOF'
#!/bin/bash
kubectl delete pod nginx-secret --ignore-not-found=true
kubectl delete secret another-secret --ignore-not-found=true
EOF

# Q19
mkdir -p questions/q19-deployment-env-var
cat > questions/q19-deployment-env-var/question.md <<'EOF'
# Q19 - Deployment Env Variable

Create Deployment `api` in namespace `ckad00014`:
- replicas `6`
- image `nginx:1.16`
- env `NGINX_PORT=8000`
- expose container port `80`
EOF
cat > questions/q19-deployment-env-var/setup.sh <<'EOF'
#!/bin/bash
set -e
NS=ckad00014
kubectl delete ns $NS --ignore-not-found=true >/dev/null 2>&1 || true
kubectl create ns $NS
echo "Namespace ckad00014 ready."
EOF
cat > questions/q19-deployment-env-var/reset.sh <<'EOF'
#!/bin/bash
kubectl delete ns ckad00014 --ignore-not-found=true
EOF

chmod +x questions/*/*.sh

echo
echo "CKAD labs rebuilt successfully."
echo "Run examples:"
echo "  ./run.sh q01"
echo "  ./run.sh q09"
echo "  ./run.sh q19"
