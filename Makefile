ROLE          ?= default ## make {func} ROLE=<AWS_ACCOUNT_ROLE>


###############################################
# Global Variables
# - Setup and templating variables
###############################################

SHELL         := /bin/bash
CHDIR_SHELL   := $(SHELL)
OS            := darwin

ACCOUNT_ID    := $(shell aws sts --profile $(ROLE) get-caller-identity --output text --query 'Account')

BASE_DIR      := $(shell pwd)
STATE_DIR     := $(BASE_DIR)/_states
LOGS_DIR      := $(BASE_DIR)/_logs
KEYS_DIR      := $(BASE_DIR)/_keys

## Default generic to test until I move it over to Rake
default: test


###############################################
# Helper functions
# - follows standard design patterns
###############################################
define chdir
	$(eval _D=$(firstword $(1) $(@D)))
	$(info $(MAKE): cd $(_D)) $(eval SHELL = cd $(_D); $(CHDIR_SHELL))
endef

.check-region:
	@if test "$(REGION)" = "" ; then echo "REGION not set"; exit 1; fi

.source-dir:
	$(call chdir, modules)

.assert-%:
	@if [ "${${*}}" = "" ]; then                                                  \
    echo "[✗] Variable ${*} not set"  ; exit 1                                ; \
	else                                                                          \
		echo "[√] ${*} set as: ${${*}}"                                           ; \
	fi



###############################################
# Generic functions
# - follows standard design patterns
###############################################
graph: .source-dir
	terraform init && terraform graph |dot -Tpng >| $(LOGS_DIR)/graph.png

clean: .source-dir
	@rm -rf .terraform
	@rm -f $(LOGS_DIR)/graph.png
	@rm -f $(LOGS_DIR)/*.log


###############################################
# Testing functions
# - follows standard design patterns
###############################################

test:
	@echo "[info] Testing Terraform"
	@if ! terraform fmt -write=false -check=true >> /dev/null; then               \
		echo "[✗] Terraform fmt failed: $$d"                                      ; \
		exit 1                                                                    ; \
	else                                                                          \
		echo "[√] Terraform fmt"                                                  ; \
	fi
	@for d in $$(find . -type f -name '*.tf' -path "./targets/*" -not -path "**/.terraform/*" -exec dirname {} \; | sort -u); do \
		cd $$d                                                                    ; \
		terraform init -backend=false >> /dev/null                                ; \
		terraform validate -check-variables=false                                 ; \
		if [ $$? -eq 1 ]; then 																											\
			echo "[✗] Terraform validate failed: $$d"; 																\
			exit 1; 																																	\
		fi; 																																				\
	done
	@echo "[√] terraform validate targets (not including variables)"
	@for d in $$(find . -type f -name '*.tf' -path "./examples/*" -not -path "**/.terraform/*" -exec dirname {} \; | sort -u); do \
		cd $$d; 																																		\
		terraform init -backend=false >> /dev/null; 																\
		terraform validate; 																												\
		if [ $$? -eq 1 ]; then 																											\
			echo "[✗] Terraform validate failed: $$d"; 																\
			exit 1; 																																	\
		fi; 																																				\
	done
	@echo "[√] Terraform validate examples"

.PHONY: default test



###############################################
# Deployment functions
# - follows standard design patterns
###############################################


# Add your build functions here...


target_name-destroy: .source-dir .check-region
	echo -e "\n\n\n\ntarget_name-destroy: $(date +"%Y-%m-%d @ %H:%M:%S")\n" 			\
		>> $(LOGS_DIR)/target_name-destroy.log
	terraform init 2>&1 |tee $(LOGS_DIR)/target_name-init.log
	aws-vault exec $(ROLE) --assume-role-ttl=60m -- terraform destroy 						\
		-state=$(STATE_DIR)/$(ACCOUNT_ID)/${REGION}-target_name.tfstate 						\
		-var region="${REGION}" 																										\
		-auto-approve																																\
	2>&1 |tee $(LOGS_DIR)/target_name-destroy.log


target_name-purge: target_name-destroy clean
	@rm -f $(STATE_DIR)/$(ACCOUNT_ID)/${REGION}-target_name.tfstate
	@rm -f $(KEYS_DIR)/*$(ACCOUNT_ID)-${REGION}*
