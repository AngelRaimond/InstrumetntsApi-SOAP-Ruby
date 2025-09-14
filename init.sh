#!/bin/bash
set -e

echo "=== Iniciando aplicación Instrumentos API ==="

echo "Esperando a que la base de datos esté lista..."
until mysql -h instrumentos-db -u root -pa --skip-ssl -e "SELECT 1" >/dev/null 2>&1; do
    echo "Esperando MySQL..."
    sleep 2
done

echo "Base de datos conectada exitosamente!"

echo "Verificando archivos de configuración..."
if [ ! -f "config/environment.rb" ]; then
    echo "ERROR: config/environment.rb no encontrado"
    exit 1
fi

if [ ! -f "config.ru" ]; then
    echo "ERROR: config.ru no encontrado"
    exit 1
fi

echo "Verificando conexión a base de datos con Ruby..."
bundle exec ruby -e "
require_relative 'config/environment'
puts 'Conexión a ActiveRecord exitosa'
puts 'Base de datos: ' + ActiveRecord::Base.connection.current_database
" || {
    echo "ERROR: No se pudo conectar a la base de datos con ActiveRecord"
    exit 1
}

echo "Listando bases de datos existentes..."
mysql -h instrumentos-db -u root -pa --skip-ssl -e "SHOW DATABASES;"

echo "Creando base de datos si no existe..."
timeout 30 bundle exec rake db:create 2>/dev/null || {
    echo "Advertencia: db:create falló o ya existe"
    echo "Intentando crear manualmente..."
    mysql -h instrumentos-db -u root -pa --skip-ssl -e "CREATE DATABASE IF NOT EXISTS instrumentos_development CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
}

echo "Ejecutando migraciones..."
timeout 30 bundle exec rake db:migrate 2>/dev/null || {
    echo "Advertencia: db:migrate falló"
    echo "Verificando estado de la base de datos..."
    mysql -h instrumentos-db -u root -pa --skip-ssl -D instrumentos_development -e "SHOW TABLES;"
}

echo "Iniciando servidor SOAP en puerto 4567..."
exec bundle exec rackup -o 0.0.0.0 -p 4567