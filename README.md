# Proyecto 2: Infraestructura de Gestión de Identidades (IdM)

**Estudiante:** Anthony Reinoso  
**Materia:** Fundamentos de Infraestructura  
**Estado:** Finalizado / Funcional

## 📋 Descripción
Este proyecto implementa un prototipo de **Servicio de Directorio y Autenticación Centralizada** bajo el dominio `areinoso.com`. El sistema integra múltiples servicios Open Source para proporcionar una infraestructura segura donde los usuarios pueden autenticarse en diferentes nodos utilizando una única identidad (Single Sign-On).

### Arquitectura de Servicios
El sistema orquesta los siguientes componentes:
1.  **BIND9 (DNS):** Resolución de nombres y localización de servicios (Registros SRV).
2.  **Chrony (NTP):** Sincronización de tiempo estricta para evitar ataques de repetición.
3.  **OpenLDAP:** Directorio backend que almacena usuarios, grupos y atributos (UID/GID).
4.  **MIT Kerberos V5:** Sistema de autenticación seguro mediante tickets (TGT/TGS).
5.  **SSSD:** Cliente que integra el sistema operativo (PAM/NSS) con LDAP y Kerberos.

---

## 🚀 Instrucciones de Instalación

### Prerrequisitos
* Sistema Operativo: Ubuntu 20.04 / 22.04 LTS (WSL o Máquina Virtual).
* Privilegios de `root` o `sudo`.

### Despliegue Automatizado
Se ha incluido un script `bash` que automatiza la instalación de paquetes, configuración de archivos y carga inicial de datos.

1.  **Clonar el repositorio:**
    ```bash
    git clone [https://github.com/TAnthonyR/Profesionalismo.git](https://github.com/TAnthonyR/Profesionalismo.git)
    cd Profesionalismo
    ```

2.  **Dar permisos de ejecución:**
    ```bash
    chmod +x ReinosoA-Proyecto2.sh
    ```

3.  **Ejecutar el instalador:**
    ```bash
    sudo ./ReinosoA-Proyecto2.sh
    ```
    *El script detectará automáticamente si los paquetes ya están instalados. Si es la primera vez, instalará y configurará todo el entorno.*

---

## ⚙️ Configuración y Uso

Una vez finalizada la ejecución del script, el sistema estará operativo. A continuación se detallan los pasos para administrar y validar el servicio.

### 1. Gestión de Usuarios (LDAP + Kerberos)
El script crea automáticamente un usuario de prueba: **`jrueda`**.

Para agregar nuevos usuarios manualmente:
1.  Crear el usuario en LDAP (archivo `.ldif`):
    ```bash
    ldapadd -x -D "cn=admin,dc=areinoso,dc=com" -W -f nuevo_usuario.ldif
    ```
2.  Registrar el principal en Kerberos:
    ```bash
    sudo kadmin.local -q "addprinc nuevo_usuario"
    ```

### 2. Validación del Servicio
Para verificar que la infraestructura funciona correctamente:

* **Prueba de Directorio (LDAP):**
    Comprobar si el sistema reconoce al usuario remoto.
    ```bash
    getent passwd jrueda
    # Salida esperada: jrueda:*:20002:7000:Jhoann Rueda:/home/jrueda:/bin/bash
    ```

* **Prueba de Autenticación (Kerberos):**
    Obtener un ticket manual.
    ```bash
    kinit jrueda
    klist
    # Salida esperada: Default principal: jrueda@AREINOSO.COM
    ```

* **Prueba de Single Sign-On (SSH):**
    Conectarse al servidor usando el nombre canónico (FQDN). No debería pedir contraseña si ya existe un ticket válido.
    ```bash
    ssh jrueda@krb5.areinoso.com
    ```

---

## 🔧 Archivos de Configuración Clave
Los siguientes archivos son modificados automáticamente por el script, pero se documentan aquí como referencia técnica:

* `/etc/hosts`: Mapeo estático para resolución canónica del KDC.
* `/etc/bind/db.areinoso.com`: Zona DNS con registros SRV (`_kerberos`, `_ldap`).
* `/etc/sssd/sssd.conf`: Configuración del cliente para usar LDAP como proveedor de ID y Kerberos como proveedor de Auth.
* `/etc/krb5.conf`: Definición del Realm `AREINOSO.COM`.

## ⚠️ Solución de Problemas Comunes
* **Error "Name or service not known" en SSH:** Verificar que `/etc/hosts` tenga la IP correcta apuntando a `krb5.areinoso.com`.
* **Error de Reloj (Clock Skew):** Kerberos falla si la hora difiere más de 5 minutos. Ejecutar `sudo chronyc makestep` para forzar la sincronización.