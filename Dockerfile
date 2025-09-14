# Usar imagen base oficial de Ruby
FROM ruby:3.2-slim

# Instalar dependencias del sistema
RUN apt-get update && apt-get install -y \
    build-essential \
    default-mysql-client \
    default-libmysqlclient-dev \
    git \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Crear directorio de trabajo
WORKDIR /app

# Copiar Gemfile y Gemfile.lock
COPY Gemfile* ./

# Instalar gemas
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install

# Copiar todo el código de la aplicación
COPY . .

# Asegurar que init.sh tenga permisos de ejecución
RUN chmod +x ./init.sh

# Asegurar que init.sh use terminaciones de línea Unix
RUN sed -i 's/\r$//' ./init.sh

# Verificar que el archivo existe y es ejecutable
RUN ls -la ./init.sh && file ./init.sh

# Exponer puerto
EXPOSE 4567

# Usar bash explícitamente para ejecutar el script
CMD ["bash", "./init.sh"]