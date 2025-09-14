# Usar imagen base oficial de Ruby
FROM ruby:3.2-slim

# Instalar dependencias del sistema
RUN apt-get update && apt-get install -y \
    build-essential \
    default-mysql-client \
    default-libmysqlclient-dev \
    git \
    bash \
    dos2unix \
    && rm -rf /var/lib/apt/lists/*

# Crear directorio de trabajo
WORKDIR /app

# Copiar Gemfile primero para aprovechar cache de Docker
COPY Gemfile ./
# Solo copiar Gemfile.lock si existe, pero no forzar su uso
COPY Gemfile.loc* ./

# Configurar bundle para regenerar el lockfile si es necesario
RUN bundle config set --local deployment 'false' && \
    bundle config set --local without 'development test' && \
    bundle lock --add-platform x86_64-linux && \
    bundle install

# Copiar todo el código de la aplicación
COPY . .

# Convertir terminaciones de línea y dar permisos
RUN dos2unix ./init.sh && \
    chmod +x ./init.sh

# Verificar que el archivo existe y es ejecutable
RUN ls -la ./init.sh && file ./init.sh

# Exponer puerto
EXPOSE 4567

# Usar bash explícitamente para ejecutar el script
CMD ["bash", "./init.sh"]