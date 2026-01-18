#!/usr/bin/env bash
set -euo pipefail

ROOT="auth-service-gitops"

# Create directory structure
mkdir -p "${ROOT}/base"
mkdir -p "${ROOT}/overlays/dev"
mkdir -p "${ROOT}/overlays/uat"
mkdir -p "${ROOT}/overlays/prod"

# -------------------------
# Base manifests (shared)
# -------------------------

cat > "${ROOT}/base/deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: auth-service
  labels:
    app: auth-service
spec:
  replicas: 2
  selector:
    matchLabels:
      app: auth-service
  template:
    metadata:
      labels:
        app: auth-service
    spec:
      containers:
        - name: auth-service
          image: ghcr.io/your-org/auth-service:latest
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 8080
          env:
            - name: LOG_LEVEL
              value: "info"
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "250m"
              memory: "256Mi"
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /health/live
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 20
YAML

cat > "${ROOT}/base/service.yaml" <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: auth-service
  labels:
    app: auth-service
spec:
  type: ClusterIP
  selector:
    app: auth-service
  ports:
    - name: http
      port: 80
      targetPort: 8080
YAML

cat > "${ROOT}/base/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml

# Common labels applied to all resources
commonLabels:
  app.kubernetes.io/name: auth-service
  app.kubernetes.io/part-of: auth-platform
YAML

# -------------------------
# Overlays: dev
# -------------------------

cat > "${ROOT}/overlays/dev/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: auth-dev

resources:
  - ../../base

patches:
  - path: patch-deployment.yaml
    target:
      kind: Deployment
      name: auth-service

# Optional: dev-specific labels/annotations
commonLabels:
  env: dev
YAML

cat > "${ROOT}/overlays/dev/patch-deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: auth-service
spec:
  replicas: 1
  template:
    spec:
      containers:
        - name: auth-service
          image: ghcr.io/your-org/auth-service:dev
          env:
            - name: LOG_LEVEL
              value: "debug"
YAML

# -------------------------
# Overlays: uat
# -------------------------

cat > "${ROOT}/overlays/uat/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: auth-uat

resources:
  - ../../base

patches:
  - path: patch-deployment.yaml
    target:
      kind: Deployment
      name: auth-service

commonLabels:
  env: uat
YAML

cat > "${ROOT}/overlays/uat/patch-deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: auth-service
spec:
  replicas: 2
  template:
    spec:
      containers:
        - name: auth-service
          image: ghcr.io/your-org/auth-service:uat
          env:
            - name: LOG_LEVEL
              value: "info"
YAML

# -------------------------
# Overlays: prod
# -------------------------

cat > "${ROOT}/overlays/prod/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: auth-prod

resources:
  - ../../base

patches:
  - path: patch-deployment.yaml
    target:
      kind: Deployment
      name: auth-service

commonLabels:
  env: prod

# Optional: enforce name prefix/suffix for prod
nameSuffix: -prod
YAML

cat > "${ROOT}/overlays/prod/patch-deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: auth-service
spec:
  replicas: 3
  template:
    spec:
      containers:
        - name: auth-service
          image: ghcr.io/your-org/auth-service:stable
          resources:
            requests:
              cpu: "200m"
              memory: "256Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
          env:
            - name: LOG_LEVEL
              value: "warn"
YAML

echo "✅ GitOps structure created at: ${ROOT}"