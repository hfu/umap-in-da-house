# uMap in-da-house Justfile
# For Raspberry Pi OS trixie 64bit on Raspberry Pi 4B
# Based on patterns from geosight-in-da-house

# Default variables - optimized for Raspberry Pi 4B
UMAP_DIR := "umap"
HTTP_PORT := "8000"
UMAP_VERSION := "3.4.2"
POSTGIS_VERSION := "14-3.4-alpine"

# Raspberry Pi optimized settings
COMPOSE_HTTP_TIMEOUT := "300"
DOCKER_CLIENT_TIMEOUT := "300"

# Default recipe: show available commands
default:
    @just --list

# Check prerequisites
_check-docker:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker is not installed. Run 'just install' first."
        exit 1
    fi
    if ! docker info &> /dev/null; then
        echo "❌ Docker daemon is not running or you don't have permission."
        echo "   Try: sudo systemctl start docker"
        echo "   Or: log out and log back in if you just added yourself to the docker group"
        exit 1
    fi

# Check if umap directory exists
_check-umap:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -d "{{UMAP_DIR}}" ]; then
        echo "❌ uMap directory not found. Run 'just install' first."
        exit 1
    fi

# Install all required packages and setup uMap
install:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Justfile variables
    UMAP_DIR="{{UMAP_DIR}}"
    HTTP_PORT="{{HTTP_PORT}}"
    UMAP_VERSION="{{UMAP_VERSION}}"
    POSTGIS_VERSION="{{POSTGIS_VERSION}}"
    
    echo "======================================"
    echo "  Installing uMap for Raspberry Pi"
    echo "======================================"
    echo ""
    
    # Update package lists
    echo "📦 Updating package lists..."
    sudo apt-get update
    
    # Install required packages
    echo "📦 Installing required packages..."
    sudo apt-get install -y \
        docker.io \
        docker-compose \
        curl \
        openssl \
        python3
    
    # Enable and start Docker
    echo "🐳 Enabling Docker service..."
    sudo systemctl enable docker
    sudo systemctl start docker
    
    # Add current user to docker group if not already
    if ! groups | grep -q docker; then
        echo "👤 Adding user to docker group..."
        sudo usermod -aG docker $USER
        echo ""
        echo "⚠️  IMPORTANT: Docker group membership added."
        echo "   Please log out and log back in, then run:"
        echo "   just install"
        echo ""
        exit 2
    fi
    
    # Verify docker works
    if ! docker info &> /dev/null; then
        echo "⚠️  Docker is running but you may need to log out and log back in"
        echo "   for group permissions to take effect."
        exit 1
    fi
    
    # Create uMap directory
    echo "📁 Creating uMap directory structure..."
    mkdir -p "$UMAP_DIR/docker"
    
    # Generate random secret key
    SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_hex(50))')
    
    # Create docker-compose.yml
    echo "🔧 Creating docker-compose.yml..."
    {
        echo "services:"
        echo "  redis:"
        echo "    image: redis:latest"
        echo "    healthcheck:"
        echo "      test: [\"CMD-SHELL\", \"redis-cli ping | grep PONG\"]"
        echo "      interval: 2s"
        echo "      timeout: 3s"
        echo "      retries: 5"
        echo "    command: [\"redis-server\"]"
        echo "    restart: unless-stopped"
        echo ""
        echo "  db:"
        echo "    image: postgis/postgis:${POSTGIS_VERSION}"
        echo "    healthcheck:"
        echo "      test: [\"CMD-SHELL\", \"pg_isready -U postgres\"]"
        echo "      interval: 2s"
        echo "      timeout: 3s"
        echo "      retries: 5"
        echo "    environment:"
        echo "      - POSTGRES_HOST_AUTH_METHOD=trust"
        echo "    volumes:"
        echo "      - umap_db:/var/lib/postgresql/data"
        echo "    restart: unless-stopped"
        echo ""
        echo "  app:"
        echo "    depends_on:"
        echo "      db:"
        echo "        condition: service_healthy"
        echo "      redis:"
        echo "        condition: service_healthy"
        echo "    image: umap/umap:${UMAP_VERSION}"
        echo "    environment:"
        echo "      - STATIC_ROOT=/srv/umap/static"
        echo "      - MEDIA_ROOT=/srv/umap/uploads"
        echo "      - DATABASE_URL=postgis://postgres@db/postgres"
        echo "      - SECRET_KEY=${SECRET_KEY}"
        echo "      - SITE_URL=http://localhost:${HTTP_PORT}/"
        echo "      - UMAP_ALLOW_ANONYMOUS=True"
        echo "      - DEBUG=0"
        echo "      - REALTIME_ENABLED=1"
        echo "      - REDIS_URL=redis://redis:6379"
        echo "    volumes:"
        echo "      - umap_data:/srv/umap/uploads"
        echo "      - umap_static:/srv/umap/static"
        echo "    restart: unless-stopped"
        echo ""
        echo "  proxy:"
        echo "    image: nginx:latest"
        echo "    ports:"
        echo "      - \"${HTTP_PORT}:80\""
        echo "    volumes:"
        echo "      - ./docker/nginx.conf:/etc/nginx/nginx.conf:ro"
        echo "      - umap_static:/static:ro"
        echo "      - umap_data:/data:ro"
        echo "    depends_on:"
        echo "      - app"
        echo "    restart: unless-stopped"
        echo ""
        echo "volumes:"
        echo "  umap_data:"
        echo "  umap_static:"
        echo "  umap_db:"
    } > "$UMAP_DIR/docker-compose.yml"
    
    # Copy nginx.conf from templates
    echo "🔧 Creating nginx.conf..."
    cp templates/nginx.conf "$UMAP_DIR/docker/nginx.conf"
    
    echo ""
    echo "======================================"
    echo "  ✅ Installation complete!"
    echo "======================================"
    echo ""
    echo "Next steps:"
    echo "  1. Run 'just run' to start uMap"
    echo "  2. Access http://localhost:${HTTP_PORT}/"
    echo ""
    echo "💡 Tip: Run 'just create-admin' to create an admin user"
    echo ""

