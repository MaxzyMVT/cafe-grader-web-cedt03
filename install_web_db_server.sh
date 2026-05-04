#!/bin/bash
# Cafe-Grader Web/DB Server Installation Script (Server 1 of 3, Ubuntu 22.04+)
# Fully automated — the only manual step is a final  sudo reboot.
# Run as a normal user with sudo privileges, NOT as root.
#
# Usage: bash install_web_db_server.sh
#
# This server hosts the Rails web app and MySQL database.
# Worker nodes (install_worker_server.sh) connect to MySQL on this server.
# Do NOT run grader worker processes on this server.

set -e

# ---------------------------------------------------------------
# Configuration — edit before running if needed
# ---------------------------------------------------------------
CAFE_DIR="$HOME/cafe_grader"
RUBY_VERSION="3.4.4"
DB_NAME="grader"
DB_QUEUE="grader_queue"
DB_USER="grader_user"
DB_PASS="grader_pass"
REPO_URL="https://github.com/MaxzyMVT/cafe-grader-web.git"

LINUX_USER="$USER"
APP_DIR="$CAFE_DIR/web"

echo "============================================================"
echo " Cafe-Grader Web/DB Server Installation (Ubuntu 22.04+)"
echo "============================================================"

# ---------------------------------------------------------------
# 1. System packages (web/db only — no language compilers needed)
# ---------------------------------------------------------------
echo "[1/11] Installing system dependencies..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y \
  apache2 apache2-dev \
  mysql-server git software-properties-common \
  libmysqlclient-dev libcap-dev \
  apt-transport-https \
  postgresql postgresql-server-dev-all \
  openssl unzip curl

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
# 3. MySQL — local + remote access for worker nodes
# ---------------------------------------------------------------
echo "[3/11] Configuring MySQL for local and remote access..."
sudo systemctl start mysql || sudo service mysql start

# Allow all interfaces — restrict by firewall to worker IPs in production
sudo sed -i 's/^bind-address\s*=.*/bind-address = 0.0.0.0/' \
  /etc/mysql/mysql.conf.d/mysqld.cnf
sudo systemctl restart mysql || sudo service mysql restart

