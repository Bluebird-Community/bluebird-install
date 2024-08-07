#!/usr/bin/env bash
#
# Script to bootstrap a basic Bluebird Core setup

set -eEuo pipefail
trap 's=$?; echo >&2 "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

# Default build identifier set to stable
DEBIAN_FRONTEND=noninteractive
ERROR_LOG="bootstrap.log"
POSTGRES_USER="postgres"
POSTGRES_PASS=""
DB_NAME="bluebird"
DB_USER="bluebird"
DB_PASS="bluebird"
BLUEBIRD_CORE_HOME="/usr/share/opennms"
ANSWER="No"
RED="\e[31m"
GREEN="\e[32m"
ENDCOLOR="\e[0m"

REQUIRED_SYSTEMS="Ubuntu|Debian"
REQUIRED_JDK="openjdk-17-jdk"

# Error codes
E_ILLEGAL_ARGS=126
E_BASH=127
E_UNSUPPORTED=128

####
# Help function used in error messages and -h option
usage() {
  echo ""
  echo "Bootstrap Bluebird Core setup on Debian based system."
  echo ""
  echo "-h: Show this help"
}

checkRequirements() {
  echo "#############"
  echo "🪺 Welcome to the Bluebird Core installer 👋"
  echo "##########"
  echo ""

  # Test if system is supported
  DISTRO_CHECK="$(command -v lsb_release 1>>"${ERROR_LOG}" 2>>"${ERROR_LOG}")"
  if [[ -z "${DISTRO_CHECK}" ]]; then
    DISTRO_CHECK="$(command -v uname)"
  fi

  if ! "${DISTRO_CHECK}" -a | grep -E "${REQUIRED_SYSTEMS}" 1>>"${ERROR_LOG}" 2>>"${ERROR_LOG}" && [[ ! -e /etc/debian_version ]]; then
    echo ""
    echo "This is system is not a supported Ubuntu or Debian system."
    echo ""
    exit "${E_UNSUPPORTED}"
  fi

  # The sudo command is required to switch to postgres user for DB setup
  if ! command -v sudo 1>>"${ERROR_LOG}" 2>"${ERROR_LOG}"; then
    echo ""
    echo "This script requires sudo which could not be found."
    echo "Please install the sudo package."
    echo ""
    exit "${E_BASH}"
  fi
}

showDisclaimer() {
  echo ""
  echo "This script installs Bluebird Core on a clean system with the following."
  echo "components:"
  echo ""
  echo " - Installing installer dependencies curl, gnupg2, apt-transport-https"
  echo " - OpenJDK Development Kit"
  echo " - PostgreSQL Server"
  echo " - Initializing database access with credentials"
  echo " - Bluebird Repositories"
  echo " - Bluebird Core services with the web application"
  echo " - Initializing and bootstrapping the Bluebird database schema"
  echo " - Start Bluebird Core"
  echo ""
  echo "If you have Bluebird Core already installed, don't use this script!"
  echo ""
  echo "If you get any errors during the install procedure please visit the"
  echo "bootstrap.log where you can find detailed error messages for"
  echo "diagnose and bug reporting."
  echo ""
  echo "Bugs or enhancements can be reported here:"
  echo ""
  echo " - https://github.com/Bluebird-Community/opennms-install/issues -"
  echo ""
  read -r -p "If you want to proceed, type YES: " ANSWER

  # Set bash to case insensitive
  shopt -s nocasematch

  if [[ "${ANSWER}" == "yes" ]]; then
    echo ""
    echo "🚀 Starting setup procedure"
    echo ""
  else
    echo ""
    echo "Your system is unchanged."
    echo "Thank you for computing with us"
    echo ""
    exit "${E_BASH}"
  fi

  # Set case sensitive
  shopt -u nocasematch
}

####
# The -r option is optional and allows to set the release of Bluebird.
# The -m option allows to overwrite the package repository server.
while getopts h flag; do
  case "${flag}" in
    h)
      usage
      exit "${E_ILLEGAL_ARGS}"
      ;;
    *)
      usage
      exit "${E_ILLEGAL_ARGS}"
      ;;
  esac
done

####
# Helper function which tests if a command was successful or failed
checkError() {
  if [[ "${1}" -eq 0 ]]; then
    echo -e "[ ${GREEN}OK${ENDCOLOR} ]"
  else
    echo -e "[ ${RED}FAILED${ENDCOLOR} ]"
    exit "${E_BASH}"
  fi
}

prepare() {
  echo "Authenticate with sudo                ... "
  sudo echo -n "" 2>>"${ERROR_LOG}"
  checkError "${?}"
  echo -n "Update APT cache                      ... "
  sudo apt-get update 1>>"${ERROR_LOG}" 2>>"${ERROR_LOG}"
  checkError "${?}"

  # Ensure curl, gnupg2 abd apt-transport-https is available
  echo -n "Install dependencies                  ... "
  sudo apt-get -y install gnupg2 curl apt-transport-https 1>>"${ERROR_LOG}" 2>>"${ERROR_LOG}"
  checkError "${?}"
}

