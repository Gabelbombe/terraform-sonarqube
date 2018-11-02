#!/bin/bash
chown -R sonarqube:sonarqube $SONARQUBE_HOME

[ -z "$AWS_REGION" ] && [ -z "$AWS_DEFAULT_REGION" ] && {
  export AWS_REGION="eu-west-1"
}

exec gosu sonarqube ./start-with-params.sh
