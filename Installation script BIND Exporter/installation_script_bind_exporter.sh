#!/bin/bash

# Установка и настройка BIND Exporter

# Задаем переменные
EXPORTER_VERSION="0.8.0" 
EXPORTER_URL="https://github.com/prometheus-community/bind_exporter/releases/download/v${EXPORTER_VERSION}/bind_exporter-${EXPORTER_VERSION}.linux-amd64.tar.gz"
USER="bind_exporter"
NAME_SERVICE_EXPORTER="bind_exporter"

# Переменная определения и хранения дистрибутива:
OS=$(awk -F= '/^ID=/{gsub(/"/, "", $2); print $2}' /etc/os-release)

### ЦВЕТА ##
ESC=$(printf '\033') RESET="${ESC}[0m" BLACK="${ESC}[30m" RED="${ESC}[31m"
GREEN="${ESC}[32m" YELLOW="${ESC}[33m" BLUE="${ESC}[34m" MAGENTA="${ESC}[35m"
CYAN="${ESC}[36m" WHITE="${ESC}[37m" DEFAULT="${ESC}[39m"

magentaprint() { echo; printf "${MAGENTA}%s${RESET}\n" "$1"; }

# ------------------------------------------------------------------------------------ #

# Выбор ОС для установки необходимых пакетов и настройки firewall:
check_os() {
  if [ "$OS" == "ubuntu" ]; then
      packages_firewall_ubuntu
      disable_apparmor
  elif [ "$OS" == "almalinux" ]; then
      packages_firewall_almalinux
      disable_selinux
  else
      magentaprint "Скрипт не поддерживает установленную ОС: $OS"
      # Выход из скрипта с кодом 1.
      exit 1
  fi
}

# Функция установки необходимых пакетов и настройки firewall на Ubuntu:
packages_firewall_ubuntu() {
  magentaprint "Устанавливаем необходимые пакеты..."
  apt -y install wget tar

  # Настраиваем firewall:
  # magentaprint "Настраиваем firewall...")
}

# Функция установки необходимых пакетов и настройки firewall на AlmaLinux:
packages_firewall_almalinux() {
  magentaprint "Устанавливаем необходимые пакеты..."
  dnf -y install wget tar

  # Настраиваем firewall:
  magentaprint "Настраиваем firewall..."
  firewall-cmd --permanent --add-port=9119/tcp
  firewall-cmd --reload
}

# Функция подготовки почвы:
preparation() {
  magentaprint "Создание пользователя $USER для запуска $NAME_SERVICE_EXPORTER..."
  useradd --no-create-home --shell /sbin/nologin $USER

  magentaprint "Создание каталога для логов $NAME_SERVICE_EXPORTER..."
  # Создаем каталог для логов и устанавливаем права доступа:
  mkdir -p /var/log/$NAME_SERVICE_EXPORTER
  chown $USER:$USER /var/log/$NAME_SERVICE_EXPORTER
}

# Функция для скачивания Exporter:
download_exporter () {
  magentaprint "Загрузка $NAME_SERVICE_EXPORTER..."
  # Загрузка Exporter
  wget $EXPORTER_URL -O /tmp/$NAME_SERVICE_EXPORTER.tar.gz
  # Распаковка архива
  mkdir /tmp/$NAME_SERVICE_EXPORTER
  tar -xzf /tmp/$NAME_SERVICE_EXPORTER.tar.gz -C /tmp/$NAME_SERVICE_EXPORTER
  # Перемещение бинарного файла в /usr/local/bin
  mv /tmp/$NAME_SERVICE_EXPORTER/bind_exporter-${EXPORTER_VERSION}.linux-amd64/bind_exporter /usr/local/bin/$NAME_SERVICE_EXPORTER
  rm -rf /tmp/$NAME_SERVICE_EXPORTER*
  # Убедитесь, что файл exporter принадлежит правильному пользователю и группе
  chown $USER:$USER /usr/local/bin/$NAME_SERVICE_EXPORTER
}

# Функция создания юнита Exporter для systemd:
create_unit_exporter() {
  magentaprint "Настраиваем юнит $NAME_SERVICE_EXPORTER..."
  tee /etc/systemd/system/$NAME_SERVICE_EXPORTER.service > /dev/null <<EOF
[Unit]
Description=$NAME_SERVICE_EXPORTER $EXPORTER_VERSION
Wants=network-online.target
After=network-online.target

[Service]
User=$USER
Group=$USER
Type=simple
ExecStart=/usr/local/bin/$NAME_SERVICE_EXPORTER
StandardOutput=append:/var/log/$NAME_SERVICE_EXPORTER/$NAME_SERVICE_EXPORTER.log
StandardError=append:/var/log/$NAME_SERVICE_EXPORTER/$NAME_SERVICE_EXPORTER.log
Restart=always

[Install]
WantedBy=multi-user.target
EOF
}

# Перезагружаем systemd. Запуск и включение Exporter:
start_enable_exporter() {
  magentaprint "Перезагружаем systemd. Запуск и включение $NAME_SERVICE_EXPORTER..."
  systemctl daemon-reload
  systemctl start $NAME_SERVICE_EXPORTER
  systemctl enable $NAME_SERVICE_EXPORTER
}

# Отключение SELinux:
disable_selinux() {
  magentaprint "Отключаем SELinux..."
  # Проверка, существует ли файл конфигурации SELinux
  if [ -f /etc/selinux/config ]; then
    # Изменение строки SELINUX= на SELINUX=disabled
    sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config  
    magentaprint "SELinux был отключен. Перезагрузите систему для применения изменений."
  else
    magentaprint "Файл конфигурации SELinux не найден."
  fi
}

# Отключение AppArmor:
disable_apparmor() {
  magentaprint "Отключаем AppArmor..."
  # Проверяем, установлен ли AppArmor
  # Читаем текущую строку GRUB_CMDLINE_LINUX_DEFAULT из файла
  current_value=$(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub)

  # Проверяем значение
  if [[ "$current_value" == 'GRUB_CMDLINE_LINUX_DEFAULT="apparmor=0"' ]]; then
      # Ничего не делать
      echo "Значение уже установлено: $current_value"
  elif [[ "$current_value" == 'GRUB_CMDLINE_LINUX_DEFAULT=""' ]]; then
      # Заменяем на apparmor=0
      sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=".*"/GRUB_CMDLINE_LINUX_DEFAULT="apparmor=0"/' /etc/default/grub
      update-grub
      magentaprint "Необходимо перезагрузить сервер: shutdown -r now"
      echo "Обновлено значение: $current_value -> GRUB_CMDLINE_LINUX_DEFAULT="apparmor=0""
  else
      echo "Значение не соответствует ожидаемым. Текущее значение: $current_value"
  fi
}

# Функция проверки состояния Exporter:
check_status_exporter() {
  systemctl status $NAME_SERVICE_EXPORTER --no-pager
  $NAME_SERVICE_EXPORTER --version
  magentaprint "$NAME_SERVICE_EXPORTER успешно установлен и настроен на $OS."

  # Получение IPv4 и сохранение её в переменную:
  IPv4=$(ip -4 -o addr show eth0 | awk '{print $4}' | cut -d/ -f1)

  magentaprint "Проверьте экспортируемые метрики по адресу http://$IPv4:9119/metrics"
}


# Создание функций main.
main() {
  check_os
  preparation
  download_exporter
  create_unit_exporter
  start_enable_exporter
  check_status_exporter
}

# Вызов функции main.
main