####
# Helper to request Postgres credentials to initialize the
# Bluebird database.
queryDbCredentials() {
  echo ""
  echo "Set a Postgres root password"
  echo ""
  while true; do
    read -r -s -p "New postgres password: " POSTGRES_PASS
    echo ""
    read -r -s -p "Confirm postgres password: " POSTGRES_PASS_CONFIRM
    echo ""
    if [ ! -z "${POSTGRES_PASS}" ]; then
      [ "${POSTGRES_PASS}" = "${POSTGRES_PASS_CONFIRM}" ] && break
      echo "Password confirmation didn't match, please try again."
    else
      echo "Password for the PostgreSQL user can't be empty. Please set a password."
    fi
    echo ""
  done
  echo ""
  echo ""
  echo "Create Bluebird Core database with user credentials"
  echo ""
  read -r -p    "Database name for Bluebird Core (default: bluebird): " DB_NAME
  DB_NAME="${DB_NAME:-bluebird}"
  read -r -p    "User for the database (default: bluebird): " DB_USER
  DB_USER="${DB_USER:-bluebird}"
  while true; do
    read -r -s -p "New password: " DB_PASS
    echo ""
    read -r -s -p "Confirm password: " DB_PASS_CONFIRM
    echo ""
    if [ ! -z "${DB_PASS}" ]; then
      [ "${DB_PASS}" = "${DB_PASS_CONFIRM}" ] && break
      echo "Password confirmation didn't match, please try again."
    else
      echo "Password for the Bluebird Core database user can't be empty. Please set a password."
    fi
    echo ""
  done
  echo ""
}

setDbCredentials() {
  echo -n "Enable SCRAM-SHA-256 in PostgreSQL    ... "
  sudo -i -u postgres psql -c "ALTER SYSTEM SET password_encryption = 'scram-sha-256';" 1>"${ERROR_LOG}" 2>>"${ERROR_LOG}"
  checkError "${?}"
  echo -n "Restart PostgreSQL Server             ... "
  sudo systemctl restart postgresql 1>"${ERROR_LOG}" 2>>"${ERROR_LOG}"
  checkError "${?}"
  echo -n "Create database and users             ... "
  {
    sudo -i -u postgres psql -c "ALTER USER postgres WITH PASSWORD '${POSTGRES_PASS}';"
    sudo -i -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';"
    sudo -i -u postgres psql -c "GRANT CREATE ON SCHEMA public TO PUBLIC;"
    sudo -i -u postgres psql -c "CREATE DATABASE ${DB_NAME} WITH OWNER ${DB_USER} ENCODING UTF8 TEMPLATE template0;"
  } 1>"${ERROR_LOG}" 2>>"${ERROR_LOG}"
  checkError "${?}"
}

####
# Install OpenJDK Development kit
installJdk() {
  # Test if a OpenJDK 17 Development Kit is installed
  echo -n "Install OpenJDK Development Kit       ... "
  if ! apt list --installed 2>>"${ERROR_LOG}" | grep "${REQUIRED_JDK}" 1>>"${ERROR_LOG}" 2>>"${ERROR_LOG}"; then
    sudo apt-get install -y --no-install-recommends ${REQUIRED_JDK} 1>>"${ERROR_LOG}" 2>>"${ERROR_LOG}"
    checkError "${?}"
  else
    echo "[ SKIP ] Already installed"
  fi
}

####
# Install the PostgreSQL database
installPostgres() {
  echo -n "Install PostgreSQL database           ... "
  sudo apt-get install -y postgresql 1>>"${ERROR_LOG}" 2>>"${ERROR_LOG}"
  checkError "${?}"
}

####
# Install Bluebird Debian repository for specific release
installRepo() {
  echo "Install Bluebird Repository              ... "
  curl -1sLf 'https://dl.cloudsmith.io/public/bluebird/develop/setup.deb.sh' | sudo -E bash
  curl -1sLf 'https://dl.cloudsmith.io/public/bluebird/common/setup.deb.sh' | sudo -E bash
}

####
# Install the Bluebird Core application from Debian repository
installCore() {
  echo -n "Install Bluebird Core packages        ... "
  sudo apt-get install -y -qq rrdtool jrrd2 jicmp jicmp6 opennms opennms-webapp-hawtio 2>>"${ERROR_LOG}"
  sudo -u opennms "${BLUEBIRD_CORE_HOME}"/bin/runjava -s 1>>"${ERROR_LOG}" 2>>"${ERROR_LOG}"
  checkError "${?}"
}