# Run uMap
run: _check-docker _check-umap
    #!/usr/bin/env bash
    set -euo pipefail
    
    UMAP_DIR="{{UMAP_DIR}}"
    HTTP_PORT="{{HTTP_PORT}}"
    
    echo "======================================"
    echo "  Starting uMap"
    echo "======================================"
    echo ""
    
    cd "$UMAP_DIR"
    
    # Set Docker timeouts for Raspberry Pi (slower I/O)
    export COMPOSE_HTTP_TIMEOUT={{COMPOSE_HTTP_TIMEOUT}}
    export DOCKER_CLIENT_TIMEOUT={{DOCKER_CLIENT_TIMEOUT}}
    
    # Pull images
    echo "🐳 Pulling Docker images..."
    docker compose pull
    
    # Start containers
    echo "🚀 Starting Docker containers..."
    echo "   (This may take a few minutes on first run on Raspberry Pi)"
    echo ""
    docker compose up -d
    
    echo ""
    echo "⏳ Waiting for services to initialize..."
    sleep 30
    
    # Run migrations
    echo "🔧 Running database migrations..."
    docker compose exec -T app umap migrate
    
    # Collect static files
    echo "📦 Collecting static files..."
    docker compose exec -T app umap collectstatic --noinput
    
    echo ""
    echo "======================================"
    echo "  ✅ uMap is running!"
    echo "======================================"
    echo ""
    echo "🌐 Access uMap at: http://localhost:${HTTP_PORT}/"
    echo ""
    echo "Useful commands:"
    echo "  just stop          - Stop uMap"
    echo "  just status        - Show container status"
    echo "  just logs          - View logs"
    echo "  just create-admin  - Create admin user"
    echo "  just tunnel        - Expose to internet via Cloudflare"
    echo ""

# Stop uMap
stop: _check-umap
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🛑 Stopping uMap..."
    cd "{{UMAP_DIR}}"
    docker compose down
    echo "✅ uMap stopped"

