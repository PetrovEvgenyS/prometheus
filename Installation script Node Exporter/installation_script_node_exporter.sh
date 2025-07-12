#!/bin/bash

# Установка и настройка Node Exporter

# Установим переменные.
EXPORTER_VERSION="1.8.2"
EXPORTER_URL="https://github.com/prometheus/node_exporter/releases/download/v${EXPORTER_VERSION}/node_exporter-${EXPORTER_VERSION}.linux-amd64.tar.gz"
USER="node_exporter"
NAME_SERVICE_EXPORTER="node_exporter"

# Переменная определения и хранения дистрибутива:
OS=$(awk -F= '/^ID=/{gsub(/"/, "", $2); print $2}' /etc/os-release)

### ЦВЕТА ##
ESC=$(printf '\033') RESET="${ESC}[0m" BLACK="${ESC}[30m" RED="${ESC}[31m"
GREEN="${ESC}[32m" YELLOW="${ESC}[33m" BLUE="${ESC}[34m" MAGENTA="${ESC}[35m"
CYAN="${ESC}[36m" WHITE="${ESC}[37m" DEFAULT="${ESC}[39m"

magentaprint() { printf "${MAGENTA}%s${RESET}\n" "$1"; }

# ------------------------------------------------------------------------------------ #

# Выбор ОС для установки необходимых пакетов и настройки firewall:
check_os() {
  if [ "$OS" == "ubuntu" ]; then
      packages_firewall_ubuntu
  elif [ "$OS" == "almalinux" ]; then
      packages_firewall_almalinux
  else
      magentaprint "Скрипт не поддерживает установленную ОС: $OS"
      # Выход из скрипта с кодом 1.
      exit 1
  fi
}

# Функция установки необходимых пакетов и настройки firewall на Ubuntu:
packages_firewall_ubuntu() {
  magentaprint "Устанавливаем необходимые пакеты..."
  sudo apt update
  sudo apt -y install wget tar

  # Настраиваем firewall:
  magentaprint "Настраиваем firewall..."
}

# Функция установки необходимых пакетов и настройки firewall на AlmaLinux:
packages_firewall_almalinux() {
  magentaprint "Устанавливаем необходимые пакеты..."
  sudo dnf -y update
  sudo dnf -y install wget tar

  # Настраиваем firewall:
  magentaprint "Настраиваем firewall..."
  sudo firewall-cmd --permanent --add-port=9100/tcp
  sudo firewall-cmd --reload
}

# Функция подготовки почвы:
preparation() {
  magentaprint "Создание пользователя $USER для запуска $NAME_SERVICE_EXPORTER..."
  sudo useradd --no-create-home --shell /sbin/nologin $USER
}

# Функция для скачивания Exporter:
download_exporter () {
  magentaprint "Загрузка $NAME_SERVICE_EXPORTER..."
  # Загрузка Exporter
  sudo wget $EXPORTER_URL -O /tmp/$NAME_SERVICE_EXPORTER.tar.gz
  # Распаковка архива
  sudo tar -xzf /tmp/$NAME_SERVICE_EXPORTER.tar.gz -C /tmp
  # Перемещение бинарного файла в /usr/local/bin
  sudo mv /tmp/node_exporter-$EXPORTER_VERSION.linux-amd64/node_exporter /usr/local/bin/$NAME_SERVICE_EXPORTER
  sudo rm -rf /tmp/node_exporter*
  # Убедитесь, что файл exporter принадлежит правильному пользователю и группе
  sudo chown $USER:$USER /usr/local/bin/$NAME_SERVICE_EXPORTER
}

# Функция создания юнита Exporter для systemd:
create_unit_exporter() {
  magentaprint "Настраиваем юнит $NAME_SERVICE_EXPORTER..."
  sudo tee /etc/systemd/system/$NAME_SERVICE_EXPORTER.service > /dev/null <<EOF
[Unit]
Description=$NAME_SERVICE_EXPORTER $NODE_EXPORTER_VERSION
Wants=network-online.target
After=network-online.target

[Service]
User=$USER
Group=$USER
Type=simple
ExecStart=/usr/local/bin/$NAME_SERVICE_EXPORTER
Restart=always

[Install]
WantedBy=multi-user.target
EOF
}

# Перезагружаем systemd. Запуск и включение Exporter:
start_enable_exporter() {
  magentaprint "Перезагружаем systemd. Запуск и включение $NAME_SERVICE_EXPORTER..."
  sudo systemctl daemon-reload
  sudo systemctl start $NAME_SERVICE_EXPORTER
  sudo systemctl enable $NAME_SERVICE_EXPORTER
}

# Отключение SELinux:
disable_selinux() {
  magentaprint "Отключаем SELinux..."
  # Проверка, существует ли файл конфигурации SELinux
  if [ -f /etc/selinux/config ]; then
    # Изменение строки SELINUX= на SELINUX=disabled
    sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config  
    magentaprint "SELinux был отключен. Перезагрузите систему для применения изменений."
  else
    magentaprint "Файл конфигурации SELinux не найден."
  fi
}

# Функция проверки состояния Exporter:
check_status_exporter() {
  sudo systemctl status $NAME_SERVICE_EXPORTER --no-pager
  $NAME_SERVICE_EXPORTER --version
  magentaprint "$NAME_SERVICE_EXPORTER успешно установлен и настроен на $OS."

  # Получение IPv4 и сохранение её в переменную:
  IPv4=$(ip -4 -o addr show eth0 | awk '{print $4}' | cut -d/ -f1)

  magentaprint "Проверьте экспортируемые метрики по адресу http://$IPv4:9100/metrics"
}


# Создание функций main.
main() {
  check_os
  preparation
  download_exporter
  create_unit_exporter
  start_enable_exporter
  disable_selinux
  check_status_node_exporter
}

# Вызов функции main.
main