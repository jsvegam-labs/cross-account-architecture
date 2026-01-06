# 🏗️ Cross-Account Architecture + CI/CD

Proyecto completo de infraestructura como código que despliega una arquitectura AWS moderna con pipeline CI/CD automatizado usando Terraform, EKS, ArgoCD y GitHub Actions.

## 🎯 Características Principales

- 🏗️ **Infraestructura completa**: EKS + VPC + ECR + IAM
- 🔄 **CI/CD GitOps**: GitHub Actions + ArgoCD
- 🎛️ **Gestión de cluster**: Rancher + Ingress NGINX + Cert-Manager
- 🤖 **Despliegue inteligente**: Validaciones + Rollback automático
- 🧹 **Destrucción ordenada**: Sin recursos colgados
- 💰 **Optimizado para costos**: Instancias SPOT + Auto-scaling

## 🏗️ Arquitectura de Infraestructura

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                AWS REGION (us-east-1)                           │
├─────────────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────────────────────┐ │
│  │                            VPC (10.0.0.0/16)                               │ │
│  │                                                                             │ │
│  │  ┌─────────────────────┐              ┌─────────────────────┐              │ │
│  │  │   PUBLIC SUBNETS    │              │   PRIVATE SUBNETS   │              │ │
│  │  │   (10.0.101.0/24)   │              │   (10.0.1.0/24)     │              │ │
│  │  │   (10.0.102.0/24)   │              │   (10.0.2.0/24)     │              │ │
│  │  │                     │              │                     │              │ │
│  │  │  ┌───────────────┐  │              │  ┌───────────────┐  │              │ │
│  │  │  │ Internet GW   │  │              │  │  NAT Gateway  │  │              │ │
│  │  │  └───────────────┘  │              │  └───────────────┘  │              │ │
│  │  │                     │              │                     │              │ │
│  │  │  ┌───────────────┐  │              │  ┌───────────────┐  │              │ │
│  │  │  │ Load Balancer │  │              │  │  EKS Nodes    │  │              │ │
│  │  │  │ (ArgoCD/Apps) │  │              │  │  (t3.medium)  │  │              │ │
│  │  │  └───────────────┘  │              │  │  SPOT Fleet   │  │              │ │
│  │  └─────────────────────┘              │  └───────────────┘  │              │ │
│  │                                       │                     │              │ │
│  │                                       │  ┌───────────────┐  │              │ │
│  │                                       │  │ EKS Control   │  │              │ │
│  │                                       │  │ Plane (AWS)   │  │              │ │
│  │                                       │  └───────────────┘  │              │ │
│  │                                       └─────────────────────┘              │ │
│  └─────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────────┐ │
│  │                              ECR Repository                                 │ │
│  │                           (deepseek-app images)                            │ │
│  └─────────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 🔧 Componentes de Infraestructura

| Componente | Descripción | Configuración |
|------------|-------------|---------------|
| **VPC** | Red virtual privada | 10.0.0.0/16, Multi-AZ |
| **EKS Cluster** | Kubernetes gestionado | v1.33, Control plane gestionado |
| **Node Groups** | Nodos de trabajo | t3.medium SPOT, Auto-scaling 1-3 |
| **ECR** | Registry de imágenes | deepseek-app repository |
| **Load Balancers** | Balanceadores de carga | NLB para ArgoCD, ALB para apps |
| **Security Groups** | Firewall de red | Reglas mínimas necesarias |

## 🔄 Pipeline CI/CD

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              CI/CD PIPELINE FLOW                               │
└─────────────────────────────────────────────────────────────────────────────────┘

    Developer                GitHub                 AWS ECR              EKS Cluster
        │                      │                      │                      │
        │ 1. git push          │                      │                      │
        ├─────────────────────►│                      │                      │
        │                      │                      │                      │
        │                      │ 2. GitHub Actions   │                      │
        │                      │    Triggered         │                      │
        │                      │                      │                      │
        │                      │ 3. Build Docker      │                      │
        │                      │    Image             │                      │
        │                      │                      │                      │
        │                      │ 4. Push Image        │                      │
        │                      ├─────────────────────►│                      │
        │                      │                      │                      │
        │                      │ 5. Update Manifest   │                      │
        │                      │    (image tag)       │                      │
        │                      │                      │                      │
        │                      │                      │ 6. ArgoCD Sync       │
        │                      │                      │    (GitOps)          │
        │                      │◄─────────────────────┼─────────────────────►│
        │                      │                      │                      │
        │                      │                      │ 7. Deploy New        │
        │                      │                      │    Version           │
        │                      │                      │                      │
        │ 8. App Running       │                      │                      │
        │◄─────────────────────┼──────────────────────┼─────────────────────►│
