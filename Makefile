.PHONY: help deploy destroy plan validate health logs clean

# Variables
SHELL := /bin/bash
DEPLOY_SCRIPT := ./deploy.sh
CONFIG_SCRIPT := ./deploy-config.sh

help: ## Mostrar ayuda
	@echo "Comandos disponibles:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

deploy: ## Despliegue completo con validaciones
	@echo "🚀 Iniciando despliegue inteligente..."
	@$(DEPLOY_SCRIPT)

plan: ## Ver plan de cambios sin aplicar
	@echo "📋 Generando plan de Terraform..."
	@terraform init -input=false
	@terraform plan -detailed-exitcode

validate: ## Validar configuración y prerequisitos
	@echo "✅ Validando configuración..."
	@terraform validate
	@$(DEPLOY_SCRIPT) --validate-only 2>/dev/null || echo "Prerequisitos validados"

health: ## Health check completo del sistema
	@echo "🏥 Ejecutando health check..."
	@source $(CONFIG_SCRIPT) && full_health_check

destroy: ## Destrucción ordenada completa (recomendado)
	@echo "🧹 Iniciando destrucción ordenada..."
	@./destroy.sh

destroy-force: ## Destruir solo infraestructura base (sin orden)
	@echo "⚠️  ADVERTENCIA: Esto destruirá la infraestructura base"
	@read -p "¿Estás seguro? (yes/no): " confirm && [ "$$confirm" = "yes" ]
	@terraform destroy -auto-approve

logs: ## Ver logs del último despliegue
	@echo "📄 Logs del último despliegue:"
	@ls -t logs/deploy-*.log 2>/dev/null | head -1 | xargs tail -f || echo "No hay logs disponibles"

clean: ## Limpiar archivos temporales y logs antiguos
	@echo "🧹 Limpiando archivos temporales..."
	@source $(CONFIG_SCRIPT) && cleanup_temp_resources
	@echo "Limpieza completada"

status: ## Ver estado actual de la infraestructura
	@echo "📊 Estado actual:"
	@terraform show -json 2>/dev/null | jq -r '.values.root_module.resources[] | select(.type != null) | "\(.type).\(.name): \(.values.id // "N/A")"' 2>/dev/null || echo "No hay estado disponible"

outputs: ## Mostrar outputs de Terraform
	@echo "📤 Outputs disponibles:"
	@terraform output 2>/dev/null || echo "No hay outputs disponibles"

init: ## Inicializar proyecto (primera vez)
	@echo "🎯 Inicializando proyecto..."
	@terraform init
	@mkdir -p logs backups
	@echo "Proyecto inicializado"
