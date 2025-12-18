# Guía de Despliegue Completo - Cross Account Architecture + CI/CD

## 📋 Prerrequisitos

```bash
# Herramientas necesarias
- AWS CLI configurado
- Terraform >= 1.0
- kubectl
- Docker
- Git
```

## 🏗️ Paso 1: Desplegar Infraestructura Base

### 1.1 Configurar Variables
```bash
export AWS_PROFILE=eks-operator
export AWS_REGION=us-east-1
```

### 1.2 Desplegar VPC + EKS + ECR
```bash
# Desde el directorio raíz
terraform init
terraform plan
terraform apply -auto-approve
```

**Recursos creados:**
- VPC en Virginia (us-east-1)
- EKS Cluster `my-eks-cluster`
- ECR Repository `deepseek-app`
- Node Groups con instancias SPOT

### 1.3 Configurar kubectl
```bash
aws eks update-kubeconfig --name my-eks-cluster --region us-east-1
kubectl get nodes
```

## 🏗️ Arquitectura del Sistema

```
┌─────────────────────────────────────────┐
│           Tu EKS Cluster                │
│         (my-eks-cluster)                │
├─────────────────────────────────────────┤
│  Namespace: default                     │
│  ├── Tu aplicación (deepseek-app)      │
│                                         │
│  Namespace: argocd                      │
│  ├── argocd-server                     │
│  ├── argocd-repo-server                │
│  ├── argocd-application-controller     │
│                                         │
│  Namespace: jenkins (si enabled)        │
│  ├── jenkins-controller                │
└─────────────────────────────────────────┘
```

**Ubicación de Componentes:**
- **ArgoCD:** Desplegado en tu EKS existente (namespace `argocd`)
- **Jenkins:** Opcional, mismo EKS (namespace `jenkins`)
- **Aplicaciones:** Namespace `default`
- **Costo adicional:** Solo LoadBalancer ArgoCD (+$16/mes)

## 🔄 Paso 2: Desplegar Pipeline CI/CD

### 2.1 Usar tu Repository Existente
```bash
# Si ya tienes el repo en GitHub, solo necesitas:
# 1. Hacer push de los nuevos archivos CI/CD
git add .
git commit -m "Add CI/CD pipeline"
git push

# 2. Asegúrate que el repo sea público (para GitHub Actions gratuitas)
# GitHub → Settings → General → Change repository visibility → Public
```

### 2.2 Configurar GitHub Secrets
En tu repo GitHub → Settings → Secrets and variables → Actions:
```
AWS_ACCESS_KEY_ID=tu_access_key_id
AWS_SECRET_ACCESS_KEY=tu_secret_access_key
```

### 2.3 Desplegar ArgoCD
```bash
# Opción A: Script automático (recomendado)
./deploy-cicd.sh

# Opción B: Manual
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
```

### 2.4 Obtener credenciales ArgoCD
```bash
# URL
kubectl get svc argocd-server -n argocd

# Password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## 🚀 Paso 3: Desplegar Aplicación

### 3.1 Actualizar manifiestos
```bash
# Obtener Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Actualizar imagen en deployment
sed -i "s/<ACCOUNT_ID>/$ACCOUNT_ID/g" k8s/manifests/deployment.yaml
```

### 3.2 Configurar ArgoCD
1. Acceder a ArgoCD UI (URL del paso 2.4)
2. Login: `admin` / password obtenido
3. Conectar repositorio Git:
   - Settings → Repositories → Connect Repo
   - URL: tu repo GitHub existente
4. Crear aplicación:
   - Applications → New App
   - Application Name: `deepseek-app`
   - Project: `default`
   - Repository URL: tu repo
   - Path: `k8s/manifests`
   - Cluster URL: `https://kubernetes.default.svc`
   - Namespace: `default`
   - Sync Policy: `Automatic`

### 3.3 Primer despliegue
```bash
# Hacer push para activar pipeline
echo "# Test" >> README.md
git add .
git commit -m "Trigger first deployment"
git push
```

## 🔐 Credenciales de Acceso

### ArgoCD
```bash
# URL de acceso
kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Usuario: admin
# Password:
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Jenkins (si está habilitado)
```bash
# URL de acceso
kubectl get svc jenkins -n jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}:8080'

# Usuario: admin
# Password:
kubectl get secret jenkins -n jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 -d
```

### Acceso Alternativo (Port-Forward)
```bash
# ArgoCD (sin LoadBalancer)
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Acceder: https://localhost:8080

# Jenkins (sin LoadBalancer)
kubectl port-forward svc/jenkins -n jenkins 8080:8080
# Acceder: http://localhost:8080
```

## 🔍 Verificación

### Verificar infraestructura
```bash
# EKS
kubectl get nodes
kubectl get pods -A

# ECR
aws ecr describe-repositories --repository-names deepseek-app
```

### Verificar pipeline
```bash
# GitHub Actions
# Ir a tu repo → Actions → Ver workflow ejecutándose

# ArgoCD
kubectl get applications -n argocd
kubectl get pods -n default
```

### Verificar aplicación
```bash
# Obtener URL del servicio
kubectl get svc sample-app-service

# Port-forward para probar
kubectl port-forward svc/sample-app-service 8080:80
# Abrir http://localhost:8080
```

## 📊 Costos Estimados

| Componente | Costo Mensual |
|------------|---------------|
| EKS Control Plane | $72 |
| EC2 Nodes (t3.small SPOT) | ~$15-25 |
| ECR Storage | ~$1-5 |
| LoadBalancers | ~$16-20 |
| **Total** | **~$104-122/mes** |

## 🛠️ Comandos Útiles

```bash
# Ver logs ArgoCD
kubectl logs -n argocd deployment/argocd-server

# Sincronizar aplicación manualmente
argocd app sync deepseek-app

# Ver estado del pipeline
kubectl get pods -n argocd
kubectl get applications -n argocd

# Acceso directo ArgoCD (sin LoadBalancer)
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## 🔄 Flujo Completo

1. **Developer** → Push código a GitHub
2. **GitHub Actions** → Build imagen + Push a ECR
3. **ArgoCD** → Detecta cambios + Deploy a EKS
4. **EKS** → Ejecuta nueva versión de la app

## 🧹 Limpieza (Opcional)

```bash
# Limpiar aplicaciones
kubectl delete applications -n argocd --all

# Limpiar ArgoCD
kubectl delete namespace argocd

# Destruir infraestructura
terraform destroy -auto-approve
```