```

### 🎛️ Componentes CI/CD

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           EKS CLUSTER COMPONENTS                               │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐    │
│  │   NAMESPACE: argocd │  │ NAMESPACE: rancher  │  │ NAMESPACE: ingress  │    │
│  │                     │  │                     │  │                     │    │
│  │  ┌───────────────┐  │  │  ┌───────────────┐  │  │  ┌───────────────┐  │    │
│  │  │ argocd-server │  │  │  │ rancher-server│  │  │  │ nginx-ingress │  │    │
│  │  │ (GitOps CD)   │  │  │  │ (Cluster Mgmt)│  │  │  │ (Load Balancer│  │    │
│  │  └───────────────┘  │  │  └───────────────┘  │  │  │  Controller)  │  │    │
│  │                     │  │                     │  │  └───────────────┘  │    │
│  │  ┌───────────────┐  │  │  ┌───────────────┐  │  │                     │    │
│  │  │ repo-server   │  │  │  │ rancher-      │  │  │  ┌───────────────┐  │    │
│  │  │ (Git Sync)    │  │  │  │ webhook       │  │  │  │ cert-manager  │  │    │
│  │  └───────────────┘  │  │  └───────────────┘  │  │  │ (TLS Certs)   │  │    │
│  │                     │  │                     │  │  └───────────────┘  │    │
│  │  ┌───────────────┐  │  └─────────────────────┘  └─────────────────────┘    │
│  │  │ app-controller│  │                                                       │
│  │  │ (Deployment)  │  │                                                       │
│  │  └───────────────┘  │                                                       │
│  └─────────────────────┘                                                       │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────────┐ │
│  │                        NAMESPACE: default                                  │ │
│  │                                                                             │ │
│  │  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐                  │ │
│  │  │ java-demo-app │  │ java-demo-app │  │ java-demo-svc │                  │ │
│  │  │ (Pod 1)       │  │ (Pod 2)       │  │ (Service)     │                  │ │
│  │  └───────────────┘  └───────────────┘  └───────────────┘                  │ │
│  └─────────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## 🚀 Comandos Rápidos

```bash
# Despliegue completo
make deploy

# Destrucción ordenada
make destroy

# Ver plan sin aplicar
make plan

# Health check
make health

# Ver logs
make logs

# Limpiar archivos temporales
make clean
```

## 💰 Costos Estimados (Mensual)

| Componente | Costo | Descripción |
|------------|-------|-------------|
| **EKS Control Plane** | $72 | Kubernetes API server gestionado |
| **EC2 Nodes (SPOT)** | $15-25 | t3.medium SPOT instances (1-3 nodes) |
| **NAT Gateway** | $32 | Conectividad internet para nodos privados |
| **Load Balancers** | $16-20 | NLB para ArgoCD + ALB para aplicaciones |
| **ECR Storage** | $1-5 | Almacenamiento de imágenes Docker |
| **Data Transfer** | $5-10 | Transferencia de datos |
| **Total** | **$141-164/mes** | Costo total estimado |

### 💡 Optimizaciones de Costo
- ✅ **Instancias SPOT**: 60-70% más baratas que On-Demand
- ✅ **Auto-scaling**: Escala a 0 cuando no hay carga
- ✅ **Single NAT Gateway**: Compartido entre AZs
- ✅ **ECR Lifecycle**: Limpieza automática de imágenes antiguas

## 🎯 Flujo de Trabajo Completo

### 1. Desarrollo Local
```bash
# Desarrollar aplicación Java
vim src/main/java/com/example/demo/DemoApplication.java

# Probar localmente
./mvnw spring-boot:run
```

### 2. CI/CD Automático
```bash
# Push activa el pipeline
git add .
git commit -m "feat: nueva funcionalidad"
git push origin main

# GitHub Actions automáticamente:
# 1. Compila la aplicación Java
# 2. Construye imagen Docker
# 3. Sube imagen a ECR
# 4. Actualiza manifiestos K8s
```

### 3. Despliegue GitOps
```bash
# ArgoCD automáticamente:
# 1. Detecta cambios en Git
# 2. Sincroniza con cluster EKS
# 3. Despliega nueva versión
# 4. Verifica health checks
```

### 4. Monitoreo y Gestión
```bash
# Acceder a ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Acceder a Rancher
kubectl get svc -n cattle-system

