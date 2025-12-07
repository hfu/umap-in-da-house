# uMap in-da-house Justfile
# For Raspberry Pi OS trixie 64bit on Raspberry Pi 4B
# Native installation (no Docker) following official uMap documentation

# Default variables - optimized for Raspberry Pi 4B
UMAP_DIR := "/opt/umap"
UMAP_VERSION := "3.4.2"
HTTP_PORT := "8100"
SITE_URL := "http://localhost:8100"
VENV_DIR := UMAP_DIR + "/venv"
DB_NAME := "umap"
DB_USER := "umap"

# Default recipe: show available commands
default:
    @just --list

# Check if umap is installed
_check-umap:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -d "{{UMAP_DIR}}" ]; then
        echo "❌ uMap directory not found. Run 'just install' first."
        exit 1
    fi
    if [ ! -d "{{VENV_DIR}}" ]; then
        echo "❌ uMap virtual environment not found. Run 'just install' first."
        exit 1
    fi
    if [ ! -f "/etc/systemd/system/umap.service" ]; then
        echo "❌ uMap systemd service not found. Run 'just install' first."
        exit 1
    fi

# Install all required packages, setup and start uMap
install:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Justfile variables
    UMAP_DIR="{{UMAP_DIR}}"
    UMAP_VERSION="{{UMAP_VERSION}}"
    HTTP_PORT="{{HTTP_PORT}}"
    VENV_DIR="{{VENV_DIR}}"
    DB_NAME="{{DB_NAME}}"
    DB_USER="{{DB_USER}}"
    
    echo "======================================"
    echo "  Installing uMap for Raspberry Pi"
    echo "  Native Installation (no Docker)"
    echo "======================================"
    echo "  uMap version: ${UMAP_VERSION}"
    echo "  Installation directory: ${UMAP_DIR}"
    echo "  HTTP port: ${HTTP_PORT}"
    echo "======================================"
    echo ""
    
    # Update package lists
    echo "📦 Updating package lists..."
    sudo apt-get update
    
    # Install required system packages
    echo "📦 Installing required packages..."
    sudo apt-get install -y \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        postgresql \
        postgresql-contrib \
        postgis \
        postgresql-postgis \
        git \
        build-essential \
        libpq-dev \
        libjpeg-dev \
        zlib1g-dev \
        curl \
        openssl
    
    # Enable and start PostgreSQL
    echo "🐘 Enabling PostgreSQL service..."
    sudo systemctl enable postgresql
    sudo systemctl start postgresql
    
    # Create PostgreSQL database and user
    echo "🗄️  Creating database and user..."
    sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname = '${DB_NAME}'" | grep -q 1 || \
        sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME};"
    
    sudo -u postgres psql -tc "SELECT 1 FROM pg_user WHERE usename = '${DB_USER}'" | grep -q 1 || \
        sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_USER}';"
    
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};"
    
    # Ensure database ownership and schema permissions (fixes permission denied during migrate)
    echo "🔐 Ensuring database owner and schema permissions..."
    sudo -u postgres psql -c "ALTER DATABASE ${DB_NAME} OWNER TO ${DB_USER};" || true
    sudo -u postgres psql -d "${DB_NAME}" -c "ALTER SCHEMA public OWNER TO ${DB_USER}; GRANT ALL ON SCHEMA public TO ${DB_USER};" || true
    
    # Enable PostGIS extension
    echo "🗺️  Enabling PostGIS extension..."
    sudo -u postgres psql -d "${DB_NAME}" -c "CREATE EXTENSION IF NOT EXISTS postgis;"
    
    # Create uMap directory
    echo "📁 Creating uMap directory..."
    sudo mkdir -p "${UMAP_DIR}"
    sudo chown -R $USER:$USER "${UMAP_DIR}"
    
    # Clone uMap repository
    echo "📦 Cloning uMap repository (version ${UMAP_VERSION})..."
    if [ -d "${UMAP_DIR}/.git" ]; then
        cd "${UMAP_DIR}"
        git fetch --tags
        git checkout "${UMAP_VERSION}"
    else
        git clone --depth 1 --branch "${UMAP_VERSION}" https://github.com/umap-project/umap.git "${UMAP_DIR}"
    fi
    
    cd "${UMAP_DIR}"
    
    # Create Python virtual environment
    echo "🐍 Creating Python virtual environment..."
    python3 -m venv "${VENV_DIR}"
    source "${VENV_DIR}/bin/activate"
    
    # Upgrade pip
    echo "📦 Upgrading pip..."
    pip install --upgrade pip setuptools wheel
    
    # Install uMap and dependencies
    echo "📦 Installing uMap and dependencies..."
    pip install -e .
    pip install psycopg2-binary gunicorn
    
    # Generate secret key
    echo "🔑 Generating secret key..."
    SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_urlsafe(50))')
    
    # Create uMap settings file
    echo "🔧 Creating uMap settings..."
    sudo mkdir -p /etc/umap
    {
        echo "# uMap configuration for Raspberry Pi"
        echo "from umap.settings.base import *"
        echo ""
        echo "SECRET_KEY = \"${SECRET_KEY}\""
        echo "DEBUG = False"
        echo "ALLOWED_HOSTS = [\"*\"]"
        echo ""
        echo "# Database"
        echo "DATABASES = {"
        echo "    \"default\": {"
        echo "        \"ENGINE\": \"django.contrib.gis.db.backends.postgis\","
        echo "        \"NAME\": \"${DB_NAME}\","
        echo "        \"USER\": \"${DB_USER}\","
        echo "        \"PASSWORD\": \"${DB_USER}\","
        echo "        \"HOST\": \"localhost\","
        echo "        \"PORT\": \"5432\","
        echo "    }"
        echo "}"
        echo ""
        echo "# Static and media files"
        echo "STATIC_ROOT = \"${UMAP_DIR}/static\""
        echo "MEDIA_ROOT = \"${UMAP_DIR}/uploads\""
        echo "STATIC_URL = \"/static/\""
        echo "MEDIA_URL = \"/uploads/\""
        echo ""
        echo "# Site configuration"
        echo "SITE_URL = \"{{SITE_URL}}\""
        echo "SHORT_SITE_URL = \"{{SITE_URL}}\""
        echo ""
        echo "# Allow anonymous users"
        echo "UMAP_ALLOW_ANONYMOUS = True"
        echo ""
        echo "# Custom template directory for overrides"
        echo "TEMPLATES[0]['DIRS'] = ['/etc/umap/templates']"
    } | sudo tee /etc/umap/settings.py > /dev/null
    
    # Create custom template directory and crypto.randomUUID polyfill
    echo "🔧 Creating custom template with crypto.randomUUID polyfill..."
    sudo mkdir -p /etc/umap/templates/umap
    {
        echo "{% load static %}"
        echo ""
        echo "{% autoescape off %}"
        echo "<script>"
        echo "// Polyfill for crypto.randomUUID() for older browsers"
        echo "if (typeof crypto === \"undefined\" || typeof crypto.randomUUID !== \"function\") {"
        echo "  (function() {"
        echo "    var getRandomValues = (typeof crypto !== \"undefined\" && crypto.getRandomValues)"
        echo "      ? crypto.getRandomValues.bind(crypto)"
        echo "      : function(arr) {"
        echo "          for (var i = 0; i < arr.length; i++) {"
        echo "            arr[i] = Math.floor(Math.random() * 256);"
        echo "          }"
        echo "          return arr;"
        echo "        };"
        echo "    "
        echo "    function randomUUID() {"
        echo "      var bytes = new Uint8Array(16);"
        echo "      getRandomValues(bytes);"
        echo "      bytes[6] = (bytes[6] & 0x0f) | 0x40;"
        echo "      bytes[8] = (bytes[8] & 0x3f) | 0x80;"
        echo "      var hex = Array.from(bytes).map(function(b) { return (\"0\" + b.toString(16)).slice(-2); }).join(\"\");"
        echo "      return hex.slice(0,8) + \"-\" + hex.slice(8,12) + \"-\" + hex.slice(12,16) + \"-\" + hex.slice(16,20) + \"-\" + hex.slice(20);"
        echo "    }"
        echo "    "
        echo "    if (typeof crypto === \"undefined\") {"
        echo "      window.crypto = { randomUUID: randomUUID, getRandomValues: getRandomValues };"
        echo "    } else {"
        echo "      crypto.randomUUID = randomUUID;"
        echo "    }"
        echo "  })();"
        echo "}"
        echo "</script>"
        echo ""
        echo "<script type=\"module\""
        echo "        src=\"{% static 'umap/vendors/leaflet/leaflet-src.esm.js' %}\""
        echo "        defer></script>"
        echo "<script type=\"module\""
        echo "        src=\"{% static 'umap/js/modules/leaflet-configure.js' %}\""
        echo "        defer></script>"
        echo "<script src=\"{% static 'umap/vendors/heat/leaflet-heat.js' %}\" defer></script>"
        echo "{% if locale %}"
        echo "  {% with \"umap/locale/\"|add:locale|add:\".js\" as path %}"
        echo "    <script src=\"{% static path %}\" defer></script>"
        echo "  {% endwith %}"
        echo "{% endif %}"
        echo "<script src=\"{% static 'umap/vendors/editable/Path.Drag.js' %}\" defer></script>"
        echo "<script src=\"{% static 'umap/vendors/editable/Leaflet.Editable.js' %}\" defer></script>"
        echo "<script type=\"module\" src=\"{% static 'umap/js/modules/global.js' %}\" defer></script>"
        echo "<script src=\"{% static 'umap/vendors/hash/leaflet-hash.js' %}\" defer></script>"
        echo "<script src=\"{% static 'umap/vendors/minimap/Control.MiniMap.min.js' %}\""
        echo "        defer></script>"
        echo "<script src=\"{% static 'umap/vendors/csv2geojson/csv2geojson.js' %}\" defer></script>"
        echo "<script src=\"{% static 'umap/vendors/osmtogeojson/osmtogeojson.js' %}\" defer></script>"
        echo "<script src=\"{% static 'umap/vendors/loading/Control.Loading.js' %}\" defer></script>"
        echo "<script src=\"{% static 'umap/vendors/photon/leaflet.photon.js' %}\" defer></script>"
        echo "<script src=\"{% static 'umap/vendors/fullscreen/Leaflet.fullscreen.min.js' %}\""
        echo "        defer></script>"
        echo "<script src=\"{% static 'umap/vendors/measurable/Leaflet.Measurable.js' %}\""
        echo "        defer></script>"
        echo "<script src=\"{% static 'umap/vendors/iconlayers/iconLayers.js' %}\" defer></script>"
        echo "<script src=\"{% static 'umap/vendors/locatecontrol/L.Control.Locate.min.js' %}\""
        echo "        defer></script>"
        echo "<script src=\"{% static 'umap/vendors/textpath/leaflet.textpath.js' %}\""
        echo "        defer></script>"
        echo "<script src=\"{% static 'umap/vendors/simple-statistics/simple-statistics.min.js' %}\""
        echo "        defer></script>"
        echo "<script src=\"{% static 'umap/js/umap.controls.js' %}\" defer></script>"
        echo "<script type=\"module\" src=\"{% static 'umap/js/components/fragment.js' %}\" defer></script>"
        echo "<script type=\"module\" src=\"{% static 'umap/js/components/modal.js' %}\" defer></script>"
        echo "<script type=\"module\" src=\"{% static 'umap/js/components/copiable.js' %}\" defer></script>"
        echo "{% endautoescape %}"
    } | sudo tee /etc/umap/templates/umap/js.html > /dev/null
    
    # Create directories for static and media files
    echo "📁 Creating static and media directories..."
    mkdir -p "${UMAP_DIR}/static"
    mkdir -p "${UMAP_DIR}/uploads"
    
    # Set environment variables for Django commands
    export DJANGO_SETTINGS_MODULE=umap.settings
    export UMAP_SETTINGS=/etc/umap/settings.py
    
    # Collect static files first (before migrations to avoid URL resolution issues)
    echo "📦 Collecting static files..."
    cd "${UMAP_DIR}"
    "${VENV_DIR}/bin/python" manage.py collectstatic --noinput --clear
    
    # Run Django migrations
    echo "🔧 Running database migrations..."
    "${VENV_DIR}/bin/python" manage.py migrate
    
    # Create systemd service
    echo "🔧 Creating systemd service..."
    {
        echo "[Unit]"
        echo "Description=uMap - OpenStreetMap based maps"
        echo "After=network.target postgresql.service"
        echo "Requires=postgresql.service"
        echo ""
        echo "[Service]"
        echo "Type=exec"
        echo "User=$USER"
        echo "Group=$USER"
        echo "WorkingDirectory=${UMAP_DIR}"
        echo "Environment=\"DJANGO_SETTINGS_MODULE=umap.settings\""
        echo "Environment=\"UMAP_SETTINGS=/etc/umap/settings.py\""
        echo "ExecStart=${VENV_DIR}/bin/gunicorn umap.wsgi:application --bind 0.0.0.0:${HTTP_PORT} --workers 2 --timeout 300 --access-logfile - --error-logfile -"
        echo "Restart=always"
        echo "RestartSec=10"
        echo ""
        echo "[Install]"
        echo "WantedBy=multi-user.target"
    } | sudo tee /etc/systemd/system/umap.service > /dev/null
    
    # Start services
    just start
    
    echo ""
    echo "======================================"
    echo "  ✅ Installation and startup complete!"
    echo "======================================"
    echo ""
    echo "🌐 Access uMap at: http://localhost/"
    echo ""
    echo "💡 Tip: Run 'just create-admin' to create an admin user"
    echo ""

