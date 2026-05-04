#!/bin/bash
# Cafe-Grader Worker Server Installation Script (Server 2 & 3, Ubuntu 22.04+)
# Fully automated — the only manual step is a final  sudo reboot.
# Run as a normal user with sudo privileges, NOT as root.
#
# Usage: bash install_worker_server.sh <WEB_DB_SERVER_IP>
# Example: bash install_worker_server.sh 10.0.0.1

set -e

# ---------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------
CAFE_DIR="$HOME/cafe_grader"
RUBY_VERSION="3.4.4"
DB_NAME="grader"
DB_USER="grader_user"
DB_PASS="grader_pass"
REPO_URL="https://github.com/MaxzyMVT/cafe-grader-web.git"
WEB_DB_IP="${1:-}"

if [ -z "$WEB_DB_IP" ]; then
  echo "ERROR: Please supply the Web/DB server's IP address as the first argument."
  echo "Usage: bash install_worker_server.sh <WEB_DB_SERVER_IP>"
  exit 1
fi

# Auto-detect worker count: CPU cores - 2, minimum 1
CPU_CORES=$(nproc)
WORKER_COUNT=$(( CPU_CORES > 2 ? CPU_CORES - 2 : 1 ))
LINUX_USER="$USER"
APP_DIR="$CAFE_DIR/web"

echo "============================================================"
echo " Cafe-Grader Worker Node Installation (Ubuntu 22.04+)"
echo " Web/DB server IP: $WEB_DB_IP"
echo " CPU cores: $CPU_CORES  |  Grader workers: $WORKER_COUNT"
echo "============================================================"

# ---------------------------------------------------------------
# 1. System packages (compilers only — no Apache or MySQL)
# ---------------------------------------------------------------
echo "[1/11] Installing system dependencies..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y \
  git software-properties-common \
  libmysqlclient-dev libcap-dev libsystemd-dev libseccomp-dev pkg-config \
  openssl curl unzip

# Language compilers / runtimes
sudo apt install -y \
  ghc g++ openjdk-21-jdk fpc \
  php-cli php-readline \
  golang-go cargo python3-venv

# ---------------------------------------------------------------
# 2. Ruby via rbenv
# ---------------------------------------------------------------
echo "[2/11] Installing rbenv and Ruby $RUBY_VERSION..."
sudo apt install -y \
  curl libssl-dev libreadline-dev zlib1g-dev \
  autoconf bison build-essential libyaml-dev \
  libncurses5-dev libffi-dev libgdbm-dev

if [ ! -d "$HOME/.rbenv" ]; then
  curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash
fi

export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

grep -qxF 'export PATH="$HOME/.rbenv/bin:$PATH"' ~/.bashrc || \
  echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
grep -qxF 'eval "$(rbenv init -)"' ~/.bashrc || \
  echo 'eval "$(rbenv init -)"' >> ~/.bashrc

rbenv install -s "$RUBY_VERSION"
rbenv global "$RUBY_VERSION"

# Remove stale system-level gem stubs that conflict with rbenv-managed Ruby.
if [ -d "$HOME/.gem/ruby" ]; then
  rm -rf "$HOME/.gem/ruby"
fi

gem install bundler --no-document

# ---------------------------------------------------------------
# 3. ioi/isolate
# ---------------------------------------------------------------
echo "[3/11] Building and installing ioi/isolate..."
if [ ! -d "/tmp/isolate" ]; then
  git clone https://github.com/ioi/isolate.git /tmp/isolate
fi
cd /tmp/isolate
make isolate
sudo make install

echo "  Disabling swap (required by isolate)..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# ---------------------------------------------------------------
# 4. Isolate systemd services + kernel settings
# ---------------------------------------------------------------
echo "[4/11] Configuring isolate kernel settings..."

ISOLATE_SVC="/tmp/isolate/systemd/isolate.service"
if [ -f "$ISOLATE_SVC" ]; then
  sudo ln -sf "$ISOLATE_SVC" /etc/systemd/system/isolate.service
fi

sudo tee /etc/systemd/system/set-ioi-isolate.service > /dev/null <<'SVCEOF'
[Unit]
Description=Set Transparent Hugepage and Core Pattern Settings for IOI isolate
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c "echo never > /sys/kernel/mm/transparent_hugepage/enabled; \
                      echo never > /sys/kernel/mm/transparent_hugepage/defrag; \
                      echo 0 > /sys/kernel/mm/transparent_hugepage/khugepaged/defrag; \
                      echo core > /proc/sys/kernel/core_pattern;"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SVCEOF

if ! grep -q "kernel.randomize_va_space" /etc/sysctl.d/99-sysctl.conf 2>/dev/null; then
  echo "# IOI isolate" | sudo tee -a /etc/sysctl.d/99-sysctl.conf
  echo "kernel.randomize_va_space=0" | sudo tee -a /etc/sysctl.d/99-sysctl.conf
fi

sudo systemctl daemon-reload
sudo systemctl enable set-ioi-isolate.service
[ -f /etc/systemd/system/isolate.service ] && sudo systemctl enable isolate.service

