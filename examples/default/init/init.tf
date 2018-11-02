locals {
  tags = {
    terraform   = "true"
    environment = "example"
    application = "sonarqube"
  }
}

module "sonarqube-init" {
  prefix = "sonarqube"
  source = "../../../init"
  tags   = "${local.tags}"
}
