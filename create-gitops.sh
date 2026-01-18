#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME=${1:-auth-service}
ROOT="${SERVICE_NAME}-gitops"

# Create directory structure
mkdir -p "${ROOT}/base"
mkdir -p "${ROOT}/overlays/dev"
mkdir -p "${ROOT}/overlays/uat"
mkdir -p "${ROOT}/overlays/prod"

# -------------------------
# Base manifests
# -------------------------

cat > "${ROOT}/base/deployment.yaml" <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${SERVICE_NAME}
  labels:
    app: ${SERVICE_NAME}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ${SERVICE_NAME}
  template:
    metadata:
      labels:
        app: ${SERVICE_NAME}
    spec:
      containers:
        - name: ${SERVICE_NAME}
          image: ghcr.io/your-org/${SERVICE_NAME}:latest
          ports:
            - name: http
              containerPort: 8080
YAML

cat > "${ROOT}/base/service.yaml" <<YAML
apiVersion: v1
kind: Service
metadata:
  name: ${SERVICE_NAME}
  labels:
    app: ${SERVICE_NAME}
spec:
  type: ClusterIP
  selector:
    app: ${SERVICE_NAME}
  ports:
    - name: http
      port: 80
      targetPort: 8080
YAML

cat > "${ROOT}/base/kustomization.yaml" <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml

commonLabels:
  app.kubernetes.io/name: ${SERVICE_NAME}
YAML

# -------------------------
# Overlays (dev, uat, prod)
# -------------------------

for ENV in dev uat prod; do
  cat > "${ROOT}/overlays/${ENV}/kustomization.yaml" <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ${SERVICE_NAME}-${ENV}

resources:
  - ../../base

patches:
  - path: patch-deployment.yaml
    target:
      kind: Deployment
      name: ${SERVICE_NAME}

commonLabels:
  env: ${ENV}
YAML

  cat > "${ROOT}/overlays/${ENV}/patch-deployment.yaml" <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${SERVICE_NAME}
spec:
  replicas: 1
  template:
    spec:
      containers:
        - name: ${SERVICE_NAME}
          image: ghcr.io/your-org/${SERVICE_NAME}:${ENV}
YAML
done

echo "✅ GitOps structure created for service: ${SERVICE_NAME}"