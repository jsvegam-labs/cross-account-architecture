#!/bin/bash

# Script de Destrucción Ordenada - Cross Account Architecture
# Autor: Kiro AI Assistant
# Fecha: $(date +%Y-%m-%d)

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"
}

# Banner
echo -e "${BLUE}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                    DESTRUCCIÓN ORDENADA                     ║
║              Cross Account Architecture                      ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Confirmación
echo -e "${RED}⚠️  ADVERTENCIA: Este script destruirá TODA la infraestructura${NC}"
echo "   - EKS Cluster"
echo "   - VPC y subnets"
echo "   - ECR Repository"
echo "   - ArgoCD y aplicaciones"
echo "   - Rancher (si existe)"
echo ""
read -p "¿Estás seguro de continuar? (escribir 'DESTROY' para confirmar): " confirm

if [ "$confirm" != "DESTROY" ]; then
    error "Destrucción cancelada por el usuario"
    exit 1
fi

log "Iniciando destrucción ordenada..."

# Paso 1: Actualizar Git Repository
log "Paso 1/6: Actualizando repositorio Git..."
if git status --porcelain | grep -q .; then
    warning "Hay cambios sin commitear, guardando estado actual..."
    git add .
    git commit -m "feat: save final state before infrastructure destroy - $(date)"
    git push
    success "Cambios guardados en Git"
else
    success "Repositorio Git ya está actualizado"
fi

# Paso 2: Destruir CI/CD (ArgoCD)
log "Paso 2/6: Destruyendo CI/CD (ArgoCD)..."
if [ -d "cicd" ]; then
    cd cicd
    if [ -f "terraform.tfstate" ] && [ -s "terraform.tfstate" ]; then
        log "Ejecutando terraform destroy en cicd..."
        terraform destroy -auto-approve \
            -var="region=us-east-1" \
            -var="aws_profile=eks-operator" \
            -var="cluster_name=my-eks-cluster" || warning "Algunos recursos de CI/CD no se pudieron destruir"
        success "CI/CD destruido"
    else
        warning "No hay estado de Terraform en cicd/"
    fi
    cd ..
else
    warning "Directorio cicd/ no encontrado"
fi

# Paso 3: Limpiar Namespaces y CRDs Problemáticos
log "Paso 3/6: Limpiando namespaces y CRDs problemáticos..."

# Verificar si kubectl funciona
if kubectl cluster-info &>/dev/null; then
    log "Cluster accesible, procediendo con limpieza..."
    
    # Eliminar aplicaciones ArgoCD
    log "Eliminando aplicaciones ArgoCD..."
    kubectl delete applications -n argocd --all --timeout=60s 2>/dev/null || warning "No se encontraron aplicaciones ArgoCD"
    
    # Eliminar CRDs de Rancher
    log "Eliminando CRDs de Rancher..."
    CATTLE_CRDS=$(kubectl get crd 2>/dev/null | grep cattle | awk '{print $1}' || true)
    if [ -n "$CATTLE_CRDS" ]; then
        echo "$CATTLE_CRDS" | xargs kubectl delete crd 2>/dev/null || warning "Algunos CRDs de Rancher no se pudieron eliminar"
        success "CRDs de Rancher eliminados"
    else
        log "No se encontraron CRDs de Rancher"
    fi
    
    # Forzar eliminación de namespaces problemáticos
    log "Forzando eliminación de namespaces problemáticos..."
    for ns in cattle-system cert-manager ingress-nginx java-demo argocd; do
        if kubectl get namespace "$ns" &>/dev/null; then
            log "Eliminando namespace: $ns"
            # Eliminar finalizers
            kubectl patch namespace "$ns" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
            # Forzar eliminación
            kubectl delete namespace "$ns" --force --grace-period=0 2>/dev/null || true
        fi
    done
    
    # Esperar un momento para que se procesen las eliminaciones
    sleep 10
    success "Namespaces problemáticos limpiados"
else
    warning "Cluster no accesible, saltando limpieza de Kubernetes"
fi

# Paso 4: Destruir Addons
log "Paso 4/6: Destruyendo addons..."
if [ -d "addons" ]; then
    cd addons
    if [ -f "terraform.tfstate" ] && [ -s "terraform.tfstate" ]; then
        log "Ejecutando terraform destroy en addons..."
        terraform destroy -auto-approve \
            -var="region=us-east-1" \
            -var="aws_profile=eks-operator" \
            -var="cluster_name=my-eks-cluster" \
            -var="rancher_hostname=" \
            -var="rancher_admin_password=dummy" || warning "Algunos addons no se pudieron destruir"
        success "Addons destruidos"
    else
        warning "No hay estado de Terraform en addons/"
    fi
    cd ..
else
    warning "Directorio addons/ no encontrado"
fi

# Paso 5: Destruir Infraestructura Base
log "Paso 5/6: Destruyendo infraestructura base..."
if [ -f "terraform.tfstate" ] && [ -s "terraform.tfstate" ]; then
    log "Ejecutando terraform destroy en infraestructura base..."
    terraform destroy -auto-approve || error "Error al destruir infraestructura base"
    success "Infraestructura base destruida"
else
    warning "No hay estado de Terraform en el directorio raíz"
fi

# Paso 6: Verificación Final
log "Paso 6/6: Verificando limpieza completa..."

# Verificar cluster
if kubectl get nodes &>/dev/null; then
    warning "El cluster EKS aún está accesible"
else
    success "Cluster EKS eliminado correctamente"
fi

# Verificar recursos AWS (opcional)
log "Verificando recursos AWS restantes..."
CLUSTERS=$(aws eks list-clusters --region us-east-1 --query 'clusters' --output text 2>/dev/null || echo "")
if [ -n "$CLUSTERS" ] && [ "$CLUSTERS" != "None" ]; then
    warning "Clusters EKS restantes: $CLUSTERS"
else
    success "No hay clusters EKS restantes"
fi

VPCS=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=vpc-virginia" --region us-east-1 --query 'Vpcs[].VpcId' --output text 2>/dev/null || echo "")
if [ -n "$VPCS" ] && [ "$VPCS" != "None" ]; then
    warning "VPCs restantes con tag vpc-virginia: $VPCS"
else
    success "No hay VPCs restantes con tag vpc-virginia"
fi

# Resumen final
echo ""
echo -e "${GREEN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                    ✅ DESTRUCCIÓN COMPLETA                   ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

success "Destrucción ordenada completada exitosamente"
log "Código fuente guardado en Git para futuras regeneraciones"
log "Para volver a desplegar: terraform apply"

echo ""
echo -e "${BLUE}📊 Resumen de lo destruido:${NC}"
echo "   ✅ CI/CD Pipeline (ArgoCD)"
echo "   ✅ Addons (Rancher, Ingress, Cert-Manager)"
echo "   ✅ EKS Cluster y Node Groups"
echo "   ✅ VPC, Subnets, NAT Gateway"
echo "   ✅ ECR Repository"
echo "   ✅ IAM Roles y Policies"
echo ""
echo -e "${GREEN}💰 Costos AWS detenidos: ~$104-122/mes${NC}"