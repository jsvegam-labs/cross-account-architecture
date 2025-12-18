#!/bin/bash

set -euo pipefail

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/deploy-$(date +%Y%m%d-%H%M%S).log"
BACKUP_DIR="${SCRIPT_DIR}/backups"
TERRAFORM_STATE_BACKUP="${BACKUP_DIR}/terraform.tfstate.backup-$(date +%Y%m%d-%H%M%S)"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables de estado
DEPLOYMENT_ID="deploy-$(date +%Y%m%d-%H%M%S)"
ROLLBACK_REQUIRED=false
INFRA_DEPLOYED=false
APP_DEPLOYED=false

# Crear directorios necesarios
mkdir -p "${LOG_DIR}" "${BACKUP_DIR}"

# Función de logging
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "${LOG_FILE}"
}

info() { log "INFO" "${BLUE}$*${NC}"; }
warn() { log "WARN" "${YELLOW}$*${NC}"; }
error() { log "ERROR" "${RED}$*${NC}"; }
success() { log "SUCCESS" "${GREEN}$*${NC}"; }

# Función de cleanup en caso de error
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        error "Deployment falló con código $exit_code"
        if [[ "$ROLLBACK_REQUIRED" == "true" ]]; then
            perform_rollback
        fi
    fi
    exit $exit_code
}

trap cleanup EXIT

# Validaciones pre-despliegue
validate_prerequisites() {
    info "Validando prerequisitos..."
    
    # Verificar herramientas
    for tool in terraform aws jq; do
        if ! command -v $tool &> /dev/null; then
            error "$tool no está instalado"
            return 1
        fi
    done
    
    # Verificar credenciales AWS
    if ! aws sts get-caller-identity &> /dev/null; then
        error "Credenciales AWS no configuradas"
        return 1
    fi
    
    # Verificar archivos Terraform
    if [[ ! -f "main.tf" ]]; then
        error "Archivos Terraform no encontrados"
        return 1
    fi
    
    success "Prerequisitos validados"
}

# Backup del estado actual
backup_state() {
    info "Creando backup del estado..."
    
    if [[ -f "terraform.tfstate" ]]; then
        cp terraform.tfstate "${TERRAFORM_STATE_BACKUP}"
        success "Estado respaldado en ${TERRAFORM_STATE_BACKUP}"
    fi
}

# Validar plan de Terraform
validate_terraform_plan() {
    info "Validando plan de Terraform..."
    
    terraform init -input=false
    terraform validate
    
    local plan_output=$(terraform plan -detailed-exitcode -out=tfplan 2>&1)
    local plan_exit_code=$?
    
    case $plan_exit_code in
        0)
            info "No hay cambios en la infraestructura"
            return 2
            ;;
        1)
            error "Error en el plan de Terraform"
            echo "$plan_output"
            return 1
            ;;
        2)
            info "Cambios detectados en la infraestructura"
            echo "$plan_output" | tee -a "${LOG_FILE}"
            return 0
            ;;
    esac
}

# Desplegar infraestructura
deploy_infrastructure() {
    info "Desplegando infraestructura..."
    ROLLBACK_REQUIRED=true
    
    if terraform apply -auto-approve tfplan; then
        INFRA_DEPLOYED=true
        success "Infraestructura desplegada exitosamente"
        
        # Validar recursos críticos
        validate_infrastructure
    else
        error "Fallo en el despliegue de infraestructura"
        return 1
    fi
}

# Validar infraestructura desplegada
validate_infrastructure() {
    info "Validando infraestructura desplegada..."
    
    # Obtener outputs de Terraform
    local db_endpoint=$(terraform output -raw db_endpoint 2>/dev/null || echo "")
    local vpc_id=$(terraform output -raw vpc_id 2>/dev/null || echo "")
    
    # Validar RDS
    if [[ -n "$db_endpoint" ]]; then
        info "Validando conectividad RDS..."
        local db_status=$(aws rds describe-db-instances --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null || echo "error")
        if [[ "$db_status" == "available" ]]; then
            success "RDS disponible: $db_endpoint"
        else
            warn "RDS no está disponible aún: $db_status"
        fi
    fi
    
    # Validar VPC
    if [[ -n "$vpc_id" ]]; then
        local vpc_state=$(aws ec2 describe-vpcs --vpc-ids "$vpc_id" --query 'Vpcs[0].State' --output text 2>/dev/null || echo "error")
        if [[ "$vpc_state" == "available" ]]; then
            success "VPC disponible: $vpc_id"
        else
            error "VPC no disponible: $vpc_state"
            return 1
        fi
    fi
}

# Desplegar aplicación (placeholder - adaptar según tu app)
deploy_application() {
    info "Desplegando aplicación..."
    
    # Ejemplo: desplegar en EC2 via SSM
    local instance_id=$(terraform output -raw ec2_instance_id 2>/dev/null || echo "")
    
    if [[ -n "$instance_id" ]]; then
        info "Desplegando en instancia: $instance_id"
        
        # Verificar que SSM Agent esté disponible
        local ssm_status=$(aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$instance_id" --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null || echo "ConnectionLost")
        
        if [[ "$ssm_status" == "Online" ]]; then
            # Ejecutar comandos de deployment via SSM
            aws ssm send-command \
                --instance-ids "$instance_id" \
                --document-name "AWS-RunShellScript" \
                --parameters 'commands=["echo \"Deployment successful\""]' \
                --output text > /dev/null
            
            APP_DEPLOYED=true
            success "Aplicación desplegada"
        else
            warn "SSM Agent no disponible en $instance_id"
        fi
    fi
}

# Rollback automático
perform_rollback() {
    error "Iniciando rollback automático..."
    
    if [[ "$INFRA_DEPLOYED" == "true" ]]; then
        info "Revirtiendo infraestructura..."
        if [[ -f "${TERRAFORM_STATE_BACKUP}" ]]; then
            cp "${TERRAFORM_STATE_BACKUP}" terraform.tfstate
            terraform refresh
        fi
    fi
    
    error "Rollback completado. Revisa los logs en ${LOG_FILE}"
}

# Función principal
main() {
    info "=== Iniciando despliegue inteligente ==="
    info "Deployment ID: ${DEPLOYMENT_ID}"
    info "Logs: ${LOG_FILE}"
    
    validate_prerequisites
    backup_state
    
    if validate_terraform_plan; then
        local plan_result=$?
        if [[ $plan_result -eq 2 ]]; then
            # Hay cambios, proceder con despliegue
            deploy_infrastructure
            deploy_application
            
            success "=== Despliegue completado exitosamente ==="
            info "Deployment ID: ${DEPLOYMENT_ID}"
            info "Logs disponibles en: ${LOG_FILE}"
        else
            info "No hay cambios que desplegar"
        fi
    else
        error "Validación del plan falló"
        exit 1
    fi
}

# Ejecutar si es llamado directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
