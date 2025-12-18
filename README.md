# Cross-Account Architecture
Terraform project that creates an AWS Architecture with intelligent deployment automation.

## 🚀 Despliegue Inteligente

Este proyecto incluye un sistema de despliegue automatizado con:
- ✅ Validaciones pre-despliegue
- 🔄 Rollback automático en caso de fallo
- 📝 Logging detallado
- 🏥 Health checks
- 🔒 Backup automático de estado

### Comandos Rápidos

```bash
# Despliegue completo
make deploy

# Ver plan sin aplicar
make plan

# Health check
make health

# Ver logs
make logs

# Limpiar archivos temporales
make clean
```

### Uso Manual del Script

```bash
# Despliegue completo
./deploy.sh

# Solo validaciones
./deploy.sh --validate-only
```

## 📁 Estructura de Archivos

```
├── deploy.sh           # Script principal de despliegue
├── deploy-config.sh    # Configuraciones y utilidades
├── Makefile           # Comandos simplificados
├── logs/              # Logs de despliegues
├── backups/           # Backups de estado
└── main.tf            # Configuración Terraform
```

## 🔧 Configuración

### Variables de Entorno (Opcionales)

```bash
export ENVIRONMENT=dev
export AWS_DEFAULT_REGION=us-east-1
export SLACK_WEBHOOK_URL="https://hooks.slack.com/..."
```

### Prerequisitos

- Terraform >= 1.0
- AWS CLI configurado
- jq
- PostgreSQL client (para testing RDS)

## 📊 Características del Script

### Validaciones Automáticas
- ✅ Herramientas requeridas instaladas
- ✅ Credenciales AWS válidas
- ✅ Archivos Terraform válidos
- ✅ Plan de Terraform sin errores
- ✅ Conectividad a recursos desplegados

### Rollback Automático
- 🔄 Backup automático del estado antes del despliegue
- 🔄 Restauración automática en caso de fallo
- 🔄 Limpieza de recursos parcialmente creados

### Logging y Monitoreo
- 📝 Logs detallados con timestamps
- 📝 Diferentes niveles de log (INFO, WARN, ERROR, SUCCESS)
- 📝 Archivos de log organizados por fecha
- 📝 Limpieza automática de logs antiguos

### Health Checks
- 🏥 Validación de estado de Terraform
- 🏥 Conectividad AWS
- 🏥 Estado de recursos críticos (VPC, RDS, EC2)
- 🏥 Conectividad a base de datos

## 🗃️ Testing RDS PostgreSQL

El script incluye validación automática de RDS, pero también puedes testear manualmente:

### Crear EC2 para Testing
```bash
# User Data para la instancia EC2:
#!/bin/bash
cd /tmp
sudo dnf install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
sudo systemctl enable amazon-ssm-agent
sudo systemctl start amazon-ssm-agent
sudo dnf install -y postgresql15
```

### Conectar a RDS
```bash
# Agregar regla inbound en SG de DB para permitir conexiones desde SG de EC2
# Comando para conectar:
psql -h <db-endpoint> -U <user> -d <database>
```

## 🚨 Troubleshooting

### Ver logs del último despliegue
```bash
make logs
# o
tail -f logs/deploy-$(date +%Y%m%d)*.log
```

### Rollback manual
```bash
# Restaurar desde backup
cp backups/terraform.tfstate.backup-YYYYMMDD-HHMMSS terraform.tfstate
terraform refresh
```

### Limpiar estado corrupto
```bash
terraform state list
terraform state rm <resource_name>  # si es necesario
```

## 📈 Próximas Mejoras

- [ ] Integración con GitHub Actions
- [ ] Notificaciones Slack/Email
- [ ] Métricas de despliegue
- [ ] Tests automatizados
- [ ] Multi-environment support