# Restart uMap
restart: stop
    #!/usr/bin/env bash
    set -euo pipefail
    
    UMAP_DIR="{{UMAP_DIR}}"
    HTTP_PORT="{{HTTP_PORT}}"
    
    echo "🔄 Restarting uMap..."
    cd "$UMAP_DIR"
    
    export COMPOSE_HTTP_TIMEOUT={{COMPOSE_HTTP_TIMEOUT}}
    export DOCKER_CLIENT_TIMEOUT={{DOCKER_CLIENT_TIMEOUT}}
    
    docker compose up -d
    
    echo ""
    echo "⏳ Waiting for services to start..."
    sleep 15
    echo "✅ uMap restarted"
    echo ""
    echo "🌐 Access at: http://localhost:${HTTP_PORT}/"

# Uninstall uMap
uninstall:
    #!/usr/bin/env bash
    set -euo pipefail
    
    UMAP_DIR="{{UMAP_DIR}}"
    
    echo "======================================"
    echo "  Uninstalling uMap"
    echo "======================================"
    echo ""
    
    if [ -d "$UMAP_DIR" ]; then
        cd "$UMAP_DIR"
        
        # Stop and remove containers
        echo "🛑 Stopping and removing containers..."
        docker compose down 2>/dev/null || true
        
        cd ..
        
        # Remove Docker volumes
        echo "🗑️  Removing Docker volumes..."
        docker volume rm \
            umap_umap_data \
            umap_umap_static \
            umap_umap_db \
            2>/dev/null || true
        
        # Ask about removing the directory
        echo ""
        read -p "Remove uMap directory? This will delete all configuration. [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "🗑️  Removing uMap directory..."
            rm -rf "$UMAP_DIR"
            echo "✅ Directory removed"
        else
            echo "📁 Directory kept at: $UMAP_DIR"
        fi
    else
        echo "⚠️  uMap directory not found - nothing to uninstall"
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
    
    # Run install first
    just install
    INSTALL_EXIT=$?
    
    # If install exited with code 0, proceed to run
    if [ $INSTALL_EXIT -eq 0 ]; then
        echo ""
        echo "✅ Installation complete, proceeding to run..."
        just run
    else
        # Install exited early, likely due to docker group addition
        echo ""
        echo "⚠️  Installation requires re-login to apply docker group."
        echo "   After logging back in, run: just run"
        exit 0
    fi

# Create admin user
create-admin: _check-docker _check-umap
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "👤 Creating admin user..."
    cd "{{UMAP_DIR}}"
    docker compose exec app umap createsuperuser

# Create Cloudflare Tunnel for internet access
tunnel: _check-umap
    #!/usr/bin/env bash
    set -euo pipefail
    
    HTTP_PORT="{{HTTP_PORT}}"
    
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
    
    cloudflared tunnel --url "http://localhost:${HTTP_PORT}"

# Show container status
status: _check-docker
    #!/usr/bin/env bash
    set -euo pipefail
    
    UMAP_DIR="{{UMAP_DIR}}"
    
    echo "📊 uMap Container Status:"
    echo ""
    if [ -d "$UMAP_DIR" ]; then
        cd "$UMAP_DIR"
        docker compose ps
    else
        echo "⚠️  uMap directory not found. Run 'just install' first."
    fi

# View logs
logs: _check-umap
    #!/usr/bin/env bash
    set -euo pipefail
    
    cd "{{UMAP_DIR}}"
    docker compose logs -f

# Clean up Docker resources
clean:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🧹 Cleaning up Docker resources..."
    echo ""
    
    read -p "This will remove unused Docker resources. Continue? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker system prune -f
        echo "✅ Cleanup complete"
    else
        echo "Cleanup cancelled"
    fi

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
    if command -v docker &> /dev/null; then
        echo "Docker: $(docker --version)"
    else
        echo "Docker: Not installed"
    fi
    if [ -d "$UMAP_DIR" ]; then
        echo "uMap: Installed at ./$UMAP_DIR"
    else
        echo "uMap: Not installed"
    fi
