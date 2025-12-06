# uMap in-da-house Justfile
# For Raspberry Pi OS trixie 64bit on Raspberry Pi 4B
# Native installation (no Docker) following official uMap documentation

# Default variables - optimized for Raspberry Pi 4B
UMAP_DIR := "/opt/umap"
UMAP_VERSION := "3.4.2"
HTTP_PORT := "8000"
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

# Install all required packages and setup uMap
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
        nginx \
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
        echo "SITE_URL = \"http://localhost:${HTTP_PORT}\""
        echo "SHORT_SITE_URL = \"http://localhost:${HTTP_PORT}\""
        echo ""
        echo "# Allow anonymous users"
        echo "UMAP_ALLOW_ANONYMOUS = True"
    } | sudo tee /etc/umap/settings.py > /dev/null
    
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
        echo "ExecStart=${VENV_DIR}/bin/gunicorn umap.wsgi:application --bind 127.0.0.1:${HTTP_PORT} --workers 2 --timeout 300 --access-logfile - --error-logfile -"
        echo "Restart=always"
        echo "RestartSec=10"
        echo ""
        echo "[Install]"
        echo "WantedBy=multi-user.target"
    } | sudo tee /etc/systemd/system/umap.service > /dev/null
    
    # Configure nginx
    echo "🔧 Configuring nginx..."
    {
        echo "server {"
        echo "    listen 80;"
        echo "    server_name _;"
        echo "    client_max_body_size 20M;"
        echo ""
        echo "    location /static/ {"
        echo "        alias ${UMAP_DIR}/static/;"
        echo "        expires 365d;"
        echo "        access_log off;"
        echo "    }"
        echo ""
        echo "    location /uploads/ {"
        echo "        alias ${UMAP_DIR}/uploads/;"
        echo "        expires 30d;"
        echo "    }"
        echo ""
        echo "    location / {"
        echo "        proxy_pass http://127.0.0.1:${HTTP_PORT};"
        echo "        proxy_set_header Host \$host;"
        echo "        proxy_set_header X-Real-IP \$remote_addr;"
        echo "        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;"
        echo "        proxy_set_header X-Forwarded-Proto \$scheme;"
        echo "    }"
        echo "}"
    } | sudo tee /etc/nginx/sites-available/umap > /dev/null
    
    # Enable nginx site
    sudo ln -sf /etc/nginx/sites-available/umap /etc/nginx/sites-enabled/umap
    sudo rm -f /etc/nginx/sites-enabled/default
    
    # Test nginx configuration
    sudo nginx -t
    
    echo ""
    echo "======================================"
    echo "  ✅ Installation complete!"
    echo "======================================"
    echo ""
    echo "Next steps:"
    echo "  1. Run 'just run' to start uMap"
    echo "  2. Access http://localhost/"
    echo ""
    echo "💡 Tip: Run 'just create-admin' to create an admin user"
    echo ""

# Start uMap services
run: _check-umap
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
    
    # Start and enable nginx
    echo "🌐 Starting nginx..."
    sudo systemctl enable nginx
    sudo systemctl start nginx
    
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
    sudo systemctl stop nginx
    echo "✅ uMap stopped"

# Restart uMap
restart: _check-umap
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🔄 Restarting uMap..."
    sudo systemctl restart umap
    sudo systemctl restart nginx
    
    echo "⏳ Waiting for services to start..."
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
    
    # Remove nginx configuration
    echo "🗑️  Removing nginx configuration..."
    sudo rm -f /etc/nginx/sites-enabled/umap
    sudo rm -f /etc/nginx/sites-available/umap
    sudo systemctl restart nginx 2>/dev/null || true
    
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

# Run install and then run (full setup)
doit:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "======================================"
    echo "  Full uMap Setup (doit)"
    echo "======================================"
    echo ""
    
    # Run install
    just install
    
    # Run
    echo ""
    echo "✅ Installation complete, starting uMap..."
    just run

# Create admin user
create-admin: _check-umap
    #!/usr/bin/env bash
    set -euo pipefail
    
    UMAP_DIR="{{UMAP_DIR}}"
    VENV_DIR="{{VENV_DIR}}"
    
    echo "👤 Creating admin user..."
    cd "${UMAP_DIR}"
    export DJANGO_SETTINGS_MODULE=umap.settings
    export UMAP_SETTINGS=/etc/umap/settings.py
    "${VENV_DIR}/bin/python" manage.py createsuperuser

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
    
    cloudflared tunnel --url "http://localhost:80"

# Show service status
status:
    #!/usr/bin/env bash
    set -euo pipefail
    
    UMAP_DIR="{{UMAP_DIR}}"
    
    echo "📊 uMap Service Status:"
    echo ""
    if [ -d "$UMAP_DIR" ]; then
        sudo systemctl status umap --no-pager || true
        echo ""
        sudo systemctl status nginx --no-pager || true
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

# View nginx logs
logs-nginx: _check-umap
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "📋 Nginx logs (Ctrl+C to exit):"
    echo ""
    sudo tail -f /var/log/nginx/access.log /var/log/nginx/error.log

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
