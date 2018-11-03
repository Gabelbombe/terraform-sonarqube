locals {
  tags = {
    terraform   = "true"
    environment = "example"
    application = "sonarqube"
  }
}

module "sonarqube-init" {
  name_prefix = "sonarqube"
  source      = "../../../modules/init"
  tags        = "${local.tags}"
}