# Start uMap services
start: _check-umap
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "======================================"
    echo "  Starting uMap"
    echo "======================================"
    echo ""
    
    # Reload systemd
    echo "🔄 Reloading systemd..."
    sudo systemctl daemon-reload
    
    # Start and enable uMap service
    echo "🚀 Starting uMap service..."
    sudo systemctl enable umap
    sudo systemctl start umap
    
    # Wait for service to be ready
    echo "⏳ Waiting for uMap to start..."
    sleep 5
    
    echo ""
    echo "======================================"
    echo "  ✅ uMap is running!"
    echo "======================================"
    echo ""
    echo "🌐 Access uMap at: http://localhost/"
    echo ""
    echo "Useful commands:"
    echo "  just stop          - Stop uMap"
    echo "  just status        - Show service status"
    echo "  just logs          - View logs"
    echo "  just create-admin  - Create admin user"
    echo "  just restart       - Restart uMap"
    echo ""

# Stop uMap services
stop: _check-umap
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🛑 Stopping uMap..."
    sudo systemctl stop umap
    echo "✅ uMap stopped"

# Restart uMap
restart: _check-umap
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🔄 Restarting uMap..."
    sudo systemctl restart umap
    
    echo "⌛ Waiting for service to start..."
    sleep 3
    echo "✅ uMap restarted"
    echo ""
    echo "🌐 Access at: http://localhost/"

