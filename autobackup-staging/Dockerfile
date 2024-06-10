ARG BUILD_FROM=ghcr.io/hassio-addons/base:14.0.7
# hadolint ignore=DL3006
FROM ${BUILD_FROM}

# Install requirements for add-on
RUN apk add --no-cache \
  coreutils=9.3-r2 \
  wget=1.21.4-r0 \
  python3 py3-pip

# Install bash, uuid-runtime (uuidgen in Alpine is part of the util-linux package), curl, jq
# and nginx. Note that Alpine uses apk instead of apt
RUN apk add --no-cache bash util-linux nginx

# Install gcc and musl-dev for compiling Python packages, if necessary for Flask extensions
RUN apk add --no-cache gcc musl-dev

# Copy the requirements file
COPY ./requirements.txt /requirements.txt

# Install Flask and other Python dependencies from the requirements file
RUN pip install -r requirements.txt

# Copy the run script, backup script, and start script
COPY api.sh /api.sh
COPY start.sh /start.sh
COPY compare.sh /compare.sh

# Copy the flask app
COPY app.py /app.py

# Copy the templates directory
COPY templates /templates

# Since you mentioned nginx configuration, adjust the path according to where nginx expects it in Alpine
# Adjust the nginx configuration path as per Alpine's nginx package structure
COPY ingress.conf /etc/nginx/conf.d/default.conf

# Set up a directory for the Nginx run files (might not be necessary in Alpine as the nginx package takes care of this)
RUN mkdir -p /run/nginx

# Make the run script, backup script, and start script executable
RUN chmod a+x /api.sh /start.sh /compare.sh

# Build arguments
ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_DESCRIPTION
ARG BUILD_NAME
ARG BUILD_REF
ARG BUILD_REPOSITORY
ARG BUILD_VERSION

# Labels
LABEL \
  io.hass.name="${BUILD_NAME}" \
  io.hass.description="${BUILD_DESCRIPTION}" \
  io.hass.arch="${BUILD_ARCH}" \
  io.hass.type="addon" \
  io.hass.version=${BUILD_VERSION} \
  org.opencontainers.image.title="${BUILD_NAME}" \
  org.opencontainers.image.description="${BUILD_DESCRIPTION}" \
  org.opencontainers.image.created=${BUILD_DATE} \
  org.opencontainers.image.revision=${BUILD_REF} \
  org.opencontainers.image.version=${BUILD_VERSION}

# Use start.sh as the default command
CMD ["/start.sh"]
