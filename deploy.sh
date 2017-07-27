#!/usr/bin/env bash

# Application name, please set
APPLICATION_NAME='resizer-web' # Use hyphens - only as symbols, no _ underscores (NIRD convention)
GIT_REPO_NAME='resizer-web' # Git repo name, matches the dir name

# Colors for cosmetics
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "=================${YELLOW} Deployment Steps =================="
echo -e " 1.) ${YELLOW}Download CLI"
echo -e " 2.) ${YELLOW}Login to CF"
echo -e " 3.) ${YELLOW}CD into app and remove vendor/bundle dir"
echo -e " 4.) ${YELLOW}Rename old application and push new one"
echo -e " 5.) ${YELLOW}Set env vars for new application"
echo -e " 6.) ${YELLOW}Start new application"
echo -e " 7.) ${YELLOW}Remove old application"
echo -e " 8.) ${YELLOW}Deploy finished"

function rollback {
    cf delete $APPLICATION_NAME -f
    cf rename ${APPLICATION_NAME}-old $APPLICATION_NAME
}

echo -e "${YELLOW}Starting deployment of $ACTUAL_BRANCH"

######################
# CLI SETUP
######################
echo -e "${GREEN}[+] Download Cli"
cd ../
wget -qO cf-linux-amd64.tgz 'https://cli.run.pivotal.io/stable?release=linux64-binary&source=github' && \
  tar -xf cf-linux-amd64.tgz && \
  rm cf-linux-amd64.tgz
export PATH=$PATH:$PWD

######################
# CF LOGIN
######################
echo -e "${GREEN}[+] CF Login"
cf api "$CF_API_URL"
cf login -u "$CF_USER" -p "$CF_PASS" -o "$CF_ORG" -s "$ACTUAL_BRANCH"

######################
# APP BACKUP AND PUSH
######################
echo -e "${GREEN}[+] Pushing application"
cd - # Go back to the application's folder

echo -e "configuring bin directory"
cat > ./bin/env <<-'EOF'
#!/bin/bash
export HOME=/app
. "${HOME}/.profile.d"/*ruby.sh
cd "${HOME}"
exec $*
EOF
chmod +x ./bin/env

rm -rf vendor/bundle
cf rename $APPLICATION_NAME ${APPLICATION_NAME}-old
if ! cf push $APPLICATION_NAME -f ./${ACTUAL_BRANCH}-manifest.yml --no-start; then
    echo -e "${RED}[-] Application could not be pushed, rolling back..."
    rollback
    exit -1;
fi

######################
# APP START
######################
echo -e "${GREEN}[+] Starting application"
if ! cf start $APPLICATION_NAME; then
    echo -e "${RED}[-] Application could not be started, rolling back..."
    rollback
    exit -1;
fi

######################
# CLEANUP
######################
cf delete ${APPLICATION_NAME}-old -f

cf logout
echo -e "${GREEN}[+] Deploy Complete"

exit 0
