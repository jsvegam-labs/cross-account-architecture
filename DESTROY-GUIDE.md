# 🧹 Guía de Destrucción Ordenada

Esta guía te ayuda a destruir completamente la infraestructura de manera ordenada y sin recursos colgados.

## 🚨 Antes de Empezar

### ⚠️ Advertencias Importantes
- **Irreversible**: Una vez destruido, no se puede recuperar
- **Datos**: Se perderán todos los datos en el cluster
- **Costos**: Se detendrán todos los costos AWS (~$104-122/mes)
- **Tiempo**: El proceso toma ~15-20 minutos

### 📋 Prerrequisitos
```bash
# Verificar herramientas
terraform --version
kubectl version --client
aws --version
git --version
```

## 🎯 Opción A: Script Automático (Recomendado)

### Ejecución Simple
```bash
./destroy.sh
```

El script te pedirá confirmación escribiendo `DESTROY` para proceder.

### Lo que hace automáticamente:
1. ✅ Guarda cambios en Git
2. ✅ Destruye CI/CD (ArgoCD)
3. ✅ Limpia namespaces problemáticos
4. ✅ Elimina CRDs de Rancher
5. ✅ Destruye addons
6. ✅ Destruye infraestructura base
7. ✅ Verifica limpieza completa

## 🔧 Opción B: Manual (Paso a Paso)

### Paso 1: Guardar Estado Actual
```bash
# Commitear todos los cambios
git add .
git commit -m "feat: save final state before destroy"
git push
```

### Paso 2: Destruir CI/CD
```bash
cd cicd
terraform destroy -auto-approve \
  -var="region=us-east-1" \
  -var="aws_profile=eks-operator" \
  -var="cluster_name=my-eks-cluster"
cd ..
```

### Paso 3: Limpiar Kubernetes
```bash
# Eliminar aplicaciones ArgoCD
kubectl delete applications -n argocd --all --timeout=60s

# Eliminar CRDs problemáticos de Rancher
kubectl get crd | grep cattle | awk '{print $1}' | xargs kubectl delete crd

# Forzar eliminación de namespaces colgados
for ns in cattle-system cert-manager ingress-nginx java-demo argocd; do
  kubectl patch namespace $ns -p '{"metadata":{"finalizers":null}}' --type=merge
  kubectl delete namespace $ns --force --grace-period=0
done
```

### Paso 4: Destruir Addons
```bash
cd addons
terraform destroy -auto-approve \
  -var="region=us-east-1" \
  -var="aws_profile=eks-operator" \
  -var="cluster_name=my-eks-cluster" \
  -var="rancher_hostname=" \
  -var="rancher_admin_password=dummy"
cd ..
```

### Paso 5: Destruir Infraestructura Base
```bash
terraform destroy -auto-approve
```

### Paso 6: Verificar Limpieza
```bash
# Verificar cluster eliminado
kubectl get nodes 2>/dev/null || echo "✅ Cluster eliminado"

# Verificar recursos AWS
aws eks list-clusters --region us-east-1
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=vpc-virginia" --region us-east-1
```

## 🚨 Troubleshooting

### Problema: Namespaces Colgados en "Terminating"
```bash
# Solución: Eliminar finalizers manualmente
kubectl get namespace <namespace> -o json | jq '.spec.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/<namespace>/finalize" -f -
```

### Problema: CRDs Bloqueando Eliminación
```bash
# Solución: Eliminar CRDs específicos
kubectl delete crd <crd-name> --force --grace-period=0
```

### Problema: Terraform State Corrupto
```bash
# Solución: Limpiar recursos específicos
terraform state list
terraform state rm <resource_name>
terraform refresh
```

### Problema: LoadBalancers No Se Eliminan
```bash
# Solución: Eliminar manualmente
kubectl delete svc --all-namespaces --field-selector spec.type=LoadBalancer
```

## 🔄 Regeneración Futura

### Para volver a desplegar todo:
```bash
# 1. Infraestructura base
terraform init
terraform apply -auto-approve

# 2. Configurar kubectl
aws eks update-kubeconfig --name my-eks-cluster --region us-east-1

# 3. Addons
cd addons
terraform init
terraform apply -auto-approve
cd ..

# 4. CI/CD
cd cicd
terraform init
terraform apply -auto-approve
cd ..
```

## 📊 Recursos Destruidos

### AWS Resources
- ✅ EKS Cluster (`my-eks-cluster`)
- ✅ EKS Node Groups
- ✅ VPC (`vpc-virginia`)
- ✅ Subnets (públicas y privadas)
- ✅ Internet Gateway
- ✅ NAT Gateway
- ✅ Route Tables
- ✅ Security Groups
- ✅ ECR Repository (`deepseek-app`)
- ✅ IAM Roles y Policies
- ✅ Elastic IPs

### Kubernetes Resources
- ✅ ArgoCD (namespace `argocd`)
- ✅ Rancher (namespace `cattle-system`)
- ✅ Ingress NGINX (namespace `ingress-nginx`)
- ✅ Cert-Manager (namespace `cert-manager`)
- ✅ Aplicaciones Java (namespace `java-demo`)
- ✅ Custom Resource Definitions (CRDs)

## 💰 Ahorro de Costos

Una vez destruido, se detienen todos los costos:
- **EKS Control Plane**: $72/mes → $0
- **EC2 Nodes**: $15-25/mes → $0
- **LoadBalancers**: $16-20/mes → $0
- **NAT Gateway**: $32/mes → $0
- **ECR Storage**: $1-5/mes → $0

**Total ahorrado**: ~$136-154/mes

## 📝 Logs y Auditoría

El script automático genera logs detallados:
```bash
# Ver logs del último destroy
tail -f destroy-$(date +%Y%m%d)*.log
```

## ✅ Checklist de Verificación

Después de la destrucción, verificar:

- [ ] `kubectl get nodes` falla (cluster eliminado)
- [ ] `aws eks list-clusters` no muestra `my-eks-cluster`
- [ ] `aws ec2 describe-vpcs` no muestra `vpc-virginia`
- [ ] `aws ecr describe-repositories` no muestra `deepseek-app`
- [ ] Git repository actualizado con último estado
- [ ] Costos AWS detenidos en la consola

## 🔗 Enlaces Útiles

- [Terraform Destroy Documentation](https://www.terraform.io/docs/commands/destroy.html)
- [Kubernetes Finalizers](https://kubernetes.io/docs/concepts/overview/working-with-objects/finalizers/)
- [AWS EKS Cleanup](https://docs.aws.amazon.com/eks/latest/userguide/delete-cluster.html)