####
# Generate Bluebird configuration file for accessing the PostgreSQL
# Database with credentials
setCredentials() {
  echo ""
  echo -n "Create secure vault for Postgres      ... "
  sudo -u opennms ${BLUEBIRD_CORE_HOME}/bin/scvcli set postgres "${DB_USER}" "${DB_PASS}" 1>/dev/null 2>>"${ERROR_LOG}"
  sudo -u opennms ${BLUEBIRD_CORE_HOME}/bin/scvcli set postgres-admin "${POSTGRES_USER}" "${POSTGRES_PASS}" 1>/dev/null 2>>"${ERROR_LOG}"
  checkError "${?}"
  echo -n "Generate Bluebird database config     ... "
  if [[ -f "${BLUEBIRD_CORE_HOME}"/etc/opennms-datasources.xml ]]; then
    printf '<?xml version="1.0" encoding="UTF-8"?>
<datasource-configuration xmlns:this="http://xmlns.opennms.org/xsd/config/opennms-datasources"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://xmlns.opennms.org/xsd/config/opennms-datasources
  http://www.opennms.org/xsd/config/opennms-datasources.xsd ">

  <connection-pool factory="org.opennms.core.db.HikariCPConnectionFactory"
      idleTimeout="600"
      loginTimeout="3"
      minPool="25"
      maxPool="50"
      maxSize="50" />

  <jdbc-data-source name="opennms"
                    database-name="%s"
                    class-name="org.postgresql.Driver"
                    url="jdbc:postgresql://localhost:5432/%s"
                    user-name="${scv:postgres:username}"
                    password="${scv:postgres:password}" />

  <jdbc-data-source name="opennms-admin"
                    database-name="template1"
                    class-name="org.postgresql.Driver"
                    url="jdbc:postgresql://localhost:5432/template1"
                    user-name="${scv:postgres-admin:username}"
                    password="${scv:postgres-admin:password}">
    <connection-pool idleTimeout="600"
                     minPool="0"
                     maxPool="10"
                     maxSize="50" />
  </jdbc-data-source>

  <jdbc-data-source name="opennms-monitor"
                    database-name="postgres"
                    class-name="org.postgresql.Driver"
                    url="jdbc:postgresql://localhost:5432/postgres"
                    user-name="${scv:postgres-admin:username}"
                    password="${scv:postgres-admin:password}">
    <connection-pool idleTimeout="600"
                     minPool="0"
                     maxPool="10"
                     maxSize="50" />
  </jdbc-data-source>
</datasource-configuration>' "${DB_NAME}" "${DB_NAME}" \
  | sudo -u opennms tee "${BLUEBIRD_CORE_HOME}"/etc/opennms-datasources.xml 1>>/dev/null 2>>"${ERROR_LOG}"
  checkError "${?}"
  else
    echo "No Bluebird configuration found in ${BLUEBIRD_CORE_HOME}/etc"
    exit "${E_ILLEGAL_ARGS}"
  fi
}

####
# Initialize the Bluebird database schema
initializeDb() {
  echo -n "Initialize Bluebird                   ... "
  sudo "${BLUEBIRD_CORE_HOME}"/bin/install -dis 1>>"${ERROR_LOG}" 2>>"${ERROR_LOG}"
  checkError "${?}"
  echo -n "Set RRDTool as time series backend    ... "
  printf 'org.opennms.rrd.strategyClass=org.opennms.netmgt.rrd.rrdtool.MultithreadedJniRrdStrategy
org.opennms.rrd.interfaceJar=/usr/share/java/jrrd2.jar
opennms.library.jrrd2=/usr/lib/jni/libjrrd2.so
org.opennms.web.graphs.engine=rrdtool
rrd.binary=/usr/bin/rrdtool\n' | sudo -u opennms tee ${BLUEBIRD_CORE_HOME}/etc/opennms.properties.d/rrdtool-backend.properties 1>>/dev/null 2>>"${ERROR_LOG}"
  checkError "${?}"
}

restartCore() {
  echo -n "Starting Bluebird Core                ... "
  sudo systemctl start opennms 1>>"${ERROR_LOG}" 2>>"${ERROR_LOG}"
  checkError "${?}"
  echo -n "Bluebird systemd enable               ... "
  sudo systemctl enable opennms 1>>"${ERROR_LOG}" 2>>"${ERROR_LOG}"
  checkError "${?}"
}

lockdownDbUser() {
  echo -n "PostgreSQL revoke super user role     ... "
  sudo -i -u postgres psql -c "ALTER ROLE \"${DB_USER}\" NOSUPERUSER;" 1>>"${ERROR_LOG}" 2>>${ERROR_LOG}
  checkError "${?}"
  echo -n "PostgreSQL revoke create db role      ... "
  sudo -i -u postgres psql -c "ALTER ROLE \"${DB_USER}\" NOCREATEDB;" 1>>"${ERROR_LOG}" 2>>${ERROR_LOG}
  checkError "${?}"
}

# Execute setup procedure
clear
checkRequirements
showDisclaimer
prepare
installJdk
installPostgres
queryDbCredentials
setDbCredentials
installRepo
installCore
setCredentials
initializeDb
lockdownDbUser
restartCore

echo ""
echo "Congratulations"
echo "---------------"
echo ""
echo "Bluebird Core is starting up and might take a few seconds. You can access the"
echo "web application with"
echo ""
echo "  http://$(hostname -I | awk '{print $1}'):8980"
echo ""
echo "Login with username admin and password admin"
echo ""
echo "Please change immediately the password for your admin user!"
echo "Select in the main navigation \"Admin\" and go to \"Change Password\""
echo ""
echo "🦄 Thank you for computing with us. ✨"
echo ""
