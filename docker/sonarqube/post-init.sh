#!/bin/bash
HEALTH=`curl -sL -w "%{http_code}\\n" ${API_URL}/system/status -o /dev/null`
API_URL='http://localhost:9000/api'

KEYS=(
  "key=sonar.core.serverBaseURL&value=${SONARQUBE_BASE_URL}"
  "key=sonar.auth.github.enabled&value=${SONARQUBE_GITHUB_AUTH_ENABLED}"
  "key=sonar.auth.github.clientId.secured&value=${SONARQUBE_GITHUB_CLIENT_ID}"
  "key=sonar.auth.github.clientSecret.secured&value=${SONARQUBE_GITHUB_CLIENT_SECRET}"
  "key=sonar.auth.github.organizations&values=${SONARQUBE_GITHUB_ORGANIZATIONS}"
)

while [[ $HEALTH -ne "200" ]] ; do
  sleep 300 ; HEALTH=`curl -sL -w "%{http_code}\\n" ${API_URL}/system/status -o /dev/null`
done

for SET in "${KEYS[@]}" ; do
  curl -u admin:admin -H 'Content-Type: application/x-www-form-urlencoded' -X POST -d '${set}' ${API_URL}/settings/set
done

   curl -u admin:admin -H "Content-Type: application/x-www-form-urlencoded" -X POST -d "login=${SONARQUBE_ADMIN_USERNAME}&name=Admin&password=${SONARQUBE_ADMIN_PASSWORD}&password_confirmation=${SONARQUBE_ADMIN_PASSWORD}" ${API_URL}/users/create \
&& curl -u admin:admin -H "Content-Type: application/x-www-form-urlencoded" -X POST -d "name=sonar-administrators&login=${SONARQUBE_ADMIN_USERNAME}" ${API_URL}/user_groups/add_user                                                                 \
&& curl -u ${SONARQUBE_ADMIN_USERNAME}:${SONARQUBE_ADMIN_PASSWORD}  -H "Content-Type: application/x-www-form-urlencoded" -X POST -d "login=admin" ${API_URL}/users/deactivate
