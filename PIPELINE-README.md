# Pipeline CI/CD - Guía de Implementación

## Arquitectura Implementada

### Componentes:
- **GitHub Actions**: CI gratuito (build + push a ECR)
- **ArgoCD**: CD en EKS (GitOps)
- **Jenkins**: Opcional para builds complejos
- **ECR**: Registry de imágenes (ya existente)

## Costos Estimados (Mensual)

### Opción Económica (Solo ArgoCD):
- **GitHub Actions**: $0 (repos públicos)
- **ArgoCD en EKS**: ~$5-10 (recursos mínimos)
- **ECR**: ~$1-5 (storage imágenes)
- **Total**: ~$6-15/mes

### Con Jenkins (si necesario):
- **Jenkins en EKS**: +$10-20/mes
- **Total**: ~$16-35/mes

## Despliegue

### 1. Configurar GitHub Secrets:
```bash
# En tu repo de GitHub, añadir secrets:
AWS_ACCESS_KEY_ID=tu_access_key
AWS_SECRET_ACCESS_KEY=tu_secret_key
```

### 2. Desplegar CI/CD en EKS existente:
```bash
# Opción A: Script automático (recomendado)
./deploy-cicd.sh

# Opción B: Manual con Terraform
cd cicd
terraform init
terraform apply
```

### 3. Obtener credenciales ArgoCD:
```bash
# URL de ArgoCD
terraform output argocd_server_url

# Password admin
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

### 4. Configurar ArgoCD:
1. Acceder a la URL de ArgoCD
2. Login: admin / password_obtenido
3. Conectar tu repositorio Git
4. Las aplicaciones se despliegan automáticamente

## Flujo de Trabajo

1. **Developer push** → GitHub
2. **GitHub Actions** → Build + Push ECR
3. **ArgoCD** → Detecta cambios + Deploy EKS

## Alternativa Más Económica

Si quieres ahorrar más, puedes usar:
- **GitLab CI/CD** (gratis)
- **ArgoCD** en cluster local (minikube/k3s)
- Solo EKS para producción

## Comandos Útiles

```bash
# Ver aplicaciones ArgoCD
kubectl get applications -n argocd

# Logs ArgoCD
kubectl logs -n argocd deployment/argocd-server

# Acceso directo ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443
```