# ---------------------------------------------------------------
# 5. GRUB: enable cgroup memory support (required for isolate)
# ---------------------------------------------------------------
echo "[5/11] Patching GRUB for cgroup_enable=memory..."
if [ -f /etc/default/grub ]; then
  if ! grep -q "cgroup_enable=memory" /etc/default/grub; then
    sudo sed -i \
      's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 cgroup_enable=memory swapaccount=1"/' \
      /etc/default/grub
    sudo update-grub
    echo "  GRUB updated — takes effect after reboot."
  else
    echo "  cgroup_enable=memory already present, skipping."
  fi
else
  echo "  WARNING: /etc/default/grub not found — add cgroup_enable=memory manually."
fi

# ---------------------------------------------------------------
# 6. Cafe-Grader app: clone + configure for remote DB
# ---------------------------------------------------------------
echo "[6/11] Cloning and configuring Cafe-Grader (worker mode)..."
mkdir -p "$CAFE_DIR"
cd "$CAFE_DIR"
if [ ! -d "web" ]; then
  git clone "$REPO_URL" web
fi
cd web

# Copy sample configs
[ ! -f config/application.rb ] && cp config/application.rb.SAMPLE config/application.rb
[ ! -f config/llm.yml ]        && cp config/llm.yml.SAMPLE        config/llm.yml

# Always regenerate and patch database.yml.
# Patch all credential fields AND set host to the remote Web/DB server.
cp config/database.yml.SAMPLE config/database.yml
sed -i "s/username:.*/username: $DB_USER/" config/database.yml
sed -i "s/password:.*/password: $DB_PASS/" config/database.yml
sed -i "s/host:.*/host: $WEB_DB_IP/"       config/database.yml
echo "  database.yml patched — host: $WEB_DB_IP, user: $DB_USER."

# Always regenerate and patch worker.yml
cp config/worker.yml.SAMPLE config/worker.yml
sed -i "s|web:.*|web: http://$WEB_DB_IP|" config/worker.yml
echo "  worker.yml patched (web: http://$WEB_DB_IP)."

bundle install

# ---------------------------------------------------------------
# 7. Python venv for grader engine
# ---------------------------------------------------------------
echo "[7/11] Creating Python venv at /venv/grader..."
if [ ! -d "/venv/grader" ]; then
  sudo python3 -m venv /venv/grader
  sudo /venv/grader/bin/pip install --upgrade pip --quiet
  echo "  Python venv ready."
else
  echo "  /venv/grader already exists, skipping."
fi

# ---------------------------------------------------------------
# 8. Rails master key + credentials (needed to boot Rails runner)
# ---------------------------------------------------------------
echo "[8/11] Generating Rails master key..."
if [ ! -f config/master.key ]; then
  cp config/credentials.yml.SAMPLE config/credentials.yml.enc
  openssl rand -hex 32 > config/master.key
  chmod 600 config/master.key
  echo "  master.key generated."
  echo "  NOTE: This key is independent from Server 1's key — credentials"
  echo "  are not shared between servers, which is fine for worker nodes."
else
  echo "  master.key already exists, skipping."
fi

# ---------------------------------------------------------------
# 9. Post-reboot service: grader workers + whenever crontab
# ---------------------------------------------------------------
echo "[9/11] Installing post-reboot grader startup service..."
sudo tee /etc/systemd/system/cafe_grader_startup.service > /dev/null <<EOF
[Unit]
Description=Start Cafe-Grader grader workers after reboot
After=network.target

[Service]
Type=oneshot
User=$LINUX_USER
WorkingDirectory=$APP_DIR
ExecStart=/bin/bash -lc 'RAILS_ENV=production bundle exec rails r "Grader.restart($WORKER_COUNT)"'
ExecStart=/bin/bash -lc 'bundle exec whenever --update-crontab'
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable cafe_grader_startup.service

# ---------------------------------------------------------------
# 10. Isolate submission cleanup cron job
# ---------------------------------------------------------------
echo "[10/11] Installing isolate_submission cleanup cron job..."
CRON_JOB="0 2 * * * find $CAFE_DIR/judge/isolate_submission/ -maxdepth 1 -mtime +1 -exec rm -rf {} \; 2>/dev/null"
# Add only if not already present
( crontab -l 2>/dev/null | grep -qF "isolate_submission" ) || \
  ( crontab -l 2>/dev/null; echo "$CRON_JOB" ) | crontab -
echo "  Cleanup cron job installed (runs daily at 02:00)."

# ---------------------------------------------------------------
# Done
# ---------------------------------------------------------------
echo ""
echo "============================================================"
echo " Worker Node installation complete!"
echo "============================================================"
echo ""
echo "  ONE STEP REQUIRED:"
echo ""
echo "    sudo reboot"
echo ""
echo "  After reboot everything starts automatically:"
echo "    - $WORKER_COUNT grader worker(s)   evaluate code submissions"
echo "    - whenever crontab      runs Grader.watchdog every minute"
echo ""
echo "  Connecting to Web/DB server at: $WEB_DB_IP"
echo ""