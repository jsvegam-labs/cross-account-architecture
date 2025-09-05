1) Verifica que el clúster esté ACTIVE
### Añadir profiles en caso de
export AWS_REGION=us-east-1

# Estado del clúster
aws eks describe-cluster --name my-eks-cluster --query 'cluster.status' --output text

# (Opcional) esperar hasta ACTIVE
aws eks wait cluster-active --name my-eks-cluster

# Ver versión/endpoint
aws eks describe-cluster --name my-eks-cluster --query 'cluster.[version,endpoint]' --output table



2) Configura tu kubeconfig y comprueba conexión
aws eks update-kubeconfig --name my-eks-cluster --region us-east-1 --alias my-eks-cluster
kubectl cluster-info
kubectl version


# Estado del Node Group
aws eks describe-nodegroup \
  --cluster-name my-eks-cluster \
  --nodegroup-name my-eks-cluster-nodes \
  --query 'nodegroup.status' --output text

# Nodos listos (Ready)
kubectl get nodes -o wide
# (útil) ver a qué nodegroup pertenece cada nodo
kubectl get nodes -L eks.amazonaws.com/nodegroup

4) Sistema kube-system sano

Deberías ver aws-node, kube-proxy y coredns “Running/Ready”.

kubectl get pods -n kube-system -o wide
kubectl get ds -n kube-system   # DaemonSets (aws-node, kube-proxy)
kubectl get deploy -n kube-system  # Deployments (coredns, etc.)

