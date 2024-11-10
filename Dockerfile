# Usa la versión estable y compatible de Ubuntu
FROM ubuntu:jammy
MAINTAINER Odoo S.A. <info@odoo.com>

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

# Genera la configuración regional C.UTF-8 para PostgreSQL y otros datos de configuración regional
ENV LANG en_US.UTF-8

# Variable para la arquitectura objetivo para instalar el paquete wkhtmltopdf correcto
ARG TARGETARCH

# Instala algunas dependencias necesarias, lessc y less-plugin-clean-css, y wkhtmltopdf
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dirmngr \
        fonts-noto-cjk \
        gnupg \
        libssl-dev \
        node-less \
        npm \
        python3-magic \
        python3-num2words \
        python3-odf \
        python3-pdfminer \
        python3-pip \
        python3-phonenumbers \
        python3-pyldap \
        python3-qrcode \
        python3-renderpm \
        python3-setuptools \
        python3-slugify \
        python3-vobject \
        python3-watchdog \
        python3-xlrd \
        python3-xlwt \
        xz-utils && \
    if [ -z "${TARGETARCH}" ]; then \
        TARGETARCH="$(dpkg --print-architecture)"; \
    fi; \
    WKHTMLTOPDF_ARCH=${TARGETARCH} && \
    case ${TARGETARCH} in \
    "amd64") WKHTMLTOPDF_ARCH=amd64 && WKHTMLTOPDF_SHA=ae26e3c8a7178a0b1d9204d3d015d3504e91cacc  ;; \
    "arm64")  WKHTMLTOPDF_SHA=90f6e69896d51ef77339d3f3a20f8582bdf496cc  ;; \
    "ppc64le" | "ppc64el") WKHTMLTOPDF_ARCH=ppc64el && WKHTMLTOPDF_SHA=5312d7d34a25b321282929df82e3574319aed25c  ;; \
    esac \
    && curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_${WKHTMLTOPDF_ARCH}.deb \
    && echo ${WKHTMLTOPDF_SHA} wkhtmltox.deb | sha1sum -c - \
    && apt-get install -y --no-install-recommends ./wkhtmltox.deb \
    && rm -rf /var/lib/apt/lists/* wkhtmltox.deb

# Instala el cliente más reciente de PostgreSQL
RUN echo 'deb http://apt.postgresql.org/pub/repos/apt/ jammy-pgdg main' > /etc/apt/sources.list.d/pgdg.list \
    && GNUPGHOME="$(mktemp -d)" \
    && export GNUPGHOME \
    && repokey='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" \
    && gpg --batch --armor --export "${repokey}" > /etc/apt/trusted.gpg.d/pgdg.gpg.asc \
    && gpgconf --kill all \
    && rm -rf "$GNUPGHOME" \
    && apt-get update  \
    && apt-get install --no-install-recommends -y postgresql-client \
    && rm -f /etc/apt/sources.list.d/pgdg.list \
    && rm -rf /var/lib/apt/lists/*

# Instala rtlcss
RUN npm install -g rtlcss

# Instala Odoo
ENV ODOO_VERSION 18.0
ARG ODOO_RELEASE=20241108
ARG ODOO_SHA=919f386aa25f0a10d537f09c945349b20c502f73
RUN curl -o odoo.deb -sSL http://nightly.odoo.com/${ODOO_VERSION}/nightly/deb/odoo_${ODOO_VERSION}.${ODOO_RELEASE}_all.deb \
    && echo "${ODOO_SHA} odoo.deb" | sha1sum -c - \
    && apt-get update \
    && apt-get -y install --no-install-recommends ./odoo.deb \
    && rm -rf /var/lib/apt/lists/* odoo.deb

# Copia el script de entrada y el archivo de configuración de Odoo
COPY ./entrypoint.sh /
COPY ./odoo.conf /etc/odoo/

# Ajusta los permisos y monta /var/lib/odoo y /mnt/extra-addons para permitir la restauración de archivos y addons personalizados
RUN chmod +x /entrypoint.sh && \
    chown odoo /etc/odoo/odoo.conf \
    && mkdir -p /mnt/extra-addons \
    && chown -R odoo /mnt/extra-addons
VOLUME ["/var/lib/odoo", "/mnt/extra-addons"]

# Expone los puertos del servicio de Odoo
EXPOSE 8069 8071 8072

# Establece el archivo de configuración predeterminado
ENV ODOO_RC /etc/odoo/odoo.conf

COPY wait-for-psql.py /usr/local/bin/wait-for-psql.py

# Establece el usuario predeterminado cuando se ejecuta el contenedor
USER odoo

ENTRYPOINT ["/entrypoint.sh"]
CMD ["odoo"]
