#!/bin/bash

# Configuración del script de despliegue
export DEPLOY_CONFIG_VERSION="1.0"

# Configuración de timeouts (en segundos)
export TERRAFORM_TIMEOUT=1800
export RDS_READY_TIMEOUT=900
export EC2_READY_TIMEOUT=300

# Configuración de reintentos
export MAX_RETRIES=3
export RETRY_DELAY=30

# Configuración de notificaciones (opcional)
export SLACK_WEBHOOK_URL=""
export EMAIL_NOTIFICATIONS=""

# Configuración específica del proyecto
export PROJECT_NAME="cross-account-architecture"
export ENVIRONMENT="${ENVIRONMENT:-dev}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

# Validaciones específicas del proyecto
validate_rds_connection() {
    local db_endpoint=$1
    local db_user=$2
    local db_name=$3
    
    info "Validando conexión a RDS..."
    
    # Crear instancia temporal para testing si no existe
    local test_instance_id=$(create_test_instance_if_needed)
    
    if [[ -n "$test_instance_id" ]]; then
        # Test de conectividad via SSM
        local test_command="timeout 10 pg_isready -h ${db_endpoint} -U ${db_user} -d ${db_name}"
        
        local command_id=$(aws ssm send-command \
            --instance-ids "$test_instance_id" \
            --document-name "AWS-RunShellScript" \
            --parameters "commands=[\"$test_command\"]" \
            --query 'Command.CommandId' \
            --output text)
        
        # Esperar resultado
        sleep 10
        local result=$(aws ssm get-command-invocation \
            --command-id "$command_id" \
            --instance-id "$test_instance_id" \
            --query 'Status' \
            --output text 2>/dev/null || echo "Failed")
        
        if [[ "$result" == "Success" ]]; then
            success "Conexión RDS validada"
            return 0
        else
            error "Fallo en conexión RDS"
            return 1
        fi
    fi
}

create_test_instance_if_needed() {
    # Buscar instancia existente con tag de testing
    local existing_instance=$(aws ec2 describe-instances \
        --filters "Name=tag:Purpose,Values=db-test" "Name=instance-state-name,Values=running" \
        --query 'Reservations[0].Instances[0].InstanceId' \
        --output text 2>/dev/null)
    
    if [[ "$existing_instance" != "None" && -n "$existing_instance" ]]; then
        echo "$existing_instance"
        return 0
    fi
    
    # Si no existe, usar la instancia principal del proyecto
    terraform output -raw ec2_instance_id 2>/dev/null || echo ""
}

# Función de notificaciones
send_notification() {
    local status=$1
    local message=$2
    
    if [[ -n "$SLACK_WEBHOOK_URL" ]]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"🚀 Deploy ${status}: ${message}\"}" \
            "$SLACK_WEBHOOK_URL" &>/dev/null || true
    fi
}

# Función de limpieza de recursos temporales
cleanup_temp_resources() {
    info "Limpiando recursos temporales..."
    
    # Limpiar archivos temporales
    rm -f tfplan terraform.tfplan.json
    
    # Limpiar logs antiguos (más de 7 días)
    find "${LOG_DIR}" -name "deploy-*.log" -mtime +7 -delete 2>/dev/null || true
    
    # Limpiar backups antiguos (más de 30 días)
    find "${BACKUP_DIR}" -name "*.backup-*" -mtime +30 -delete 2>/dev/null || true
}

# Función de health check completo
full_health_check() {
    info "Ejecutando health check completo..."
    
    local health_status=0
    
    # Check 1: Terraform state
    if ! terraform show &>/dev/null; then
        error "Estado de Terraform corrupto"
        health_status=1
    fi
    
    # Check 2: AWS conectividad
    if ! aws sts get-caller-identity &>/dev/null; then
        error "Conectividad AWS fallida"
        health_status=1
    fi
    
    # Check 3: Recursos críticos
    local vpc_id=$(terraform output -raw vpc_id 2>/dev/null)
    if [[ -n "$vpc_id" ]]; then
        local vpc_status=$(aws ec2 describe-vpcs --vpc-ids "$vpc_id" --query 'Vpcs[0].State' --output text 2>/dev/null)
        if [[ "$vpc_status" != "available" ]]; then
            error "VPC no disponible"
            health_status=1
        fi
    fi
    
    if [[ $health_status -eq 0 ]]; then
        success "Health check completado - Todo OK"
    else
        error "Health check falló"
    fi
    
    return $health_status
}
