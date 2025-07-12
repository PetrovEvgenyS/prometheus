# Prometheus Installation Scripts

Этот репозиторий содержит скрипты для установки и настройки Prometheus и связанных экспортеров. Скрипты поддерживают дистрибутивы Ubuntu и AlmaLinux.

## Список скриптов

### 1. Установка Prometheus
- **Файл:** `Installation script Prometheus/installation_script_prometheus.sh`
- **Описание:**
  - Устанавливает Prometheus версии 2.51.1.
  - Настраивает конфигурацию Prometheus для мониторинга самого себя, Linux Node Exporter и Windows Node Exporter.
  - Создает systemd-юнит для управления сервисом Prometheus.
  - Отключает SELinux (если применимо).

### 2. Установка Node Exporter
- **Файл:** `Installation script Node Exporter/installation_script_node_exporter.sh`
- **Описание:**
  - Устанавливает Node Exporter версии 1.8.2.
  - Создает systemd-юнит для управления сервисом Node Exporter.
  - Отключает SELinux (если применимо).
  - Экспортирует метрики по адресу http://IP-address:9100/metrics.

### 3. Установка Nginx Exporter
- **Файл:** `Installation script Nginx Exporter/installation_script_nginx_exporter.sh`
- **Описание:**
  - Устанавливает Nginx Prometheus Exporter версии 1.3.0.
  - Настраивает systemd-юнит для управления сервисом Nginx Exporter.
  - Отключает SELinux (если применимо).
  - Экспортирует метрики по адресу http://IP-address:9113/metrics.

### 4. Установка BIND Exporter
- **Файл:** `Installation script BIND Exporter/installation_script_bind_exporter.sh`
- **Описание:**
  - Устанавливает BIND Exporter версии 0.8.0.
  - Создает пользователя и systemd-юнит для bind_exporter.
  - Для AlmaLinux открывает порт 9119/tcp в firewall.
  - Для Ubuntu отключает AppArmor, для AlmaLinux — SELinux.
  - Экспортирует метрики по адресу http://IP-address:9119/metrics.
  
- **Настройка BIND:**
  - Настройте BIND на открытие канала статистики. Рекомендуется запускать bind_exporter вместе с BIND, поэтому достаточно открыть порт локально.

```
statistics-channels {
  inet 127.0.0.1 port 8053 allow { 127.0.0.1; };
};
```

## Примечания
- Скрипты автоматически определяют вашу операционную систему (Ubuntu или AlmaLinux) и устанавливают необходимые зависимости.
- SELinux или AppArmor будет отключен, если он активен.
- Убедитесь, что порты, используемые сервисами (например, 9090 для Prometheus, 9100 для Node Exporter, 9113 для Nginx Exporter, 9119 для BIND Exporter), открыты в вашем файрволе.
