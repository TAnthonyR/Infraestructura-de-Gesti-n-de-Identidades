#!/bin/bash

# ====================================================
# PROYECTO 2: Instalador de Infraestructura Base
# Estudiante: Anthony Reinoso
# ====================================================

# --- VARIABLES ---
DOMINIO="areinoso.com"
REALM="AREINOSO.COM"

# Colores
VERDE='\033[0;32m'
AZUL='\033[0;34m'
AMARILLO='\033[1;33m'
NC='\033[0m'

# --- DETECCIÓN DE ENTORNO ---
HOSTNAME_SVR=$(hostname)
IP_SVR=$(hostname -I | awk '{print $1}')

clear
echo -e "${AZUL}====================================================${NC}"
echo -e "${AZUL}   INSTALADOR DE INFRAESTRUCTURA (DNS/SSSD/NTP)     ${NC}"
echo -e "${AZUL}====================================================${NC}"
echo -e "Host: ${AMARILLO}$HOSTNAME_SVR${NC}"
echo -e "IP:   ${AMARILLO}$IP_SVR${NC}"

# 1. ACTUALIZAR E INSTALAR
echo -e "\n${AZUL}[1/4] Actualizando lista de paquetes...${NC}"
# Se quitó "> /dev/null" para que veas el proceso
sudo apt-get update

echo -e "\n${AZUL}[INFO] Configurando respuestas automáticas para Kerberos...${NC}"
# Pre-configuración para evitar preguntas bloqueantes (esto sigue oculto para no estorbar)
export DEBIAN_FRONTEND=noninteractive
echo "krb5-config krb5-config/default_realm string $REALM" | sudo debconf-set-selections
echo "krb5-config krb5-config/kerberos_servers string $HOSTNAME_SVR.$DOMINIO" | sudo debconf-set-selections
echo "krb5-config krb5-config/admin_server string $HOSTNAME_SVR.$DOMINIO" | sudo debconf-set-selections

echo -e "\n${AZUL}>>> INSTALANDO PAQUETES (BIND9, LDAP, KRB5, SSSD) <<<${NC}"
# AQUÍ ESTÁ EL CAMBIO: Se eliminó el silencio. Ahora verás todo el proceso.
sudo apt-get install -y bind9 bind9utils bind9-doc chrony slapd ldap-utils krb5-kdc krb5-admin-server sssd-ldap sssd-krb5 sssd-tools libpam-sss libnss-sss

echo -e "${VERDE}✔ Paquetes instalados correctamente.${NC}"

# 2. CONFIGURACIÓN DE RED (HOSTS)
echo -e "\n${AZUL}[2/4] Configurando /etc/hosts...${NC}"
# Eliminamos configuración vieja si existe
sudo sed -i "/$DOMINIO/d" /etc/hosts
# Agregamos la linea correcta
echo "$IP_SVR krb5.$DOMINIO $HOSTNAME_SVR.$DOMINIO $DOMINIO $HOSTNAME_SVR" | sudo tee -a /etc/hosts
echo -e "${VERDE}✔ Hosts actualizado.${NC}"

# 3. CONFIGURACIÓN DNS (BIND9)
echo -e "\n${AZUL}[3/4] Configurando DNS...${NC}"
cat <<EOF | sudo tee /etc/bind/named.conf.local
zone "$DOMINIO" { type master; file "/etc/bind/db.$DOMINIO"; };
EOF

cat <<EOF | sudo tee /etc/bind/db.$DOMINIO
; BIND data file for $DOMINIO
\$TTL    604800
@       IN      SOA     $HOSTNAME_SVR.$DOMINIO. root.$DOMINIO. ( 2 604800 86400 2419200 604800 )
@       IN      NS      $HOSTNAME_SVR.$DOMINIO.
@       IN      A       $IP_SVR
$HOSTNAME_SVR    IN      A       $IP_SVR
krb5    IN      A       $IP_SVR
_kerberos._udp  IN      SRV     0 0 88 krb5.$DOMINIO.
_kerberos._tcp  IN      SRV     0 0 88 krb5.$DOMINIO.
_ldap._tcp      IN      SRV     0 0 389 $HOSTNAME_SVR.$DOMINIO.
EOF
sudo systemctl restart bind9
echo -e "${VERDE}✔ DNS Reiniciado.${NC}"

# 4. CONFIGURACIÓN SSSD (Cliente)
echo -e "\n${AZUL}[4/4] Configurando SSSD...${NC}"
sudo rm -f /etc/sssd/sssd.conf
cat <<EOF | sudo tee /etc/sssd/sssd.conf
[sssd]
services = nss, pam
config_file_version = 2
domains = $DOMINIO

[domain/$DOMINIO]
id_provider = ldap
auth_provider = krb5
ldap_uri = ldap://$IP_SVR
ldap_search_base = dc=areinoso,dc=com
ldap_id_use_start_tls = false
ldap_tls_reqcert = never
ldap_schema = rfc2307
krb5_server = $IP_SVR
krb5_realm = $REALM
enumerate = true
cache_credentials = true
EOF

sudo chmod 600 /etc/sssd/sssd.conf
sudo chown root:root /etc/sssd/sssd.conf
sudo systemctl restart sssd
echo -e "${VERDE}✔ SSSD Reiniciado.${NC}"

echo -e "\n${AZUL}====================================================${NC}"
echo -e "${VERDE} INFRAESTRUCTURA LISTA ${NC}"
echo -e "${AZUL}====================================================${NC}"
echo "Siguientes pasos (Ver README.md):"
echo "1. Configurar LDAP:   sudo dpkg-reconfigure slapd"
echo "2. Crear Kerberos:    sudo krb5_newrealm"
echo "3. Cargar Usuarios:   ldapadd -x -D ... -f data/base_datos.ldif"
echo "4. Crear Principals:  sudo kadmin.local"
