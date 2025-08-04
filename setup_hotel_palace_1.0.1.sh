#!/bin/bash

# Palace 1.0.1 - Esta es la versión de codigo que tiene el Hotel Palace para el mando bluetooth.

# [01]: Parametros.
# [02]: Funciones.
# [03]: Comprobaciones.
# [04]: Instalar dependencias.
# [05]: Instalar Teclado Virtual 2.0
# [06]: Registrando / Actualizando STB en el Almacen.
# [07]: Descargar archivos de git.
# [08]: Mover cada archivo.
# [09]: Dar permisos a los scripts y crear entornos virtuales.
# [10]: Instalación y configuración de Data Dinamica + Imagenes.
# [11]: Instalar Cursor.
# [12]: Habilitar servicios.
# [13]: Crontab.
# [14]: Descargar juegos y activar vpn.
# [15]: Configurando control remoto.
# [16]: Configuraciones del sistema.

# Alerta de permisos sudo.
if [ "$(id -u)" -ne 0 ]; then
    echo "Este script debe ejecutarse con privilegios de sudo."
    exit 1
fi

# Obtener el usuario original y su directorio home
if [ -n "$SUDO_USER" ]; then
    USER="$SUDO_USER"
    HOME_DIR=$(eval echo ~$SUDO_USER)
else
    USER=$(whoami)
    HOME_DIR=$HOME
fi


# [01]: Parametros.
cliente='Royal blue bird, s.l.'
instalacion='El Palace'
grupo='Habitaciones'
estancia='stb-alexis-testing'

hotel_colon_ssid='TORNAVICA'
hotel_colon_password='18745924'

ping_URL_internet="google.com"
ping_URL_puerta_enlace="192.168.1.1"
ping_URL_dominio="server.panoram4.com"
pc_impresora="192.168.1.39"

git_username="joelsegoviacrespo"
git_token="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"

HOME_DIR="/home/panoram4"


# [02]: Funciones.
run_as_root() {
    if [ "$EUID" -ne 0 ]; then
        sudo "$@"
    else
        "$@"
    fi
}

consultar_grupo() {
    local api_url="$1"

    response=$(wget -qO- "$api_url")

    if [ "$response" == "true" ]; then
        echo "La respuesta es true. Continuando con el script."
    else
        echo "La respuesta es false. Terminando el script."
        exit 1
    fi
}