# Create databases
sudo mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;"
sudo mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`$DB_QUEUE\`;"

# localhost user (web app on this server)
sudo mysql -u root -e "DROP USER IF EXISTS '$DB_USER'@'localhost';"
sudo mysql -u root -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
sudo mysql -u root -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';"
sudo mysql -u root -e "GRANT ALL PRIVILEGES ON \`$DB_QUEUE\`.* TO '$DB_USER'@'localhost';"

# Wildcard user for worker nodes
sudo mysql -u root -e "DROP USER IF EXISTS '$DB_USER'@'%';"
sudo mysql -u root -e "CREATE USER '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS';"
sudo mysql -u root -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'%';"
sudo mysql -u root -e "GRANT ALL PRIVILEGES ON \`$DB_QUEUE\`.* TO '$DB_USER'@'%';"
sudo mysql -u root -e "FLUSH PRIVILEGES;"

echo "  NOTE: Firewall must allow TCP 3306 from worker IPs only."

# ---------------------------------------------------------------
# 4. Cafe-Grader app: clone + configure
# ---------------------------------------------------------------
echo "[4/11] Cloning and configuring Cafe-Grader..."
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
# SAMPLE defaults to  username: grader / password: grader  which will fail db:setup.
cp config/database.yml.SAMPLE config/database.yml
sed -i "s/username:.*/username: $DB_USER/" config/database.yml
sed -i "s/password:.*/password: $DB_PASS/" config/database.yml
sed -i "s/host:.*/host: localhost/"        config/database.yml
echo "  database.yml patched with DB credentials."

# Always regenerate and patch worker.yml
cp config/worker.yml.SAMPLE config/worker.yml
sed -i "s|web:.*|web: http://localhost|" config/worker.yml
echo "  worker.yml patched (web: http://localhost)."

# Silence Dart Sass @import deprecation warnings from Bootstrap.
cat > config/initializers/dartsass_silence_deprecations.rb <<'RUBYEOF'
Rails.application.config.dartsass.build_options \
  << "--silence-deprecation=import" \
  << "--silence-deprecation=global-builtin" \
  << "--silence-deprecation=color-functions" \
  << "--silence-deprecation=mixed-decls"
RUBYEOF
echo "  Dart Sass deprecation warnings silenced."

bundle install

# ---------------------------------------------------------------
# 5. Rails master key + credentials
# ---------------------------------------------------------------
echo "[5/11] Generating Rails master key..."
if [ ! -f config/master.key ]; then
  cp config/credentials.yml.SAMPLE config/credentials.yml.enc
  openssl rand -hex 32 > config/master.key
  chmod 600 config/master.key
  echo "  master.key generated."
  echo "  *** BACK UP $APP_DIR/config/master.key ***"
else
  echo "  master.key already exists, skipping."
fi

# ---------------------------------------------------------------
# 6. Database setup + asset compilation
# ---------------------------------------------------------------
echo "[6/11] Initialising database and compiling assets..."
cd "$APP_DIR"
RAILS_ENV=production bundle exec rails db:setup DISABLE_DATABASE_ENVIRONMENT_CHECK=1
RAILS_ENV=production bundle exec rails db:seed
RAILS_ENV=production bundle exec rails dartsass:build
RAILS_ENV=production bundle exec rails assets:precompile
echo "  Database and assets ready."

# ---------------------------------------------------------------
# 7. Phusion Passenger + Apache vhost
# ---------------------------------------------------------------
echo "[7/11] Installing Phusion Passenger and configuring Apache..."
gem install passenger --no-document

PASSENGER_INSTALL=$(gem contents passenger 2>/dev/null \
  | grep "passenger-install-apache2-module$" | head -1)
if [ -n "$PASSENGER_INSTALL" ]; then
  sudo "$(which ruby)" "$PASSENGER_INSTALL" --auto --languages ruby
else
  passenger-install-apache2-module --auto --languages ruby
fi

PASSENGER_ROOT=$(passenger-config --root)
PASSENGER_RUBY=$(which ruby)
PASSENGER_MODULE=$(find "$PASSENGER_ROOT" -name mod_passenger.so 2>/dev/null | head -1)

if [ -z "$PASSENGER_MODULE" ]; then
  echo "  WARNING: mod_passenger.so not found — Apache module may need manual setup."
  echo "  See: https://www.phusionpassenger.com/docs/tutorials/deploy_to_production/"
else
  sudo tee /etc/apache2/mods-available/passenger.load > /dev/null <<EOF
LoadModule passenger_module $PASSENGER_MODULE
EOF
  sudo tee /etc/apache2/mods-available/passenger.conf > /dev/null <<EOF
<IfModule mod_passenger.c>
  PassengerRoot $PASSENGER_ROOT
  PassengerDefaultRuby $PASSENGER_RUBY
</IfModule>
EOF
  sudo a2enmod passenger
fi

sudo a2dissite 000-default 2>/dev/null || true
sudo tee /etc/apache2/sites-available/cafe_grader.conf > /dev/null <<EOF
<VirtualHost *:80>
  ServerName localhost
  DocumentRoot $APP_DIR/public

  <Directory $APP_DIR/public>
    AllowOverride all
    Options -MultiViews
    Require all granted
  </Directory>

  PassengerEnabled on
  PassengerRuby $PASSENGER_RUBY
  PassengerEnvVar RAILS_ENV production

  ErrorLog \${APACHE_LOG_DIR}/cafe_grader_error.log
  CustomLog \${APACHE_LOG_DIR}/cafe_grader_access.log combined
</VirtualHost>
EOF

sudo a2ensite cafe_grader
sudo systemctl restart apache2
echo "  Apache + Passenger configured."

# ---------------------------------------------------------------
# 8. Solid Queue systemd service
# ---------------------------------------------------------------
echo "[8/11] Installing Solid Queue systemd service..."
sudo tee /etc/systemd/system/solid_queue.service > /dev/null <<EOF
[Unit]
Description=Solid Queue for Cafe-Grader
After=network.target mysql.service
Wants=mysql.service

[Service]
User=$LINUX_USER
WorkingDirectory=$APP_DIR
ExecStart=/bin/bash -lc 'bundle exec rails solid_queue:start'
Environment=RAILS_ENV=production
Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable solid_queue.service

# ---------------------------------------------------------------
# Done
# ---------------------------------------------------------------
echo ""
echo "============================================================"
echo " Web/DB Server installation complete!"
echo "============================================================"
echo ""
echo "  Default login  ->  username: root   password: ioionrails"
echo "  Change the password immediately after first login."
echo ""
echo "  Note this server's IP address — you will need it when"
echo "  running install_worker_server.sh on each worker node."
echo ""
echo "  ONE STEP REQUIRED:"
echo ""
echo "    sudo reboot"
echo ""
echo "  After reboot everything starts automatically:"
echo "    - Apache + Passenger   serves the web app on port 80"
echo "    - Solid Queue          processes background jobs"
echo "    (Do NOT start grader workers on this server.)"
echo ""
echo "  *** BACK UP: $APP_DIR/config/master.key ***"
echo ""