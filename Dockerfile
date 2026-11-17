FROM ghcr.io/cirruslabs/flutter:stable AS frontend

WORKDIR /src

COPY pubspec.* ./
RUN flutter pub get

COPY . .
RUN flutter build web --release --base-href=/

FROM php:8.5-apache

RUN docker-php-ext-install pdo pdo_mysql mysqli

COPY --from=frontend /src/build/web/ /var/www/html/
COPY backend/ /var/www/html/backend/

RUN a2enmod rewrite \
    && chown -R www-data:www-data /var/www/html \
    && find /var/www/html -type d -exec chmod 755 {} \; \
    && find /var/www/html -type f -exec chmod 644 {} \;

EXPOSE 80