set_estancia() {
    while true; do
        echo -e "\r\n\n - Por favor, ingrese la estancia al que pertenece el stb: \r\n"
        read estancia

        if [ -n "$estancia" ]; then
            break
        else
            echo "La estancia no puede estar vacío. ¡Inténtalo de nuevo!"
        fi
    done

    instalacion_modificada=$(echo "$instalacion" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')

    serial="serial_${instalacion_modificada}_${estancia}"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

get_bluetooth_address() {
    BLUETOOTH_ADDRESS=$(hcitool dev | awk '$0=$2')

    if [ -z "$BLUETOOTH_ADDRESS" ]; then
        BLUETOOTH_ADDRESS="00:00:00:00:00:00"
    fi
}

convert_address_to_hex() {
    HEX_SALT=$(echo -n "$BLUETOOTH_ADDRESS" | xxd -p)
}

convertir_a_mayusculas() {
    texto="$1"
    mayusculas=$(echo "$texto" | tr '[:lower:]' '[:upper:]')
    echo "$mayusculas"
}

obtener_contrasena_api() {
    contrasena=$(curl -s "$API_URL" | jq -r '.[0].password')
    echo "$contrasena"
}

wayvnc_sshd_config() {
    local setting="$1"
    local value="$2"

    if grep -q "^#\s*$setting\s" "/etc/ssh/sshd_config"; then
        run_as_root sed -i "s/^#\s*$setting\s.*/$setting $value/" "/etc/ssh/sshd_config"
        echo "Descomentado $setting en /etc/ssh/sshd_config"
    elif ! grep -q "^$setting\s" "/etc/ssh/sshd_config"; then
        echo "$setting $value" | run_as_root tee -a "/etc/ssh/sshd_config" >/dev/null
        echo "Añadido $setting al final de /etc/ssh/sshd_config"
    else
        echo "$setting ya está configurado correctamente."
    fi
}

check_connectivity() {
    local url="$1"
    echo "Comprobando conectividad a $url..."

    if ping -c 4 -W 5 "$url" >/dev/null 2>&1; then
        echo -e "\r\nConectividad a $url: OK"
    else
        echo -e "\r\nError: No hay conectividad a $url."
        exit 1
    fi
}

clear && echo -e "\r\n\n Bienvenido al instalador de $instalacion \r\n"

#set_estancia

# Deshabilitar reinicios automáticos durante la instalación.
run_as_root sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'a'"'"';/g' /etc/needrestart/needrestart.conf
printf "\n" | run_as_root apt-get install --yes --force-yes libc6

echo "intel-microcode intel-microcode/license/accepted select true" | sudo debconf-set-selections
echo "needrestart needrestart/restart string a" | sudo debconf-set-selections
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# [03]: Comprobaciones.
echo -e "\r\n\r\n\n\n\n[1/54] ############### Comprobando la conexión a internet ###############\r\n"
check_connectivity "$ping_URL_internet"

echo -e "\r\n\r\n\n\n\n[2/54] ############### Comprobando la conexión a la puerta de enlace ###############\r\n"
#check_connectivity "$ping_URL_puerta_enlace"

echo -e "\r\n\r\n\n\n\n[3/54] ############### Comprobando la conexión a server.panoram4.com ###############\r\n"
#check_connectivity "$ping_URL_dominio"

echo -e "\r\n\r\n\n\n\n[4/54] ############### Comprobando la conexión al pc de la impresora ###############\r\n"
#check_connectivity "$pc_impresora"

ping 8.8.8.8 > /dev/null 2>&1 &

echo -e "\r\n\r\n\n\n\n[5/54] ############### Comprobando si el STB ya existe ###############\r\n"

run_as_root apt install -y jq wireless-tools bluez

# Obtener la MAC de la interfaz de red (formato en mayúsculas).
mac=$(LANG=C ip link show | awk '/link\/ether/ {print $2}' | head -n 1)

if [ -z "$mac" ]; then
    echo "El dispositivo no tiene acceso a la MAC. Deteniendo el script."
    exit 1
else
    mac=$(echo "$mac" | tr '[:lower:]' '[:upper:]')
fi

# Obtener la MAC de la interfaz Bluetooth.
#mac_bluetooh=$(hcitool dev | awk 'NR==2 {print $2}')
mac_bluetooh="00:00:00:00:00:00"

if [ -z "$mac_bluetooh" ]; then
    echo "El dispositivo no posee MAC bluetooh. Deteniendo el script."
    exit 1
fi

# Construir URL de la API para comprobar si el STB ya existe.
url_check_if_exists="https://stblinuxhospitality.panoram4.com/api/stb/info/$mac/$mac_bluetooh"

# Hacer la petición a la API y capturar tanto la respuesta como el código HTTP.
response_check_if_exists=$(mktemp)
http_code=$(curl -s -w "%{http_code}" -o "$response_check_if_exists" "$url_check_if_exists")

# Evaluar si el STB fue encontrado.
if [ "$http_code" = "404" ]; then
    echo -e "\r\n\r\n\n\n\nEl STB no existe. Continuando...\r\n"
else
    echo -e "\r\n\r\n\n\n\nEl STB existe. Deteniendo el script.\r\n"
    exit 1
fi

# Eliminar archivo temporal con la respuesta de la API.
rm -f "$response_check_if_exists"


echo -e "\r\n\r\n\n\n\n[6/54] ############### Actualizando los repositorios ###############\r\n"
run_as_root apt update

# Creación de usuario Panoram4.
usuario="panoram4"

# Comprobar si el usuario existe.
if id "$usuario" &>/dev/null; then
    echo -e "\r\n\r\n\n\n\nEl usuario $usuario ya existe.\r\n"
else
    # Crear el usuario.
    echo -e "\r\n\n\n\n############### Creación de Usuario ###############\r\n"
    run_as_root useradd -m -s /bin/bash "$usuario"

    echo -e "\r\n\n\n\n############### Permisos de usuario ###############\r\n"
    run_as_root usermod -aG sudo "$usuario"
fi


# [04]: Instalar dependencias.

# Descargar y guardar la clave GPG del repositorio de Brave en el sistema.
run_as_root curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg

# Agregar el repositorio de Brave al sistema con la clave firmada.
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | run_as_root tee /etc/apt/sources.list.d/brave-browser-release.list

# Aceptar automáticamente la licencia EULA de Microsoft Core Fonts.
echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | run_as_root debconf-set-selections

DEPENDENCIAS_1=(
    alsa-base
    alsa-utils
    autossh
    build-essential
    cage
    cargo
    check
    cmake
    curl
    dkms
    dnsmasq
    evtest
    expect
    ffmpeg
    fonts-arabeyes
    fonts-arphic-ukai
    fonts-arphic-uming
    fonts-crosextra-caladea
    fonts-crosextra-carlito
    fonts-dejavu-core
    fonts-hosny-amiri
    fonts-kacst
    fonts-liberation
    fonts-sil-scheherazade
    fonts-takao
    fonts-wqy-microhei
    fonts-wqy-zenhei
    git
    hostapd
    imagemagick
    inotify-tools
    inxi
    iw
    libavahi-compat-libdnssd1
    libdbus-1-dev
    libevdev-dev
    libevdev2
    libglib2.0-0
    libglib2.0-dev
    libnm-dev
    libnl-3-dev
    libreadline-dev
    libssl-dev
    libsystemd-dev
    libtool
    mame
    meson
    mpv
    net-tools
    network-manager
    openvpn
    plymouth
    plymouth-themes
    portaudio19-dev
    p7zip-full
    pulseaudio
    python3-pip
    python3-pyaudio
    python3-virtualenv
    python3.11-venv
    qrencode
    sed
    sshpass
    swayimg
    sysstat
    ttf-mscorefonts-installer
    unclutter-xfixes
    unzip
    wayland-protocols
    wayvnc
    wlr-randr
    wmctrl
    wpasupplicant
    xdotool
    xorg
    xwayland
)

DEPENDENCIAS_2=(
    eog
    gstreamer1.0-libav
    gstreamer1.0-plugins-bad
    gstreamer1.0-plugins-good
    gstreamer1.0-plugins-ugly
    gstreamer1.0-plugins-base
    imagemagick
    qrencode
    sed
    unclutter-xfixes
)

DEPENDENCIAS_3=(
    gstreamer1.0-alsa
    gstreamer1.0-libav
    gstreamer1.0-plugins-bad
    gstreamer1.0-plugins-base
    gstreamer1.0-plugins-good
    gstreamer1.0-plugins-ugly
    gstreamer1.0-tools
    libgstreamer1.0-dev
)

echo -e "\r\n\n\n\n[7/54] ############### Actualizando lista de paquetes... ###############\r\n"

run_as_root apt update && run_as_root apt upgrade -y

run_as_root add-apt-repository -y ppa:apt-fast/stable && run_as_root apt update

echo apt-fast apt-fast/aptmanager select apt | run_as_root debconf-set-selections
echo apt-fast apt-fast/confirm-true boolean true | run_as_root debconf-set-selections
echo apt-fast apt-fast/maxdownloads string 15 | run_as_root debconf-set-selections
echo apt-fast apt-fast/dlmanager select aria2 | run_as_root debconf-set-selections
echo apt-fast apt-fast/dlflag boolean true | run_as_root debconf-set-selections

run_as_root apt install -y apt-fast

echo -e "\r\n\n\n\n[8/54] ############### Instalando dependencias... ###############\r\n"

run_as_root apt-fast install -y "${DEPENDENCIAS_1[@]}"
run_as_root apt-get install -y "${DEPENDENCIAS_2[@]}"
apt install -y "${DEPENDENCIAS_3[@]}"
run_as_root snap install fast

echo iptables-persistent iptables-persistent/autosave_v4 boolean true | run_as_root debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | run_as_root debconf-set-selections

run_as_root env DEBIAN_FRONTEND=noninteractive apt install -y iptables-persistent

run_as_root env DEBIAN_FRONTEND=noninteractive apt install -y msmtp

echo "postfix postfix/main_mailer_type select No configuration" | run_as_root debconf-set-selections

run_as_root env DEBIAN_FRONTEND=noninteractive apt install -y mailutils

echo -e "\r\n\n\n\nVerificando instalación...\r\n"
for paquete in "${DEPENDENCIAS_1[@]}"; do
    if dpkg -l | grep -qw "$paquete"; then
        echo "[OK] $paquete instalado correctamente."
    else
        echo "[ERROR] $paquete no se pudo instalar."
    fi
done

for paquete in "${DEPENDENCIAS_2[@]}"; do
    if dpkg -l | grep -qw "$paquete"; then
        echo "[OK] $paquete instalado correctamente."
    else
        echo "[ERROR] $paquete no se pudo instalar."
    fi
done

for paquete in "${DEPENDENCIAS_3[@]}"; do
    if dpkg -l | grep -qw "$paquete"; then
        echo "[OK] $paquete instalado correctamente."
    else
        echo "[ERROR] $paquete no se pudo instalar."
    fi
done

cd /home/panoram4
wget -nc https://server.panoram4.com/evsieve-1.4.0.tar.gz && tar -xzf evsieve-1.4.0.tar.gz
cd evsieve-1.4.0 && cargo build --release && run_as_root install -m 755 -t /usr/local/bin target/release/evsieve


# [05]: Instalar Teclado Virtual 2.0
echo -e "\r\n\n\n\n[9/54] ############### Descargando teclado de brave ###############\r\n"
cd /home/panoram4 && git clone https://$git_username:$git_token@github.com/JavierPanoram4/keyboard.git TecladoVirtual-2.0

run_as_root chown -R panoram4:panoram4 /home/panoram4/TecladoVirtual-2.0/

run_as_root chmod +x /home/panoram4/TecladoVirtual-2.0/*.sh

cd TecladoVirtual-2.0/Backend && rm -rf env && python3.11 -m venv env && source env/bin/activate

cat <<EOF | tee /home/panoram4/TecladoVirtual-2.0/requeriments.txt
websockets==15.0.1
python-uinput==1.0.1

EOF

cd /home/panoram4/TecladoVirtual-2.0

pip3 install -r requeriments.txt && deactivate

cat <<EOF | tee /etc/systemd/system/teclado_virtual.service
[Unit]
Description=Teclado Virtual Backend Service
After=network.target
[Service]
Type=simple
User=root
WorkingDirectory=/home/panoram4/TecladoVirtual-2.0
ExecStart=/home/panoram4/TecladoVirtual-2.0/Backend/env/bin/python /home/panoram4/TecladoVirtual-2.0/Backend/backend.py
StandardOutput=append:/home/panoram4/TecladoVirtual-2.0/keyboard.log
StandardError=append:/home/panoram4/TecladoVirtual-2.0/keyboard.log
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target

EOF


echo -e "\r\n\n\n\n[10/54] ############### Configurar plugin en brave ###############\r\n"
run_as_root rm -r /home/panoram4/.config/BraveSoftware
wget -nc "http://server.panoram4.com/palace/v1.0.1/Brave-Browser.tar.gz" -P /home/panoram4/.config/BraveSoftware
tar xvf /home/panoram4/.config/BraveSoftware/Brave-Browser.tar.gz -C /home/panoram4/.config/BraveSoftware

echo -e "\r\n\n\n\n[11/54] ############### Actualizando Brave ###############\r\n"

run_as_root apt upgrade -y brave-browser


# [06]: Registrando / Actualizando STB en el Almacen.
echo -e "\r\n\n\n\n[12/54] ############### Dando de alta el STB ###############\r\n"

# API: Consultar la existencia del grupo dado cliente, instalación y nombre del mismo.
url_api="https://stblinuxhospitality.panoram4.com/api/group/info/$cliente/$instalacion/$grupo"
consultar_grupo "$url_api"

url="https://stblinuxhospitality.panoram4.com/api/stb/habitacion-disponible/$cliente/$instalacion/$grupo/$estancia"

json_response=$(wget -qO- "$url")

# Extraer los valores de "success" y "room" usando jq.
success_value=$(echo "$json_response" | jq -r '.success')
room_value=$(echo "$json_response" | jq -r '.room')

# Version del OS.
descripcion_os=$(lsb_release -d | cut -f2-)

# Version del Kernel.
version_kernel=$(uname -r)

API_URL="https://passwordwolf.com/api/?length=16&special=1"

contrasena=$(obtener_contrasena_api)
echo "Tu contraseña segura de la API es: $contrasena"

machine_id=$(run_as_root cat /etc/machine-id)

# Crear el JSON.
if [ -n "$cliente" ] && [ -n "$instalacion" ] && [ -n "$grupo" ] && [ -n "$estancia" ] && [ -n "$serial" ]; then
    json_data='{"cliente":"'$cliente'","instalacion":"'$instalacion'","grupo":"'$grupo'","estancia":"'$estancia'","serial":"'$serial'","mac_address":"'$mac'","bluetooh_address":"'$mac_bluetooh'","os_version":"'$descripcion_os'","kernel":"'$version_kernel'","machine_id":"'$machine_id'","passwords":[{"password":"'$contrasena'","tipo":"ssh"}]}'
else
    json_data='{"mac_address":"'$mac'","bluetooh_address":"'$mac_bluetooh'","os_version":"'$descripcion_os'","kernel":"'$version_kernel'"}'
fi

echo $json_data

# Verificar el valor de "success" en un if.
if [ "$success_value" == "true" ]; then
    echo -e "\r\n\n\n\n[13/54] ############### Actualizando STB en el Almacen ###############\r\n"
    action="actualizado"
    wget --quiet --method=POST --body-data="${json_data}" --header="Content-Type:application/json" -O /home/panoram4/response.json https://stblinuxhospitality.panoram4.com/api/stb/config/update
    wget --quiet --method=POST --body-data="${json_data}" --header="Content-Type:application/json" -O /home/panoram4/response_pre.json https://stblinuxhospitalitypre.panoram4.com/api/stb/config/update
else
    echo -e "\r\n\n\n\n[13/54] ############### Registrando STB en el Almacen ###############\r\n"
    action="registrado"
    wget --quiet --method=POST --body-data="${json_data}" --header="Content-Type:application/json" -O /home/panoram4/response.json https://stblinuxhospitality.panoram4.com/api/stb/config/
    wget --quiet --method=POST --body-data="${json_data}" --header="Content-Type:application/json" -O /home/panoram4/response_pre.json https://stblinuxhospitalitypre.panoram4.com/api/stb/config/
fi

# Definir el nombre del archivo JSON.
json_file="/home/panoram4/response.json"

# Verificar si el archivo JSON existe.
if [ -f "$json_file" ]; then
    # Utilizar jq para contar la cantidad de elementos en el archivo JSON.
    json_count=$(jq length "$json_file")

    # Verificar si el archivo JSON esta vacio (count igual a 0).
    if [ "$json_count" -eq 0 ]; then
        echo "El registro o actualización no se ha realizado correctamente."
    else
        echo -e "\r\n\r\n\n\n\nSe ha $action el STB exitosamente...\r\n"
        echo -e "\r\n\n\n\n############### Descargando información del stb ###############\r\n"
        mkdir -p /home/panoram4/data
        wget -O /home/panoram4/data/info_stb_prod.json https://stblinuxhospitality.panoram4.com/api/stb/info/$mac/$mac_bluetooh
        wget -O /home/panoram4/data/info_stb.json https://stblinuxhospitalitypre.panoram4.com/api/stb/info/$mac/$mac_bluetooh
    fi
else
    echo "Ha ocurrido un problema durante el registro, vuelva a intentarlo"
fi


# [07]: Descargar archivos de git.
echo -e "\r\n\n\n\n[14/54] ############### Descargando archivos de Git ###############\r\n"

# Definir URL de autenticación para Git con usuario y token
GIT_AUTH_URL="https://${git_username}:${git_token}@github.com/JavierPanoram4/panoram4_versiones.git"

cd /home/panoram4

# Clonar el repositorio usando la URL autenticada.
git clone "$GIT_AUTH_URL"

# Cambiar al directorio clonado, salir si falla.
cd panoram4_versiones || exit 1

# Cambiar a la rama especificada.
git checkout palace_1.0.1

# Actualizar la URL remota para usar la autenticación.
git remote set-url origin "$GIT_AUTH_URL"


# [08]: Mover cada archivo.
echo -e "\r\n\n\n\n[15/54] ############### Moviendo los archivos de Git ###############\r\n"

cd /home/panoram4/panoram4_versiones/palace_1.0.1/respaldo/

run_as_root rm -r CAFile && run_as_root rm -r gamepad && run_as_root rm vigilar_gamepad_mapeo.sh && run_as_root rm detector_voz.py  

run_as_root chown -R panoram4:panoram4 /home/panoram4/panoram4_versiones/palace_1.0.1/respaldo/

run_as_root mv /home/panoram4/panoram4_versiones/palace_1.0.1/respaldo/* /home/panoram4

run_as_root mv -f /home/panoram4/panoram4_versiones/palace_1.0.1/opt/* /opt

run_as_root mv /home/panoram4/panoram4_versiones/palace_1.0.1/Servicios/* /etc/systemd/system

run_as_root mv /home/panoram4/panoram4_versiones/palace_1.0.1/crontab_panoram4 /home/panoram4

run_as_root mv /home/panoram4/panoram4_versiones/palace_1.0.1/crontab_root /home/panoram4

mkdir -p /home/panoram4/.config/mpv && run_as_root mv -f /home/panoram4/panoram4_versiones/palace_1.0.1/input.conf /home/panoram4/.config/mpv/input.conf

run_as_root chown -R panoram4:panoram4 /home/panoram4/.config/mpv

run_as_root mv /home/panoram4/panoram4_versiones/palace_1.0.1/.msmtprc /home/panoram4

mkdir -p /home/panoram4/.config/systemd/user

run_as_root mv /home/panoram4/panoram4_versiones/palace_1.0.1/mqtt_stb_action.service /home/panoram4/.config/systemd/user

run_as_root mv /home/panoram4/panoram4_versiones/palace_1.0.1/mute_control.service /home/panoram4/.config/systemd/user

run_as_root chown -R panoram4:panoram4 /home/panoram4/.config/systemd/user

# [09]: Dar permisos a los scripts y crear entornos virtuales.
echo -e "\r\n\n\n\n[16/54] ############### Configurando permisos y entorno virtual para client_generate_keys ###############\r\n"

cd /home/panoram4/client_generate_keys

virtualenv env && chown -R panoram4:panoram4 env && source env/bin/activate && pip3 install -r requirements.txt && deactivate


echo -e "\r\n\n\n\n[17/54] ############### Configurando permisos y entorno virtual para client_rport_panoram4 ###############\r\n"

cd /home/panoram4/client_rport_panoram4

run_as_root chmod +x *.sh

virtualenv env && chown -R panoram4:panoram4 env && source env/bin/activate && pip3 install -r requeriments.txt && deactivate


echo -e "\r\n\n\n\n[18/54] ############### Configurando permisos y entorno virtual para connection_data ###############\r\n"

cd /home/panoram4/connection_data

run_as_root chmod +x *.sh

virtualenv env && chown -R panoram4:panoram4 env && source env/bin/activate && pip3 install -r requirements.txt && deactivate


echo -e "\r\n\n\n\n[19/54] ############### Configurando permisos y entorno virtual para delete_stb_data ###############\r\n"

cd /home/panoram4/delete_stb_data

run_as_root chmod +x *.sh

virtualenv env && chown -R panoram4:panoram4 env && source env/bin/activate && pip3 install -r requirements.txt && deactivate


echo -e "\r\n\n\n\n[20/54] ############### Configurando entorno virtual para Panoram4 ###############\r\n"

cd /home/panoram4/dev-linux/Panoram4

virtualenv env && chown -R panoram4:panoram4 env && source env/bin/activate

pip3 install bson==0.5.8 && pip3 install pymongo==3.10.1

pip3 install -r requirements.txt && deactivate


echo -e "\r\n\n\n\n[21/54] ############### Configurando permisos y entorno virtual para generate_json ###############\r\n"

cd /home/panoram4/generate_json

run_as_root chmod +x *.sh

virtualenv env && chown -R panoram4:panoram4 env && source env/bin/activate && pip3 install -r requeriments.txt && deactivate


echo -e "\r\n\n\n\n[22/54] ############### Configurando permisos y entorno virtual para migrate_statistics ###############\r\n"

cd /home/panoram4/migrate_statistics

run_as_root chmod +x *.sh

virtualenv env && chown -R panoram4:panoram4 env && source env/bin/activate && pip3 install -r requirements.txt && deactivate


echo -e "\r\n\n\n\n[23/54] ############### Configurando permisos y entorno virtual para mqtt_stb_action ###############\r\n"

cd /home/panoram4/mqtt_stb_action

run_as_root chmod +x *.sh

virtualenv env && chown -R panoram4:panoram4 env && source env/bin/activate && pip3 install -r requirements.txt && deactivate


echo -e "\r\n\n\n\n[24/54] ############### Configurando permisos para network ###############\r\n"

cd /home/panoram4/network

run_as_root chmod +x *.sh


echo -e "\r\n\n\n\n[25/54] ############### Configurando permisos y entorno virtual para oracle_pms ###############\r\n"

cd /home/panoram4/oracle_pms

run_as_root chmod +x *.sh

virtualenv env && chown -R panoram4:panoram4 env && source env/bin/activate && pip3 install -r requirements.txt && deactivate


echo -e "\r\n\n\n\n[26/54] ############### Configurando permisos y entorno virtual para la vpn ###############\r\n"

cd /home/panoram4/vpn

run_as_root chmod +x *.sh


echo -e "\r\n\n\n\n[27/54] ############### Configurando permisos para /home/panoram4 ###############\r\n"

cd /home/panoram4

run_as_root chmod +x *.sh *.exp


echo -e "\r\n\n\n\n[28/54] ############### Configurando entorno virtual para accion_stb ###############\r\n"

cd /opt/accion_stb

virtualenv env && chown -R panoram4:panoram4 env && source env/bin/activate && pip3 install -r requeriments.txt && deactivate

run_as_root chmod +x /home/panoram4/.msmtprc && run_as_root chmod 600 /home/panoram4/.msmtprc



# [10]: Instalación y configuración de Data Dinamica + Imagenes.
echo -e "\r\n\n\n\n[29/54] ############### Instalación de Data Dinamica ###############\r\n"

cd /home/panoram4/generate_json/ && chmod +x *.sh && virtualenv env && source env/bin/activate && pip3 install -r requeriments.txt && deactivate && cd --

run_as_root chown -R panoram4:panoram4 /home/panoram4/generate_json/

mkdir -p /home/panoram4/data/images
cd /home/panoram4/data/images && wget -r -np -nH --cut-dirs=7 \
  -A jpg,jpeg,png,gif,webp,svg \
  "https://serverpre.panoram4.com/data/stb/Royal%20blue%20bird,%20s.l./El%20Palace/Habitaciones/images/"

cat <<EOF | tee /home/panoram4/acciones_post_instalacion.sh
#!/bin/bash

# Esperar a que el proceso "brave" esté corriendo (máximo 60 segundos)
timeout=60
echo "Esperando a que brave esté corriendo..."

while ! pgrep -x brave >/dev/null; do
    sleep 1
    timeout=\$((timeout - 1))
    if [ \$timeout -le 0 ]; then
        echo "Brave no se levantó a tiempo. Abortando."
        exit 1
    fi
done

echo "Brave detectado."

sleep 30

# Activar entorno y ejecutar migrate
cd /home/panoram4/dev-linux/Panoram4 || exit 1
source env/bin/activate
export DISPLAY=:0
python3 manage.py migrate &
sleep 5
deactivate && cd /home/panoram4

pkill -9 cage

systemctl disable acciones_post_instalacion.service
systemctl stop acciones_post_instalacion.service

# Borrarse a sí mismo
rm -- "\$(realpath "\$0")"
EOF

run_as_root chmod +x /home/panoram4/acciones_post_instalacion.sh

cat <<EOF | tee /etc/systemd/system/acciones_post_instalacion.service
[Unit]
Description=Ejecutar Django migrate una sola vez al iniciar
After=graphical-session.target

[Service]
Type=oneshot
User=panoram4
ExecStart=/home/panoram4/acciones_post_instalacion.sh
RemainAfterExit=no
Environment=DISPLAY=:0

[Install]
WantedBy=graphical.target

EOF

# [11]: Instalar Cursor.
echo -e "\r\n\n\n\n[30/54] ############### Instalación del cursor ###############\r\n"
mkdir -p /home/panoram4/.icons && unzip /home/panoram4/Cursores.zip -d /home/panoram4/.icons

mkdir -p /home/panoram4/.icons/CustomCursor && mv -f /home/panoram4/.icons/Cursores/* /home/panoram4/.icons/CustomCursor/ && rm -r /home/panoram4/.icons/Cursores/

cat <<EOF | tee /home/panoram4/.icons/CustomCursor/index.theme 
[Icon Theme]
Name=CustomCursor
Comment=Cursor customizado para stb
Inherits=Adwaita
EOF

cat <<EOF | tee /home/panoram4/startup_panoram4.sh
#!/bin/bash
export XCURSOR_PATH=/home/panoram4/.icons
export XCURSOR_THEME=CustomCursor
export XCURSOR_SIZE=128

echo "Xcursor.theme: CustomCursor" | xrdb -merge || true
echo "Xcursor.size: 128" | xrdb -merge || true

export DISPLAY=:0
export XDG_RUNTIME_DIR=/run/user/\$(id -u)

cd /home/panoram4/dev-linux/Panoram4
source env/bin/activate
python3 manage.py runserver 127.0.0.1:9090 &>/dev/null &
wlr-randr --output HDMI-A-1 --mode 1920x1080
wlr-randr --output HDMI-A-2 --mode 1920x1080

brave-browser --kiosk file:///home/panoram4/dev-linux/Panoram4/splash/index.html &

bash ~/configuracion_sonido.sh
pactl set-sink-volume @DEFAULT_SINK@ 100%

echo "off" > mirroring_ios_estado.txt
echo "off" > mirroring_android_estado.txt

exit 0

EOF

cd /home/panoram4/.icons/CustomCursor/cursors

for name in X_cursor default arrow watch wait none hand2; do
  ln -sf left_ptr "$name"
done

cat <<EOF | run_as_root tee /usr/share/icons/default/index.theme
[Icon Theme]
Inherits=CustomCursor
EOF

sudo ln -s /home/panoram4/.icons/CustomCursor /usr/share/icons/CustomCursor




echo -e "\r\n\n\n\n[31/54] ############### Creando archivos para reconexión automática de control remoto Bluetooth ###############\r\n"
cat <<EOF | run_as_root tee /home/panoram4/connect_controller.py
import subprocess
import time
import sys
import re
import os

if os.geteuid() != 0:
    print("Este script debe ejecutarse como root. Usa sudo.")
    sys.exit(1)

def validar_mac(mac):
    return re.match(r"^([0-9A-Fa-f]{2}:){5}([0-9A-Fa-f]{2})$", mac) is not None

def actualizar_mac_en_archivos(mac):
    archivos_a_actualizar = [
        "/etc/udev/rules.d/99-bt-autoconnect.rules",
        "/usr/local/bin/bluetooth-watchdog.sh",
        "localizacion.txt"
    ]

    patron_mac = r"(?:([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}|XX:XX:XX:XX:XX:XX)"

    for archivo in archivos_a_actualizar:
        try:
            with open(archivo, "r") as f:
                contenido = f.read()

            nuevo_contenido = re.sub(patron_mac, mac, contenido)

            with open(archivo, "w") as f:
                f.write(nuevo_contenido)

            print(f"MAC actualizada en {archivo}")
        except Exception as e:
            print(f"Error actualizando {archivo}: {e}")

    try:
        subprocess.run(["udevadm", "control", "--reload-rules"], check=True)
        subprocess.run(["udevadm", "trigger"], check=True)
        print("Reglas udev recargadas correctamente.")
    except subprocess.CalledProcessError as e:
        print(f"Error al aplicar reglas udev: {e}")

def buscar_y_conectar(controller_mac):
    try: output = proceso.stdout.readline().strip()
            if output:
                print(output)
                if "Connection successful" in output:
                    break

        # Confirmar estado final
        proceso.stdin.write('info\n')
        proceso.stdin.flush()
        time.sleep(2)

        paired = bonded = connected = False
        checks = 0

        while checks < 3:
            output = proceso.stdout.readline().strip()
            if output:
                print(output)
                if "Paired: yes" in output:
                    paired = True
                    checks += 1
                if "Connected: yes" in output:
                    connected = True
                    checks += 1
                if "Bonded: yes" in output or "WakeAllowed: yes" in output:
                    bonded = True
                    checks += 1

        if paired and connected:
            print("Controller conectado correctamente.")
            return True
        else:
            print("Controller no se conectó completamente.")
            return False

    except Exception as e:
        print(f"Error durante el proceso: {e}")
        return False

if __name__ == "__main__":
    if os.geteuid() != 0:
        print("Este script debe ejecutarse como root. Usa sudo.")
        sys.exit(1)

    if len(sys.argv) != 2:
        print("Uso: sudo python3 connect_controller.py <MAC_DEL_CONTROLLER>")
        sys.exit(1)

    mac = sys.argv[1].strip()

    if not validar_mac(mac):
        print("Dirección MAC inválida. Usa formato XX:XX:XX:XX:XX:XX")
        sys.exit(1)

    while True:
        if buscar_y_conectar(mac):
            actualizar_mac_en_archivos(mac)
            sys.exit(0)
        else:
            print("Reintentando conexión en 5 segundos...")
            time.sleep(5)
        proceso = subprocess.Popen(
            ['bluetoothctl'],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True,
            bufsize=1
        )

        proceso.stdin.write('power on\n')
        proceso.stdin.flush()

        proceso.stdin.write('scan on\n')
        proceso.stdin.flush()
        time.sleep(2)

        print(f"Esperando que el controller {controller_mac} aparezca...")

        encontrado = False
        timeout = time.time() + 30

        while time.time() < timeout:
            output = proceso.stdout.readline().strip()
            if output:
                print(output)
                if f'Device {controller_mac}' in output:
                    print(f"Controller encontrado: {output}")
                    encontrado = True
                    break

        if not encontrado:
            print("No se encontró el controller en el tiempo esperado.")
            return False

        proceso.stdin.write(f'pair {controller_mac}\n')
        proceso.stdin.flush()

        while True:
            output = proceso.stdout.readline().strip()
            if output:
                print(output)
                if "Accept pairing (yes/no):" in output:
                    proceso.stdin.write('yes\n')
                    proceso.stdin.flush()
                if "Pairing successful" in output:
                    break
                if "Failed to pair" in output or "Pairing failed" in output:
                    return False

        proceso.stdin.write(f'trust {controller_mac}\n')
        proceso.stdin.flush()

        while True:
            output = proceso.stdout.readline().strip()
            if output:
                print(output)
                if "trust succeeded" in output:
                    break

        proceso.stdin.write(f'connect {controller_mac}\n')
        proceso.stdin.flush()

        while True:
            output = proceso.stdout.readline().strip()
            if output:
                print(output)
                if "Connection successful" in output:
                    break

        # Confirmar estado final
        proceso.stdin.write('info\n')
        proceso.stdin.flush()
        time.sleep(2)

        paired = bonded = connected = False
        checks = 0

        while checks < 3:
            output = proceso.stdout.readline().strip()
            if output:
                print(output)
                if "Paired: yes" in output:
                    paired = True
                    checks += 1
                if "Connected: yes" in output:
                    connected = True
                    checks += 1
                if "Bonded: yes" in output or "WakeAllowed: yes" in output:
                    bonded = True
                    checks += 1

        if paired and connected:
            print("Controller conectado correctamente.")
            return True
        else:
            print("Controller no se conectó completamente.")
            return False

    except Exception as e:
        print(f"Error durante el proceso: {e}")
        return False

if __name__ == "__main__":
    if os.geteuid() != 0:
        print("Este script debe ejecutarse como root. Usa sudo.")
        sys.exit(1)

    if len(sys.argv) != 2:
        print("Uso: sudo python3 connect_controller.py <MAC_DEL_CONTROLLER>")
        sys.exit(1)

    mac = sys.argv[1].strip()

    if not validar_mac(mac):
        print("Dirección MAC inválida. Usa formato XX:XX:XX:XX:XX:XX")
        sys.exit(1)

    while True:
        if buscar_y_conectar(mac):
            actualizar_mac_en_archivos(mac)
            sys.exit(0)
        else:
            print("Reintentando conexión en 5 segundos...")
            time.sleep(5)

EOF


cat <<EOF | run_as_root tee /etc/bluetooth/main.conf
[General]
# Default adaper name
# Defaults to 'BlueZ X.YZ'
#Name = BlueZ

# Default device class. Only the major and minor device class bits are
# considered. Defaults to '0x000000'.
#Class = 0x000100

# How long to stay in discoverable mode before going back to non-discoverable
# The value is in seconds. Default is 180, i.e. 3 minutes.
# 0 = disable timer, i.e. stay discoverable forever
#DiscoverableTimeout = 0

# How long to stay in pairable mode before going back to non-discoverable
# The value is in seconds. Default is 0.
# 0 = disable timer, i.e. stay pairable forever
#PairableTimeout = 0

# Automatic connection for bonded devices driven by platform/user events.
# If a platform plugin uses this mechanism, automatic connections will be
# enabled during the interval defined below. Initially, this feature
# intends to be used to establish connections to ATT channels. Default is 60.
AutoConnectTimeout = 0

# Use vendor id source (assigner), vendor, product and version information for
# DID profile support. The values are separated by ":" and assigner, VID, PID
# and version.
# Possible vendor id source values: bluetooth, usb (defaults to usb)
#DeviceID = bluetooth:1234:5678:abcd

# Do reverse service discovery for previously unknown devices that connect to
# us. This option is really only needed for qualification since the BITE tester
# doesn't like us doing reverse SDP for some test cases (though there could in
# theory be other useful purposes for this too). Defaults to 'true'.
#ReverseServiceDiscovery = true

# Enable name resolving after inquiry. Set it to 'false' if you don't need
# remote devices name and want shorter discovery cycle. Defaults to 'true'.
#NameResolving = true

# Enable runtime persistency of debug link keys. Default is false which
# makes debug link keys valid only for the duration of the connection
# that they were created for.
#DebugKeys = false

# Restricts all controllers to the specified transport. Default value
# is "dual", i.e. both BR/EDR and LE enabled (when supported by the HW).
# Possible values: "dual", "bredr", "le"
ControllerMode = dual

# Enables Multi Profile Specification support. This allows to specify if
# system supports only Multiple Profiles Single Device (MPSD) configuration
# or both Multiple Profiles Single Device (MPSD) and Multiple Profiles Multiple
# Devices (MPMD) configurations.
# Possible values: "off", "single", "multiple"
#MultiProfile = off

# Permanently enables the Fast Connectable setting for adapters that
# support it. When enabled other devices can connect faster to us,
# however the tradeoff is increased power consumptions. This feature
# will fully work only on kernel version 4.1 and newer. Defaults to
# 'false'.
FastConnectable = true

[Policy]

# The ReconnectUUIDs defines the set of remote services that should try
# to be reconnected to in case of a link loss (link supervision
# timeout). The policy plugin should contain a sane set of values by
# default, but this list can be overridden here. By setting the list to
# empty the reconnection feature gets disabled.
ReconnectUUIDs=00001812-0000-1000-8000-00805f9b34fb

# ReconnectAttempts define the number of attempts to reconnect after a link
# lost. Setting the value to 0 disables reconnecting feature.
ReconnectAttempts=10

# ReconnectIntervals define the set of intervals in seconds to use in between
# attempts.
# If the number of attempts defined in ReconnectAttempts is bigger than the
# set of intervals the last interval is repeated until the last attempt.
ReconnectIntervals=5

# AutoEnable defines option to enable all controllers when they are found.
# This includes adapters present on start as well as adapters that are plugged
# in later on. Defaults to 'false'.
AutoEnable=true

EOF


cat <<EOF | run_as_root tee /etc/modprobe.d/bluetooth_disable_autosuspend.conf
options btusb enable_autosuspend=0
EOF


cat <<EOF | run_as_root tee /etc/udev/rules.d/99-bt-autoconnect.rules
SUBSYSTEM=="bluetooth", ATTR{address}=="XX:XX:XX:XX:XX:XX", ACTION=="add", RUN+="/usr/bin/bluetoothctl connect XX:XX:XX:XX:XX:XX"
EOF

cat <<EOF | run_as_root tee /etc/udev/rules.d/99-bluetooth-realtek-noautosuspend.rules
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0bda", ATTR{idProduct}=="c821", TEST=="power/control", ATTR{power/control}="on"
EOF

run_as_root  udevadm control --reload-rules && run_as_root udevadm trigger

echo 'on' | run_as_root tee /sys/bus/usb/devices/1-4/power/control && cat /sys/bus/usb/devices/1-4/power/control

cat <<EOF | tee /home/panoram4/localizacion.txt
MAC_ETH=$mac
MAC_BT=$mac_bluetooh
LOCALIZACION="$instalacion"
HABITACION="$estancia"
MANDO_BLUETOOTH=XX:XX:XX:XX:XX:XX
EOF


cat <<EOF | tee /home/panoram4/comprobar-mando.sh
#!/bin/bash

# Cargar variables desde el archivo de configuración
source /home/panoram4/localizacion.txt

# Comprobar si el mando está conectado
CONNECTED=\$(bluetoothctl info "\$MANDO_BLUETOOTH" | grep "Connected: yes")

# Si no está conectado, intenta reconectar
if [ -z "\$CONNECTED" ]; then
    echo -e "connect \$MANDO_BLUETOOTH\nquit" | bluetoothctl
fi

EOF

run_as_root chmod +x /home/panoram4/comprobar-mando.sh


cat <<EOF | run_as_root tee /usr/local/bin/bluetooth-watchdog.sh
#!/bin/bash

MAC="D2:36:74:16:BA:86"  # ← reemplaza por la MAC real
LOG="/var/log/bt-watchdog.log"

echo "\$(date) - Bluetooth watchdog iniciado para \$MAC" >> "\$LOG"

while true; do
    estado=\$(bluetoothctl info "\$MAC" | grep "Connected: yes")
    if [ -z "\$estado" ]; then
        echo "\$(date) - Mando no conectado. Intentando reconectar..." >> "\$LOG"
        bluetoothctl connect "\$MAC" >> "\$LOG" 2>&1
    else
        echo "\$(date) - Mando conectado. Vigilando..." >> "\$LOG"
    fi
    sleep 10
done

EOF

run_as_root chmod +x /usr/local/bin/bluetooth-watchdog.sh


# [12]: Habilitar servicios.
echo -e "\r\n\n\n\n[32/54] ############### Recargando systemd, iniciando y habilitando servicios ###############\r\n"
run_as_root systemctl daemon-reload

SERVICIOS=(
    back.service
    bluetooth-watchdog.service
    controller.service
    listen_stb_update.service
    listener_json.service
    mqtt_consumer_accion_stb.service
    mqtt_consumer_tunel.service
    mqtt_stb_check.service
    return_vol.service
    teclado_virtual.service
    update_stb_db_consumer.service
    update_token_pms_listener.service
)

for servicio in "${SERVICIOS[@]}"; do
  run_as_root systemctl start "$servicio"
done

for servicio in "${SERVICIOS[@]}"; do
  run_as_root systemctl enable "$servicio"
done

run_as_root systemctl enable acciones_post_instalacion.service

USER_ID=$(id -u panoram4)
DBUS_ADDR="unix:path=/run/user/${USER_ID}/bus"

run_as_root sudo -u panoram4 env DBUS_SESSION_BUS_ADDRESS=$DBUS_ADDR systemctl --user daemon-reload
run_as_root sudo -u panoram4 env DBUS_SESSION_BUS_ADDRESS=$DBUS_ADDR systemctl --user enable mqtt_stb_action.service
run_as_root sudo -u panoram4 env DBUS_SESSION_BUS_ADDRESS=$DBUS_ADDR systemctl --user restart mqtt_stb_action.service
run_as_root sudo -u panoram4 env DBUS_SESSION_BUS_ADDRESS=$DBUS_ADDR systemctl --user enable mute_control.service
run_as_root sudo -u panoram4 env DBUS_SESSION_BUS_ADDRESS=$DBUS_ADDR systemctl --user restart mute_control.service

# [13]: Crontab.
echo -e "\r\n\n\n\n[33/54] ############### Colocando servicios al crontab ###############\r\n"

cd /home/panoram4

# Añadir crontab de root.
touch temp_cron
cat crontab_root > temp_cron
echo '*/5 * * * * /home/panoram4/comprobar-mando.sh' >> temp_cron
run_as_root crontab temp_cron
rm temp_cron


# Añadir crontab de panoram4.
touch temp_cron_no_root
cat crontab_panoram4 > temp_cron_no_root
run_as_root crontab -u panoram4 crontab_panoram4
rm temp_cron_no_root


# [14]: Descargar juegos y activar vpn.
echo -e "\r\n\n\n\n[34/54] ############### Descargar y descomprimir Juegos ###############\r\n"
# Descargar los juegos.
wget -nc https://server.panoram4.com/roms/mame.zip -P /home/panoram4
unzip /home/panoram4/mame.zip


echo -e "\r\n\n\n\n[35/54] ############### Activar ExpressVPN ###############\r\n"

wget -nc https://server.panoram4.com/expressvpn_3.53.0.0-1_amd64.deb
run_as_root dpkg -i expressvpn_3.53.0.0-1_amd64.deb

cd /home/panoram4/
./activar_expressvpn.exp

# Desconectar ExpressVPN.
expressvpn disconnect

# Desactivar network lock de ExpressVPN.
expressvpn preferences set network_lock off


# [15]: Configurando control remoto.
echo -e "\r\n\n\n\n[36/54] ############### Configurando y verificando dependencias de control remoto ###############\r\n"

SSH_KEY="id_rsa"

# Definir la ubicación y el nombre del archivo de la llave ssh.
SSH_KEY_PATH="$HOME_DIR/.ssh/$SSH_KEY"

# Directorio actual y nombre del entorno virtual.
WORKING_DIR="$HOME_DIR/client_generate_keys"
ENV_DIR="$WORKING_DIR/env"
REQUIREMENTS_FILE="$WORKING_DIR/requirements.txt"
PUBLISH_KEY_FILE="$WORKING_DIR/publish_key.py"

# Crear el directorio de trabajo si no existe
if [ ! -d "$WORKING_DIR" ]; then
    echo -e "\r\n\n\n\n############### Creando el directorio de trabajo $WORKING_DIR... ###############\r\n"
    mkdir -p "$WORKING_DIR"
    chown $USER:$USER "$WORKING_DIR"
fi

# Crear la carpeta 'env' con permisos del usuario antes de levantar el entorno virtual
if [ ! -d "$ENV_DIR" ]; then
    echo -e "\r\n\n\n\n############### Creando el entorno virtual en $ENV_DIR... ###############\r\n"
    mkdir -p "$ENV_DIR"
    chown $USER:$USER "$ENV_DIR"
    run_as_root virtualenv "$ENV_DIR"
else
    echo "El entorno virtual ya existe en $ENV_DIR"
fi

# Crear los archivos requirements.txt y publish_key.py con el contenido especificado
# Asegurarse de que estos archivos sean creados y editados con permisos del usuario
echo -e "\r\n\n\n\n[37/54] ############### Creando archivos de configuración... ###############\r\n"

run_as_root bash -c "cat << 'EOF' > \"$REQUIREMENTS_FILE\"
paho-mqtt==2.1.0
cryptography==43.0.0
EOF"

run_as_root chown $USER:$USER "$REQUIREMENTS_FILE"

# Activar el entorno virtual y asegurar que las dependencias se instalen correctamente
echo -e "\r\n\n\n\n[38/54] ############### Instalando dependencias en el entorno virtual... ###############\r\n"
#run_as_root -u "$USER" bash -c "source \"$ENV_DIR/bin/activate\" && pip install -r \"$REQUIREMENTS_FILE\""
run_as_root bash -c "source \"$ENV_DIR/bin/activate\" && pip install -r \"$REQUIREMENTS_FILE\""

# Comprobar si la llave ya existe y sobrescribir sin pedir confirmación
if [ -f "$SSH_KEY_PATH" ]; then
    echo -e "\r\n\nUna llave SSH ya existe en $SSH_KEY_PATH. La llave será sobrescrita.\r\n"
    run_as_root rm -f "$SSH_KEY_PATH" "${SSH_KEY_PATH}.pub" # Elimina los archivos existentes como el usuario no root
fi

# Generar la llave SSH sin la opción -C como el usuario no root
run_as_root ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N "" -C "$mac@panoram4.com"
run_as_root chown -R $USER:$USER "$SSH_KEY_PATH" "$SSH_KEY_PATH"

# Mostrar la llave pública generada
echo -e "\r\n\nLlave SSH generada exitosamente: "
cat "${SSH_KEY_PATH}.pub"
echo -e "\r\n\n"

# Leer el contenido de la llave pública
SSH_KEY_CONTENT=$(cat "${SSH_KEY_PATH}.pub")

chown $USER:$USER "$REQUIREMENTS_FILE"
chown $USER:$USER "$PUBLISH_KEY_FILE"
chown -R $USER:$USER "$ENV_DIR"

# Debemos encriptar el contenido de las llaves

# Obtener la dirección Bluetooth
get_bluetooth_address

# Convertir la dirección Bluetooth a hexadecimal
convert_address_to_hex

# Ejecutar el script Python pasando el contenido de la clave SSH como parámetro
run_as_root bash -c "source \"$ENV_DIR/bin/activate\" && python3 \"$PUBLISH_KEY_FILE\" \"$SSH_KEY_CONTENT\""

# Asegurarse de que los archivos y el entorno virtual sean propiedad del usuario actual
#chown $USER:$USER "$REQUIREMENTS_FILE"
#chown $USER:$USER "$PUBLISH_KEY_FILE"
#chown -R $USER:$USER "$ENV_DIR"

echo -e "\r\n\n\n\n############### Proceso de generar clave SSH completado ###############\r\n"

echo -e "\r\n\n\n\n[39/54] ############### Creación de los archivos sh y py para control remoto ###############\r\n"

if [ -d "$HOME_DIR/CAFile" ]; then
    rm -rf "$HOME_DIR/CAFile"
fi

mkdir -p "$HOME_DIR/CAFile"

wget -nc https://server.panoram4.com/ca_combined.pem -P $HOME_DIR/CAFile


# [16]: Configuraciones del sistema.
# Permitir ejecutar 'ip' sin contraseña.
echo 'panoram4 ALL=(ALL) NOPASSWD: /usr/sbin/ip' | run_as_root tee /etc/sudoers.d/ip

# Permitir ejecutar 'iw' e 'iwlist' sin contraseña.
echo 'panoram4 ALL=(ALL) NOPASSWD: /usr/sbin/iw' | run_as_root tee /etc/sudoers.d/iw
echo 'panoram4 ALL=(ALL) NOPASSWD: /usr/sbin/iwlist' | run_as_root tee /etc/sudoers.d/iwlist

# Permitir aplicar configuración de red sin contraseña.
echo 'panoram4 ALL=(ALL) NOPASSWD: /usr/sbin/netplan apply' | run_as_root tee /etc/sudoers.d/netplan

# Permitir gestionar el servicio update_stb_db_consumer sin contraseña.
echo 'panoram4 ALL=(ALL) NOPASSWD: /bin/systemctl start update_stb_db_consumer.service, /bin/systemctl stop update_stb_db_consumer.service, /bin/systemctl restart update_stb_db_consumer.service' | run_as_root tee /etc/sudoers.d/update_stb_db_consumer

# Otorgar permisos totales sobre la configuración de red.
run_as_root chmod 777 -R /etc/netplan
run_as_root chown -R panoram4:panoram4 /etc/netplan

# Evitar que el sistema espere a la red durante el arranque.
run_as_root systemctl mask systemd-networkd-wait-online.service


echo -e "\r\n\n\n\n[40/54] ############### Configuración de salida de sonido ###############\r\n"

# Desactivar detección de micrófono digital para evitar conflictos de sonido.
echo "options snd-hda-intel dmic_detect=0" | run_as_root tee -a /etc/modprobe.d/alsa-base.conf

# Recargar configuración de ALSA.
run_as_root alsa force-reload


echo -e "\r\n\n\n\n[41/54] ############### Configuración del Autologin ###############\r\n"
# Deshabilitar línea original de autologin en getty@.service.
run_as_root sed -i 's/^ExecStart=-\/sbin\/agetty -o/#ExecStart=-\/sbin\/agetty -o/' /lib/systemd/system/getty@.service

# Agregar nueva línea de autologin para el usuario panoram4.
run_as_root sed -i '/ExecStart=-\/sbin\/agetty -o/a ExecStart=-/sbin/agetty --noissue --autologin panoram4 %I $TERM Type=idle' /lib/systemd/system/getty@.service

# Crear el directorio de override si no existe.
mkdir -p /etc/systemd/system/getty@tty1.service.d/

# Crear archivo de configuración override para habilitar autologin.
cat <<EOF >/etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --noissue --autologin panoram4 %I \$TERM
EOF

echo -e "\r\n\n\n\n[42/54] ############### Configuración de evdev en las teclas 180 home y help ###############\r\n"
# Crear una copia de seguridad del archivo evdev.
run_as_root cp /usr/share/X11/xkb/keycodes/evdev /usr/share/X11/xkb/keycodes/evdev_copy

# Comentar la línea existente para la tecla HOME y agregar una nueva con el valor 180.
run_as_root sed -i '/<HOME> = 110;/ s/^/#/' /usr/share/X11/xkb/keycodes/evdev
run_as_root sed -i '/<HOME> = 110;/a <HOME> = 180;' /usr/share/X11/xkb/keycodes/evdev

# Comentar la línea existente para la tecla HELP y agregar una nueva con el valor 135.
run_as_root sed -i '/<HELP> = 146;/ s/^/#/' /usr/share/X11/xkb/keycodes/evdev
run_as_root sed -i '/<HELP> = 146;/a <HELP> = 135;' /usr/share/X11/xkb/keycodes/evdev

# Comentar la línea de I180 y reasignarla al valor 110 (HOME original).
run_as_root sed -i '/<I180> = 180;/ s/^/#/' /usr/share/X11/xkb/keycodes/evdev
run_as_root sed -i '/<I180> = 180;/a <I180> = 110;           // #define KEY_HOMEPAGE            172;' /usr/share/X11/xkb/keycodes/evdev

cd /home/panoram4

# Modificar profile.
echo -e "\r\n\n\n\n[43/54] ############### Configuración de .profile ###############\r\n"

# Bloque que lanza cage automáticamente al iniciar sesión en TTY1.
nuevas_lineas='
if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then
  exec cage -- ./startup_panoram4.sh
fi
'

# Agregar el bloque anterior al final de .profile
echo "$nuevas_lineas" | tee -a /home/panoram4/.profile

cd /home/panoram4

# Crear regla udev para solucionar el problema de pantalla negra (reinicia Cage al detectar cambios en DRM/HDMI).
echo 'SUBSYSTEM=="drm", ACTION=="change", RUN+="/usr/local/bin/restart-cage.sh"' | run_as_root tee /etc/udev/rules.d/99-hdmi.rules >/dev/null

# Script que reinicia Cage.
cat <<EOF | tee /usr/local/bin/restart-cage.sh
#!/bin/bash
pkill -9 cage
# Espera un momento para asegurarte de que el dispositivo esté listo
sleep 1
EOF

run_as_root chmod +x /usr/local/bin/restart-cage.sh

# Recargar las reglas de udev.
run_as_root udevadm control --reload

# Extender el volumen lógico para usar todo el disco disponible.
run_as_root lvresize -l+100%FREE /dev/mapper/ubuntu--vg-ubuntu--lv && run_as_root resize2fs /dev/mapper/ubuntu--vg-ubuntu--lv && df -h

run_as_root tee "/etc/sudoers.d/openvpn" >/dev/null <<EOF
panoram4 ALL=(ALL) NOPASSWD: /usr/sbin/openvpn --config /home/panoram4/vpn/*.ovpn --daemon
panoram4 ALL=(ALL) NOPASSWD: /usr/sbin/openvpn --config * --daemon
panoram4 ALL=(ALL) NOPASSWD: /usr/bin/pkill -9 openvpn
panoram4 ALL=(ALL) NOPASSWD: /usr/bin/killall -9 openvpn
panoram4 ALL=(ALL) NOPASSWD: /bin/kill -9 $(pgrep openvpn)

EOF

echo -e "\r\n\n\n\n[44/54] ############### Modificación para que no muestre mensaje de bienvenida del OS ###############\r\n"
# Deshabilitar mensaje de bienvenida MOTD.
MOTD_CONFIG="/etc/default/motd-news"

if [[ -f "$MOTD_CONFIG" ]]; then
    sed -i 's/^ENABLED=1/ENABLED=0/' "$MOTD_CONFIG"

    echo "El mensaje MOTD ha sido deshabilitado en $MOTD_CONFIG."
else
    echo "Archivo de configuración $MOTD_CONFIG no encontrado."
fi

# Vaciar archivos de información de inicio de sesión.
if [[ -f "/etc/issue" ]]; then
    : >/etc/issue
    echo "Contenido de /etc/issue eliminado."
fi

if [[ -f "/etc/issue.net" ]]; then
    : >/etc/issue.net
    echo "Contenido de /etc/issue.net eliminado."
fi

run_as_root systemctl disable motd-news.timer
run_as_root systemctl disable motd-news.service

echo -e "\r\n\n\n\n[45/54] ############### Modificar el grub ###############\r\n"
# Comentar línea existente y agregar parámetros personalizados al grub.
run_as_root sh -c 'sed "/GRUB_CMDLINE_LINUX_DEFAU/ s/^/#/" /etc/default/grub > /etc/default/grub_temp && mv /etc/default/grub_temp /etc/default/grub'
run_as_root sed -i '/GRUB_CMDLINE_LINUX_DEFAU/a GRUB_CMDLINE_LINUX_DEFAULT="quiet splash video=1920x1080 loglevel=0 vt.global_cursor_default=0 systemd.confirm_spawn=0 fastboot"' /etc/default/grub

echo -e "\r\n\n\n\n[46/54] ############### Actualización del grub ###############\r\n"
# Actualizar la configuración del grub.
run_as_root update-grub

# Deshabilitar historial de último inicio de sesión.
PAM_LOGIN_CONFIG="/etc/pam.d/login"
if [[ -f "$PAM_LOGIN_CONFIG" ]]; then
    sed -i '/^session[[:space:]]\+optional[[:space:]]\+pam_lastlog\.so/s/^/# /' "$PAM_LOGIN_CONFIG"
    echo "Línea 'session optional pam_lastlog.so' comentada en $PAM_LOGIN_CONFIG."
else
    echo "Archivo $PAM_LOGIN_CONFIG no encontrado."
fi

cd /home/panoram4 && rm -r bootanimationv3_respira

echo -e "\r\n\n\n\n############### Descargar de splash ###############\r\n"
# Descargar splash y adaptarlo.
wget https://server.panoram4.com/bootanimationv2_respira.tar.xz
tar -xvf bootanimationv2_respira.tar.xz

echo -e "\r\n\n\n\n[47/54] ############### Configuración de splash ###############\r\n"
# Configurar tema de splash personalizado.
run_as_root cp -r bootanimationv3_respira /usr/share/plymouth/themes/
run_as_root sed -i 's/\.7/\.5/g' /usr/share/plymouth/themes/bgrt/bgrt.plymouth
run_as_root sed -i 's/spinner/bootanimationv3_respira/g' /usr/share/plymouth/themes/bgrt/bgrt.plymouth


echo -e "\r\n\n\n\n[48/54] ############### Actualizar initramfs ###############\r\n"
# Actualizar initramfs.
run_as_root update-initramfs -u

echo -e "\r\n\n\n\n[49/54] ############### Seteo de time zone ###############\r\n"
# Establecer zona horaria.
run_as_root timedatectl set-timezone 'Europe/Madrid'

echo -e "\r\n\n\n\n[50/54] ############### Configuración para no permitir actualizaciones ###############\r\n"
# Deshabilitar actualizaciones automáticas.
run_as_root mv /etc/apt/apt.conf.d/20auto-upgrades /etc/apt/apt.conf.d/20auto-upgrades_save

# Contenido del archivo 20auto-upgrades.
conf_content='APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Download-Upgradeable-Packages "0";
APT::Periodic::AutocleanInterval "0";
APT::Periodic::Unattended-Upgrade "1";'

# Establecer propietario del directorio personal.
run_as_root chown -R panoram4:panoram4 /home/panoram4

# Aplicar nueva configuración de actualizaciones.
echo "$conf_content" | run_as_root tee /etc/apt/apt.conf.d/20auto-upgrades

echo -e "\r\n\n\n\n[51/54] ############### Configuración de ssh para wayvnc ###############\r\n"
# Habilitar opciones necesarias en SSH para wayvnc.
wayvnc_sshd_config "AllowTcpForwarding" "yes"
wayvnc_sshd_config "X11Forwarding" "yes"

run_as_root systemctl restart ssh


echo -e "\r\n\n\n\n[52/54] ############### Configuración de Netplan para Ethernet ###############\r\n"

adaptador_ethernet=$(ls /sys/class/net | grep -E '^(en|eth)')

ruta_archivo_netplan_eth="/etc/netplan/00-installer-config-ethernet.yaml"

echo "network:" >"$ruta_archivo_netplan_eth"
echo "  version: 2" >>"$ruta_archivo_netplan_eth"
echo "  ethernets:" >>"$ruta_archivo_netplan_eth"
echo "    $adaptador_ethernet:" >>"$ruta_archivo_netplan_eth"
echo "      dhcp4: true" >>"$ruta_archivo_netplan_eth"

if [ $? -ne 0 ]; then
    echo "Error al crear el archivo de configuración de Netplan."
    exit 1
fi

cat "$ruta_archivo_netplan_eth"


echo -e "\r\n\n\n\n[53/54] ############### Configuración de Netplan para WiFi ###############\r\n"

adaptador_wifi=$(ls /sys/class/net | grep -E '^(wlan|wl)')

ruta_archivo_netplan_wifi="/etc/netplan/00-installer-config-wifi.yaml"

# Crear un archivo de configuración YAML nuevo con los valores proporcionados
echo "network:" >"$ruta_archivo_netplan_wifi"
echo "  version: 2" >>"$ruta_archivo_netplan_wifi"
echo "  wifis:" >>"$ruta_archivo_netplan_wifi"
echo "    "$adaptador_wifi":" >>"$ruta_archivo_netplan_wifi"
echo "      optional: true" >>"$ruta_archivo_netplan_wifi"
echo "      dhcp4: true" >>"$ruta_archivo_netplan_wifi"
echo "      access-points:" >>"$ruta_archivo_netplan_wifi"
echo "        '$hotel_colon_ssid':" >>"$ruta_archivo_netplan_wifi"
echo "          password: '$hotel_colon_password'" >>"$ruta_archivo_netplan_wifi"

if [ $? -ne 0 ]; then
    echo "Error al crear el archivo de configuración de Netplan."
fi

cat /etc/netplan/00-installer-config-wifi.yaml

run_as_root chmod 777 -R /etc/netplan
run_as_root chown -R panoram4:panoram4 /etc/netplan
run_as_root netplan apply


echo -e "\r\n\n\n\n[54/54] ############### Borraremos los archivos que no se van a usar mas. ###############\r\n"

cd /home/panoram4
run_as_root rm response.json
run_as_root rm -r evsieve-1.4.0.tar.gz*
run_as_root rm -r expressvpn_3.53.0.0-1_amd64.deb*
run_as_root rm -r libssl1.1_1.1.1f-1ubuntu2_amd64.deb*
run_as_root rm -r mame.zip*
run_as_root rm crontab_root crontab_panoram4

sleep 5

clear && echo -e "\r\n- ¡La instalación del STB para $instalacion ha finalizado! \r\n"

echo -e "\r\n\n\n\n############### Información del STB ###############\r\n\r\n"
echo -e " - Cliente: $cliente\r\n"
echo -e " - Instalación: $instalacion\r\n"
echo -e " - Grupo: $grupo\r\n"
echo -e " - Estancia: $estancia\r\n"
echo -e " - Serial: $serial\r\n\r\n\r\n"
echo -e " - MAC: $mac\r\n"
echo -e " - MAC Bluetooh: $mac_bluetooh\r\n\r\n\r\n"
echo -e " - Version del OS: $descripcion_os\r\n"
echo -e " - Version del Kernel: $version_kernel\r\n"

echo -e "\r\n\n\n############### Enviando información al PC de la impresora. ###############\r\n"
json_file="$serial.json"
ssh_pub_key_file="/home/panoram4/.ssh/id_rsa.pub"

# Verifica si el archivo id_rsa.pub existe y lee su contenido
if [ -f "$ssh_pub_key_file" ]; then
    ssh_pub_key=$(cat "$ssh_pub_key_file")
else
    echo "Error: No se encontró el archivo $ssh_pub_key_file. Asegúrate de que existe."
    exit 1
fi

if [ ! -f "$json_file" ]; then
    echo "{
    \"Instalación\": \"$instalacion\",
    \"Estancia\": \"$estancia\",
    \"Mac Address\": \"$mac\",
    \"Passw\": \"$contrasena\",
    \"SSH Public Key\": \"$ssh_pub_key\"
  }" >"$json_file"
    echo "Archivo JSON creado: $json_file"
else
    echo "El archivo JSON $json_file ya existe."
fi

remote_user="panoram4"
remote_dir="/home/panoram4/Desktop/"

instalacion_sin_espacios="${instalacion// /_}"
final_path="${remote_dir}${instalacion_sin_espacios}"

if [ ! -f "$json_file" ]; then
    echo "Archivo local $json_file no encontrado."
fi

ping -c 2 "$pc_impresora" &>/dev/null
sleep 1
if [ $? -ne 0 ]; then
    echo "Error: No se puede conectar con $pc_impresora. Asegúrate de que está en la misma red."
fi

sshpass -p "Pan0CPD100" ssh -o StrictHostKeyChecking=no $remote_user@$pc_impresora "echo $(cat ~/.ssh/id_rsa.pub) >> ~/.ssh/authorized_keys"

sshpass -p "Pan0CPD100" ssh -o StrictHostKeyChecking=no $remote_user@$pc_impresora "mkdir -p '$final_path'"

sshpass -p "Pan0CPD100" scp "$json_file" "$remote_user@$pc_impresora:$final_path"

if [ $? -eq 0 ]; then
    echo "Archivo JSON $json_file copiado a $final_path en la máquina remota $pc_impresora"
else
    echo "Error al copiar el archivo JSON a la máquina remota"
fi

run_as_root rm $json_file

cd /home/panoram4

MOTD_SCRIPTS='/etc/update-motd.d/*'
if [[ -d "/etc/update-motd.d" ]]; then
    run_as_root chmod -x $MOTD_SCRIPTS
    echo "Se han deshabilitado los scripts en /etc/update-motd.d/."
else
    echo "Directorio /etc/update-motd.d/ no encontrado."
fi

echo "$estancia" >/home/panoram4/estancia.txt

# Actualizar la contraseña de panoram4 y root a la generada
run_as_root echo "$usuario:$contrasena" | run_as_root chpasswd
run_as_root echo "root:$contrasena" | run_as_root chpasswd

echo -e "\r\n\n\n############### El sistema se reiniciará en 10 segundos. ###############\r\n"
sleep 10

# Reiniciar el sistema.
clear && run_as_root reboot
