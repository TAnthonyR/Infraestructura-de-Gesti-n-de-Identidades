# Proyecto 2: Infraestructura de Gestión de Identidades 

## Descripción
Este proyecto implementa un prototipo de **Servicio de Directorio y Autenticación Centralizada** bajo el dominio `areinoso.com`. El sistema integra múltiples servicios Open Source para proporcionar una infraestructura segura donde los usuarios pueden autenticarse en diferentes nodos utilizando una única identidad (Single Sign-On).

### Arquitectura de Servicios
El sistema orquesta los siguientes componentes:
1.  **BIND9 (DNS):** Resolución de nombres y localización de servicios (Registros SRV).
2.  **Chrony (NTP):** Sincronización de tiempo estricta para evitar ataques de repetición.
3.  **OpenLDAP:** Directorio backend que almacena usuarios, grupos y atributos (UID/GID).
4.  **MIT Kerberos V5:** Sistema de autenticación seguro mediante tickets (TGT/TGS).
5.  **SSSD:** Cliente que integra el sistema operativo (PAM/NSS) con LDAP y Kerberos.

---

## Instrucciones de Instalación

Instalación de Infraestructura
Se utiliza el script `ReinosoA-Proyecto2.sh` para instalar paquetes base y configurar la red (DNS, NTP, Hosts).

1.  **Ejecutar el instalador:**
    ```bash
    chmod +x ReinosoA-Proyecto2.sh
    sudo ./ReinosoA-Proyecto2.sh
    ```
    *El script mostrará en pantalla el progreso de la instalación de los paquetes.*

---
## Configuración y Uso

Para asegurar que los servicios base se inicialicen correctamente, realice estos pasos manuales una única vez:

### A. Inicializar LDAP (slapd)
Este paso crea la estructura raíz del directorio.
1.  Ejecuta: `sudo dpkg-reconfigure slapd`
2.  Configuración aplicada:
    * ¿Omitir la configuración del servidor?: **No**
    * Nombre del dominio DNS: **areinoso.com**
    * Nombre de la organización: **FIS**
    * Contraseña de administrador: **cd2025**
    * ¿Borrar la base de datos al purgar?: **No**
    * ¿Mover la base de datos antigua?: **Sí**

### B. Inicializar Kerberos
Este paso crea la base de datos de autenticación.
1.  Ejecuta: `sudo krb5_newrealm`
2.  Contraseña maestra KDC: **cd2025**

---

## Habilitar SSO en SSH (GSSAPI)
**IMPORTANTE:** Habilita la autenticación por tickets en el servicio SSH.

1.  **Instalar el servidor SSH:**
    ```bash
    sudo apt-get install openssh-server -y
    ```

2.  **Activar GSSAPI (Copiar y pegar en terminal):**
    ```bash
    # Configurar Servidor (Aceptar tickets)
    sudo sed -i 's/#GSSAPIAuthentication no/GSSAPIAuthentication yes/g' /etc/ssh/sshd_config
    sudo sed -i 's/GSSAPIAuthentication no/GSSAPIAuthentication yes/g' /etc/ssh/sshd_config
    echo "GSSAPICleanupCredentials yes" | sudo tee -a /etc/ssh/sshd_config

    # Configurar Cliente (Enviar tickets)
    sudo sed -i 's/#   GSSAPIAuthentication no/    GSSAPIAuthentication yes/g' /etc/ssh/ssh_config
    echo "    GSSAPIDelegateCredentials yes" | sudo tee -a /etc/ssh/ssh_config

    # Reiniciar servicio
    sudo systemctl restart ssh
    ```

---
## Creación de Usuarios y Datos

### 1. Poblar el Directorio (LDAP)
Cargar el archivo `.ldif` incluido en la carpeta `data/`.
```bash
# Password: cd2025
ldapadd -x -D "cn=admin,dc=areinoso,dc=com" -W -f data/base_datos.ldif
```
### 2. Registrar Principales (Kerberos)
Entrar a la consola de administración: `sudo kadmin.local`.

Dentro ejecutamos lo siguiente:
```bash
# Crear usuario areinoso
addprinc areinoso

# Crear y exportar la llave del servidor
addprinc -randkey host/krb5.areinoso.com
ktadd host/krb5.areinoso.com

# Salir
quit
```
### 3. Cambio de hostname 

Una vez terminada la configuracion realizar el cambio del hostname de la maquina con el siguiente comando:
```bash
sudo hostname krb5.areinoso.com
```

### 4. Validación del Servicio
Para verificar que la infraestructura funciona correctamente:

* **Prueba de Directorio (LDAP):**
    Comprobar si el sistema reconoce al usuario remoto.
    ```bash
    getent passwd areinoso
    # Salida esperada: (cambiar)areinoso:*:20002:7000:Anthony Reinoso:/home/areinoso:/bin/bash
    ```

* **Prueba de Autenticación (Kerberos):**
    Obtener un ticket manual.
    ```bash
    kinit areinoso
    klist
    # Salida esperada: Default principal: areinoso@AREINOSO.COM
    ```

* **Prueba de Single Sign-On (SSH):**
    Para verificar la autenticación sin contraseña (Kerberos), el procedimiento varía según el cliente:

    **A. Desde Linux / WSL (Interno)**
    ```bash
    # Debe ingresar automáticamente si tiene ticket (kinit)
    ssh areinoso@krb5.areinoso.com
    ```

---

## 🔧 Archivos de Configuración Clave
Los siguientes archivos son modificados automáticamente por el script, pero se documentan aquí como referencia técnica:

* `/etc/hosts`: Mapeo estático para resolución canónica del KDC.
* `/etc/bind/db.areinoso.com`: Zona DNS con registros SRV (`_kerberos`, `_ldap`).
* `/etc/sssd/sssd.conf`: Configuración del cliente para usar LDAP como proveedor de ID y Kerberos como proveedor de Auth.

## ⚠️ Solución de Problemas Comunes

* **Error de Reloj (Clock Skew):** Kerberos falla si la hora difiere más de 5 minutos. Ejecutar `sudo chronyc makestep` para forzar la sincronización.