# Uninstall uMap
uninstall:
    #!/usr/bin/env bash
    set -euo pipefail
    
    UMAP_DIR="{{UMAP_DIR}}"
    DB_NAME="{{DB_NAME}}"
    DB_USER="{{DB_USER}}"
    
    echo "======================================"
    echo "  Uninstalling uMap"
    echo "======================================"
    echo ""
    
    # Stop services
    echo "🛑 Stopping services..."
    sudo systemctl stop umap 2>/dev/null || true
    sudo systemctl disable umap 2>/dev/null || true
    
    # Remove systemd service
    echo "🗑️  Removing systemd service..."
    sudo rm -f /etc/systemd/system/umap.service
    sudo systemctl daemon-reload
    
    # Remove settings
    echo "🗑️  Removing settings..."
    sudo rm -rf /etc/umap
    
    # Ask about removing the directory
    echo ""
    read -p "Remove uMap directory (${UMAP_DIR})? This will delete all data. [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️  Removing uMap directory..."
        sudo rm -rf "$UMAP_DIR"
        echo "✅ Directory removed"
    else
        echo "📁 Directory kept at: $UMAP_DIR"
    fi
    
    # Ask about removing database
    echo ""
    read -p "Remove PostgreSQL database (${DB_NAME})? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️  Removing database..."
        sudo -u postgres psql -c "DROP DATABASE IF EXISTS ${DB_NAME};" || true
        sudo -u postgres psql -c "DROP USER IF EXISTS ${DB_USER};" || true
        echo "✅ Database removed"
    else
        echo "🗄️  Database kept"
    fi
    
    echo ""
    echo "✅ Uninstall complete"

