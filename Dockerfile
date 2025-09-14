FROM ruby:3.2

# Instalar dependencias del sistema
RUN apt-get update && apt-get install -y \
    default-mysql-client \
    default-libmysqlclient-dev \
    && rm -rf /var/lib/apt/lists/*

# Crear directorio de trabajo
WORKDIR /app

# Copiar archivos de configuración primero
COPY Gemfile ./

# Instalar gems
RUN bundle install

# Copiar todo el código
COPY . .

# Hacer el script ejecutable
RUN chmod +x init.sh

# Exponer puerto
EXPOSE 4567

# Comando de inicio
CMD ["./init.sh"]