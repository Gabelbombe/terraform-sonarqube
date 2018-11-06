ROLE          ?= 'default'     ## make {func} ROLE=<AWS_ACCOUNT_ROLE>
REGION        ?= 'us-east-1'   ## make {func} REGION=<AWS_TARGET_REGION>


###############################################
# Global Variables
# - Setup and templating variables
###############################################

SHELL         := /bin/bash
CHDIR_SHELL   := $(SHELL)
OS            := darwin

BASE_DIR      := $(shell pwd)
#ACCOUNT_ID    := $(shell aws sts --profile $(ROLE) get-caller-identity --output text --query 'Account')
INVENTORY     := $(shell which terraform-inventory |awk '{print$3}')

STATE_DIR     := $(BASE_DIR)/_states
LOGS_DIR      := $(BASE_DIR)/_logs
KEYS_DIR      := $(BASE_DIR)/_keys

MODULE        := $(BASE_DIR)/modules
ANSIBLE       := $(BASE_DIR)/ansible

## Example directories for all prerequisites
DEFAULT       := $(BASE_DIR)/examples/default
INIT          := $(BASE_DIR)/examples/default/init



## Default generics to test until I move it over to Rake
default: test
all:     sonarqube provision
rebuild: destroy all


###############################################
# Helper functions
# - follows best practices design patterns
###############################################
define chdir
	$(eval _D=$(firstword $(1) $(@D)))
	$(info $(MAKE): cd $(_D)) $(eval SHELL = cd $(_D); $(CHDIR_SHELL))
endef

.check-region:
	@if test "$(REGION)" = ""; then  echo "REGION not set"; exit 1; fi

.check-role:
	@if test "$(ROLE)" = ""; then  echo "ROLE not set"; exit 1; fi

.directory-%:
	$(call chdir, ${${*}})

.assert-%:
	@if [ "${${*}}" = "" ]; then                                                  \
    echo "[✗] Variable ${*} not set"  ; exit 1                                ; \
	else                                                                          \
		echo "[√] ${*} set as: ${${*}}"                                           ; \
	fi

.roles: .directory-ANSIBLE
	[[ `ls roles/*/ 2>/dev/null` ]] && rm -fr roles/*                           ; \
	sed -e "s/<SSH_KEYFILE>/$(ROLE)/" ansible.tmpl.cfg >| ansible.cfg           ; \
	ansible-galaxy install -r requirements.yml


###############################################
# Generic functions
###############################################
graph: .directory-MODULE
	terraform init && terraform graph |dot -Tpng >| $(LOGS_DIR)/graph.png

clean:
	@rm -rf $(TERRAFORM)/.terraform
	@rm -f  $(LOGS_DIR)/graph.png
	@rm -f  $(LOGS_DIR)/*.log

globals:
	@echo "REGION set to: $(REGION)"
	@echo "ROLE   set to: $(ROLE)"

###############################################
# Testing functions
# - follow testing design patterns
###############################################

test:
	@echo 'No tests currently configured...'


###############################################
# Deployment functions
# - follows deployment patterns
###############################################

init: .directory-MODULE
	terraform init

preflight-init: .directory-INIT .check-region
	terraform init                                                                \
	&& aws-vault exec $(ROLE) --assume-role-ttl=60m -- terraform plan             \
		-var region=$(REGION)                                                       \
		-var key_name=$(ROLE)                                                       \
	2>&1 |tee $(LOGS_DIR)/pre-plan.log                                          ; \
                                                                                \
	aws-vault exec $(ROLE) --assume-role-ttl=60m -- terraform apply               \
		-state=$(STATE_DIR)/$(ROLE)-pre_terraform.tfstate                           \
		-var region=$(REGION)                                                       \
		-var key_name=$(ROLE)                                                       \
		-auto-approve                                                               \
	2>&1 |tee $(LOGS_DIR)/pre-apply.log

preflight-output:
	@if [ ! -f "$(STATE_DIR)/$(ROLE)-pre_terraform.tfstate" ]; then make pre-build ROLE=$(ROLE) ; fi
	export ARN=$(shell terraform output -state=$(STATE_DIR)/$(ROLE)-pre_terraform.tfstate |awk -F ' = ' '{print$$2}') \
	echo $(ARN)




sonarqube: init .directory-MODULE .check-region
	aws-vault exec $(ROLE) --assume-role-ttl=60m -- terraform plan                \
		-var region=$(REGION)                                                       \
		-var key_name=$(ROLE)                                                       \
	2>&1 |tee $(LOGS_DIR)/sonarqube-plan.log                                    ; \
                                                                                \
	aws-vault exec $(ROLE) --assume-role-ttl=60m -- terraform apply               \
		-state=$(STATE_DIR)/$(ROLE)_terraform.tfstate                               \
		-var region=$(REGION)                                                       \
		-var key_name=$(ROLE)                                                       \
		-auto-approve                                                               \
	2>&1 |tee $(LOGS_DIR)/sonarqube-apply.log


destroy: init .directory-MODULE .check-region
	@echo -e "\n\n\n\nsonarqube-destroy: $(date +"%Y-%m-%d @ %H:%M:%S")\n"        \
		>> $(LOGS_DIR)/sonarqube-destroy.log
	aws-vault exec $(ROLE) --assume-role-ttl=60m -- terraform destroy             \
		-state=$(STATE_DIR)/$(ROLE)_terraform.tfstate                               \
		-var region=$(REGION)		                                                    \
		-var key_name=$(ROLE)                                                       \
		-auto-approve                                                               \
	2>&1 |tee $(LOGS_DIR)/sonarqube-destroy.log


ssh: .directory-MODULE
	exec `terraform output -state=$(STATE_DIR)/$(ROLE)_terraform.tfstate          \
	|head -1 |awk -F' = ' '{print$$2}' |sed 's/.\//..\//'`