# Create admin user (interactive or non-interactive)
# Usage:
#   just create-admin              (interactive)
#   just create-admin admin admin  (non-interactive with user/pass)
create-admin user='""' pass='""': _check-umap
    #!/usr/bin/env bash
    set -euo pipefail
    
    UMAP_DIR="{{UMAP_DIR}}"
    VENV_DIR="{{VENV_DIR}}"
    
    cd "${UMAP_DIR}"
    export DJANGO_SETTINGS_MODULE=umap.settings
    export UMAP_SETTINGS=/etc/umap/settings.py
    
    if [ -n "{{user}}" ] && [ -n "{{pass}}" ]; then
        echo "👤 Creating non-interactive admin user '{{user}}'..."
        (
            echo "from django.contrib.auth import get_user_model;"
            echo "User = get_user_model();"
            echo "if not User.objects.filter(username='{{user}}').exists():"
            echo "    User.objects.create_superuser('{{user}}', '{{user}}@example.com', '{{pass}}');"
            echo "    print('ADMIN_CREATED');"
            echo "else:"
            echo "    print('ADMIN_EXISTS');"
        ) | "${VENV_DIR}/bin/python" manage.py shell
    else
        echo "👤 Creating admin user (interactive)..."
        "${VENV_DIR}/bin/python" manage.py createsuperuser
    fi