# Ver aplicaciones
kubectl get pods -n default
```

## 📁 Estructura del Proyecto

```
cross-account-architecture/
├── 🏗️ INFRAESTRUCTURA
│   ├── main.tf                 # Configuración principal Terraform
│   ├── providers.tf            # Proveedores AWS
│   ├── variables.tf            # Variables de entrada
│   ├── outputs.tf              # Outputs de infraestructura
│   └── modules/                # Módulos reutilizables
│       ├── vpc/                # Módulo VPC
│       ├── eks/                # Módulo EKS
│       └── ecr/                # Módulo ECR
│
├── 🔄 CI/CD
│   ├── cicd/                   # Configuración ArgoCD
│   │   ├── argocd.tf          # Despliegue ArgoCD
│   │   ├── jenkins.tf         # Jenkins (opcional)
│   │   └── variables.tf       # Variables CI/CD
│   └── addons/                 # Addons del cluster
│       ├── rancher.tf         # Gestión de cluster
│       ├── ingress-certmanager.tf # Ingress + TLS
│       └── variables.tf       # Variables addons
│
├── 🐳 APLICACIÓN
│   ├── src/                   # Código fuente Java
│   ├── k8s/                   # Manifiestos Kubernetes
│   │   ├── manifests/         # Deployments, Services
│   │   └── argocd-apps/       # Aplicaciones ArgoCD
│   ├── Dockerfile             # Imagen Docker
│   ├── pom.xml               # Configuración Maven
│   └── .github/workflows/     # GitHub Actions
│
├── 🤖 AUTOMATIZACIÓN
│   ├── deploy.sh             # Script de despliegue inteligente
│   ├── destroy.sh            # Script de destrucción ordenada
│   ├── deploy-config.sh      # Configuraciones y utilidades
│   └── Makefile              # Comandos simplificados
│
├── 📚 DOCUMENTACIÓN
│   ├── README.md             # Este archivo
│   ├── DEPLOYMENT-GUIDE.md   # Guía completa de despliegue
│   ├── DESTROY-GUIDE.md      # Guía de destrucción
│   └── PIPELINE-README.md    # Configuración CI/CD
│
└── 📊 LOGS Y BACKUPS
    ├── logs/                 # Logs de despliegues
    └── backups/              # Backups de estado Terraform
```

## 🔧 Prerequisitos

```bash
# Herramientas requeridas
terraform --version  # >= 1.0
aws --version        # AWS CLI configurado
kubectl version      # Cliente Kubernetes
docker --version     # Para builds locales
git --version        # Control de versiones
jq --version         # Procesamiento JSON
```

## 🚀 Inicio Rápido

### 1. Clonar y Configurar
```bash
git clone <tu-repo>
cd cross-account-architecture

# Configurar AWS
export AWS_PROFILE=eks-operator
export AWS_REGION=us-east-1
```

### 2. Desplegar Infraestructura
```bash
# Opción A: Script automático (recomendado)
make deploy

# Opción B: Manual
terraform init
terraform apply -auto-approve
```

### 3. Configurar kubectl
```bash
aws eks update-kubeconfig --name my-eks-cluster --region us-east-1
kubectl get nodes
```

### 4. Desplegar CI/CD
```bash
# Desplegar ArgoCD y addons
cd addons && terraform apply -auto-approve
cd ../cicd && terraform apply -auto-approve
```

### 5. Configurar GitHub Actions
```bash
# En tu repo GitHub → Settings → Secrets:
AWS_ACCESS_KEY_ID=tu_access_key
AWS_SECRET_ACCESS_KEY=tu_secret_key
```

## 🧹 Destrucción Completa

```bash
# Destrucción ordenada (recomendado)
make destroy

# O manual paso a paso
./destroy.sh
```

## 🚨 Troubleshooting

### Problemas Comunes

#### 1. Namespaces Colgados
```bash
# Solución automática en destroy.sh
kubectl patch namespace <ns> -p '{"metadata":{"finalizers":null}}' --type=merge
```

#### 2. CRDs Problemáticos
```bash
# Eliminar CRDs de Rancher
kubectl get crd | grep cattle | awk '{print $1}' | xargs kubectl delete crd
```

#### 3. Estado Terraform Corrupto
```bash
terraform state list
terraform state rm <resource>
terraform refresh
```

## 📊 Monitoreo y Logs

```bash
# Ver logs de despliegue
make logs

# Health check completo
make health

# Estado de recursos
terraform show

# Pods en el cluster
kubectl get pods -A
```

## 🔗 Enlaces Útiles

- [📖 DEPLOYMENT-GUIDE.md](./DEPLOYMENT-GUIDE.md) - Guía completa paso a paso
- [🧹 DESTROY-GUIDE.md](./DESTROY-GUIDE.md) - Destrucción ordenada
- [🔄 PIPELINE-README.md](./PIPELINE-README.md) - Configuración CI/CD detallada
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EKS Documentation](https://docs.aws.amazon.com/eks/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)

## 📈 Roadmap

- [ ] **Multi-environment**: Dev, Staging, Prod
- [ ] **Monitoring**: Prometheus + Grafana
- [ ] **Logging**: ELK Stack
- [ ] **Security**: OPA Gatekeeper + Falco
- [ ] **Backup**: Velero para backups de cluster
- [ ] **Networking**: Istio Service Mesh
- [ ] **Database**: RDS PostgreSQL + Redis
- [ ] **Secrets**: External Secrets Operator

## 🤝 Contribuir

1. Fork el proyecto
2. Crear feature branch (`git checkout -b feature/nueva-funcionalidad`)
3. Commit cambios (`git commit -m 'feat: nueva funcionalidad'`)
4. Push al branch (`git push origin feature/nueva-funcionalidad`)
5. Crear Pull Request

## 📄 Licencia

Este proyecto está bajo la licencia MIT. Ver `LICENSE` para más detalles.

---

**💡 Tip**: Para una experiencia completa, revisa la [Guía de Despliegue](./DEPLOYMENT-GUIDE.md) que incluye ejemplos detallados y mejores prácticas.