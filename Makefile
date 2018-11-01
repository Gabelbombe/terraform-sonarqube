ROLE 					?= default


###############################################
# Global Variables
# - Setup and templating variables
###############################################

SHELL 				:= /bin/bash
CHDIR_SHELL 	:= $(SHELL)
OS						:= darwin

ACCOUNT_ID  	:= $(SHELL aws sts --profile $(ROLE) get-caller-identity --output text --query 'Account')

BASE_DIR			:= $(SHELL pwd)
STATE_DIR 		:= $(BASE_DIR)/_states
LOGS_DIR			:= $(BASE_DIR)/_logs
KEYS_DIR			:= $(BASE_DIR)/_keys




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
	$(call chdir, module)




###############################################
# Generic functions
# - follows standard design patterns
###############################################
graph: .source-dir
	terraform graph |dot -Tpng >| $(LOGS_DIR)/graph.png

clean:
	@rm -rf .terraform
	@rm -f $(LOGS_DIR)/graph.png
	@rm -f $(LOGS_DIR)/*.log


###############################################
# Testing functions
# - follows standard design patterns
###############################################

## Generic test until I move it over to Rake
default: test

test:
	@echo "== Test =="
	@if ! terraform fmt -write=false -check=true >> /dev/null; then 							\
		echo "✗ terraform fmt failed: $$d"; 																				\
		exit 1; 																																		\
	else 																																					\
		echo "√ terraform fmt"; 																										\
	fi
	@for d in $$(find . -type f -name '*.tf' -path "./modules/*" -not -path "**/.terraform/*" -exec dirname {} \; | sort -u); do \
		cd $$d; 																																		\
		terraform init -backend=false >> /dev/null; 																\
		terraform validate -check-variables=false; 																	\
		if [ $$? -eq 1 ]; then 																											\
			echo "✗ terraform validate failed: $$d"; 																	\
			exit 1; 																																	\
		fi; 																																				\
	done
	@echo "√ terraform validate modules (not including variables)"
	@for d in $$(find . -type f -name '*.tf' -path "./examples/*" -not -path "**/.terraform/*" -exec dirname {} \; | sort -u); do \
		cd $$d; 																																		\
		terraform init -backend=false >> /dev/null; 																\
		terraform validate; 																												\
		if [ $$? -eq 1 ]; then 																											\
			echo "✗ terraform validate failed: $$d"; 																	\
			exit 1; 																																	\
		fi; 																																				\
	done
	@echo "√ terraform validate examples"

.PHONY: default test



###############################################
# Deployment functions
# - follows standard design patterns
###############################################


# Add your build functions here...


module_name-destroy: .source-dir .check-region
	echo -e "\n\n\n\nmodule_name-destroy: $(date +"%Y-%m-%d @ %H:%M:%S")\n" 			\
		>> $(LOGS_DIR)/module_name-destroy.log
	terraform init 2>&1 |tee $(LOGS_DIR)/module_name-init.log
	terraform destroy 																														\
		-state=$(STATE_DIR)/$(ACCOUNT_ID)/${REGION}-module_name.tfstate 						\
		-var region="${REGION}" 																										\
		-auto-approve																																\
	2>&1 |tee $(LOGS_DIR)/module_name-destroy.log


module_name-purge: module_name-destroy clean
	@rm -f $(STATE_DIR)/$(ACCOUNT_ID)/${REGION}-module_name.tfstate
	@rm -f $(KEYS_DIR)/*$(ACCOUNT_ID)-${REGION}*