# Access Django shell
shell: _check-umap
    #!/usr/bin/env bash
    set -euo pipefail
    
    UMAP_DIR="{{UMAP_DIR}}"
    VENV_DIR="{{VENV_DIR}}"
    
    cd "${UMAP_DIR}"
    export DJANGO_SETTINGS_MODULE=umap.settings
    export UMAP_SETTINGS=/etc/umap/settings.py
    "${VENV_DIR}/bin/python" manage.py shell

# Create Cloudflare Tunnel for internet access
tunnel: _check-umap
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "======================================"
    echo "  Creating Cloudflare Tunnel"
    echo "======================================"
    echo ""
    
    # Check if cloudflared is installed
    if ! command -v cloudflared &> /dev/null; then
        echo "📦 Installing cloudflared..."
        
        # Detect architecture
        ARCH=$(uname -m)
        if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
            CLOUDFLARED_ARCH="arm64"
        else
            CLOUDFLARED_ARCH="amd64"
        fi
        
        # Download and install cloudflared
        CLOUDFLARED_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CLOUDFLARED_ARCH}.deb"
        echo "   Downloading from: ${CLOUDFLARED_URL}"
        curl -L -o /tmp/cloudflared.deb "${CLOUDFLARED_URL}"
        sudo dpkg -i /tmp/cloudflared.deb
        rm /tmp/cloudflared.deb
        
        echo "✅ cloudflared installed"
    else
        echo "✅ cloudflared is already installed"
    fi
    
    echo ""
    echo "🌐 Starting Cloudflare Tunnel..."
    echo ""
    echo "   This will create a temporary public URL for your uMap instance."
    echo "   The URL will be displayed below after the tunnel is established."
    echo ""
    echo "   ⚠️  SECURITY WARNING:"
    echo "   - Anyone with this URL can access your uMap instance!"
    echo ""
    echo "   Press Ctrl+C to stop the tunnel."
    echo ""
    
    cloudflared tunnel --url "http://localhost:{{HTTP_PORT}}"

# Show service status
status:
    #!/usr/bin/env bash
    set -euo pipefail
    
    UMAP_DIR="{{UMAP_DIR}}"
    
    echo "📊 uMap Service Status:"
    echo ""
    if [ -d "$UMAP_DIR" ]; then
        sudo systemctl status umap --no-pager || true
    else
        echo "⚠️  uMap directory not found. Run 'just install' first."
    fi

# View logs
logs: _check-umap
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "📋 uMap logs (Ctrl+C to exit):"
    echo ""
    sudo journalctl -u umap -f

# Show system information
info:
    #!/usr/bin/env bash
    set -euo pipefail
    
    UMAP_DIR="{{UMAP_DIR}}"
    
    echo "======================================"
    echo "  System Information"
    echo "======================================"
    echo ""
    echo "Architecture: $(uname -m)"
    echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo "Kernel: $(uname -r)"
    echo ""
    echo "Memory:"
    free -h | head -2
    echo ""
    echo "Disk:"
    df -h / | tail -1
    echo ""
    if command -v python3 &> /dev/null; then
        echo "Python: $(python3 --version)"
    else
        echo "Python: Not installed"
    fi
    if command -v psql &> /dev/null; then
        echo "PostgreSQL: $(psql --version)"
    else
        echo "PostgreSQL: Not installed"
    fi
    if [ -d "$UMAP_DIR" ]; then
        echo "uMap: Installed at $UMAP_DIR"
        if [ -f "$UMAP_DIR/venv/bin/python" ]; then
            echo "Virtual env: Yes"
        fi
    else
        echo "uMap: Not installed"
    fi

# Show version information
version:
    #!/usr/bin/env bash
    set -euo pipefail
    
    UMAP_DIR="{{UMAP_DIR}}"
    
    echo "======================================"
    echo "  uMap in-da-house Version Info"
    echo "======================================"
    echo ""
    echo "Configured version: {{UMAP_VERSION}}"
    echo "Installation: Native (no Docker)"
    echo ""
    if [ -d "$UMAP_DIR" ]; then
        if sudo systemctl is-active --quiet umap; then
            echo "Service: Running"
        else
            echo "Service: Stopped"
        fi
    else
        echo "Status: Not installed"
    fi
