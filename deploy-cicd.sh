#!/bin/bash

# Script para desplegar CI/CD en EKS existente
set -e

echo "🚀 Desplegando CI/CD en EKS existente..."

# Variables
export AWS_PROFILE=eks-operator
export AWS_REGION=us-east-1
export CLUSTER_NAME=my-eks-cluster

# Configurar kubeconfig
echo "📋 Configurando kubeconfig..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION" --alias "$CLUSTER_NAME"
kubectl config use-context "$CLUSTER_NAME"

# Verificar conexión
echo "✅ Verificando conexión al cluster..."
kubectl get nodes

# Desplegar ArgoCD directamente con kubectl
echo "🔄 Desplegando ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Esperar a que ArgoCD esté listo
echo "⏳ Esperando a que ArgoCD esté listo..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Exponer ArgoCD con LoadBalancer
echo "🌐 Exponiendo ArgoCD..."
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Obtener URL y password
echo "📝 Obteniendo credenciales..."
echo "Esperando LoadBalancer..."
sleep 30

LB_URL=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
ADMIN_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo ""
echo "🎉 ¡ArgoCD desplegado exitosamente!"
echo "📍 URL: http://$LB_URL"
echo "👤 Usuario: admin"
echo "🔑 Password: $ADMIN_PASS"
echo ""
echo "💡 Próximos pasos:"
echo "1. Accede a ArgoCD con las credenciales de arriba"
echo "2. Conecta tu repositorio Git"
echo "3. Configura GitHub Secrets (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)"
echo "4. Haz push de código para activar el pipeline"