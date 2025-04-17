#!/bin/sh

# Exit on error
set -e

# Initialize skip flags
SKIP_WLSLEEPHANDLER=""
SKIP_FM=""
SKIP_ORCHIS_GTK=""
SKIP_VIMIX=""

# Ensure root
[ "$(id -u)" != "0" ] && { echo "This script must be run as root" >&2; exit 1; }

# Configure repositories
echo "Configuring package repositories..."
cat > /etc/apk/repositories << EOF
https://dl-cdn.alpinelinux.org/alpine/edge/main
https://dl-cdn.alpinelinux.org/alpine/edge/community
https://dl-cdn.alpinelinux.org/alpine/edge/testing
EOF
apk update || { echo "Failed to update package repositories" >&2; exit 1; }

# Install Wayland base and additional packages
echo "Installing packages..."
setup-wayland-base || { echo "Failed to install Wayland base" >&2; exit 1; }
apk add --no-cache \
  labwc sfwbar foot badwolf greetd-gtkgreet wbg waylock \
  mupdf mako lite-xl image-roll drawing font-roboto wofi \
  greetd cage polkit tlp wlr-randr upower iw util-linux \
  pipewire wireplumber pipewire-alsa pipewire-pulse alsa-lib alsa-utils \
  clipman grim slurp xdg-desktop-portal-wlr papirus-icon-theme \
  bluez blueman linux-firmware pavucontrol \
  xdotool bash celluloid \
  rust cargo git musl-dev pkgconf lua-dev make sdl2-dev \
  g++ gtk4.0-dev libpanel-dev libadwaita-dev gtksourceview5-dev poppler-glib poppler-dev eudev-dev || { echo "Failed to install packages" >&2; exit 1; }

# Define runtime dependencies
RUNTIME_DEPS="labwc sfwbar foot badwolf greetd-gtkgreet wbg waylock mupdf mako \
  drawing font-roboto wofi greetd cage polkit tlp wlr-randr upower iw util-linux \
  pipewire wireplumber pipewire-alsa pipewire-pulse alsa-lib alsa-utils clipman grim slurp \
  xdg-desktop-portal-wlr papirus-icon-theme \
  bluez blueman linux-firmware pavucontrol xdotool celluloid poppler-glib"

# Function to retry git clone
retry_git_clone() {
  local url=$1
  local branch=$2
  local dest=$3
  local max_attempts=3
  local attempt=1
  while [ $attempt -le $max_attempts ]; do
    echo "Attempt $attempt: Cloning $url (branch: $branch) to $dest..."
    if git clone --branch "$branch" "$url" "$dest"; then
      return 0
    fi
    echo "Clone failed, retrying in 5 seconds..." >&2
    sleep 5
    attempt=$((attempt + 1))
  done
  echo "Error: Failed to clone $url after $max_attempts attempts" >&2
  return 1
}

# Install wlsleephandler-rs
echo "Installing wlsleephandler-rs..."
cargo install --git https://github.com/fishman/sleepwatcher-rs --locked || {
  echo "Warning: wlsleephandler-rs installation failed" >&2
  SKIP_WLSLEEPHANDLER=1
}

# Install fm
if ! command -v fm >/dev/null 2>&1; then
  echo "Building fm..."
  mkdir -p /tmp/fm && cd /tmp/fm
  retry_git_clone "https://github.com/euclio/fm.git" "master" "fm" || { echo "Error: fm clone failed" >&2; SKIP_FM=1; }
  if [ -z "$SKIP_FM" ]; then
    cd fm
    [ ! -f Cargo.toml ] && { echo "Error: Cargo.toml not found" >&2; SKIP_FM=1; }
    [ -z "$SKIP_FM" ] && {
      cargo install --path . --root=/usr || { echo "Error: fm build/install failed" >&2; SKIP_FM=1; }
    }
  fi
  cd /tmp
fi

# Install Orchis GTK theme and wallpaper
echo "Installing Orchis GTK theme and wallpaper..."
mkdir -p /tmp/orchis && cd /tmp/orchis
retry_git_clone "https://github.com/vinceliuice/Orchis-theme.git" "master" "Orchis-theme" || { echo "Error: Orchis GTK clone failed" >&2; exit 1; }
cd Orchis-theme
mkdir -p /usr/share/themes/Orchis-Dark
[ -d "src/gtk-3.0" ] && cp -r src/gtk-3.0/* /usr/share/themes/Orchis-Dark/ || { echo "Warning: Orchis GTK 3.0 copy failed" >&2; SKIP_ORCHIS_GTK=1; }
[ -d "src/gtk-4.0" ] && cp -r src/gtk-4.0/* /usr/share/themes/Orchis-Dark/ || { echo "Warning: Orchis GTK 4.0 copy failed" >&2; SKIP_ORCHIS_GTK=1; }
[ -f "src/gtk-3.0/gtk.css" ] && sed -i 's/gtk-theme-name=.*/gtk-theme-name=Orchis-Dark/' src/gtk-3.0/gtk.css
[ -f "src/gtk-4.0/gtk.css" ] && sed -i 's/gtk-theme-name=.*/gtk-theme-name=Orchis-Dark/' src/gtk-4.0/gtk.css
for res in "1080p" "2k" "4k"; do
  [ -f "wallpaper/$res.jpg" ] && { mkdir -p /usr/share/backgrounds; cp "wallpaper/$res.jpg" /usr/share/backgrounds/orchis-wallpaper.jpg && break; }
done
[ ! -f /usr/share/backgrounds/orchis-wallpaper.jpg ] && {
  echo "Warning: Orchis wallpaper not found, using fallback" >&2
  mkdir -p /usr/share/backgrounds
  echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==" | base64 -d > /usr/share/backgrounds/orchis-wallpaper.jpg
}
cd /tmp

# Install Vimix cursor themes
echo "Installing Vimix cursor themes..."
mkdir -p /tmp/vimix-cursors && cd /tmp/vimix-cursors
retry_git_clone "https://github.com/vinceliuice/Vimix-cursors.git" "2020-10-10" "Vimix-cursors" || { echo "Error: Vimix cursors clone failed" >&2; exit 1; }
cd Vimix-cursors
if [ -f "install.sh" ]; then
  /bin/bash install.sh || {
    echo "Warning: Vimix cursors install failed, attempting fallback" >&2
    mkdir -p /usr/share/icons
    [ -d "dist" ] && cp -r dist/* /usr/share/icons/ || true
    [ -d "dist-white" ] && cp -r dist-white/* /usr/share/icons/ || {
      echo "Error: Vimix cursors fallback failed" >&2
      mkdir -p /usr/share/icons/Vimix-White
      echo "[Icon Theme]\nName=Vimix-White\nComment=Minimal Vimix cursor theme\nInherits=default" > /usr/share/icons/Vimix-White/index.theme
      SKIP_VIMIX=1
    }
  }
else
  echo "Error: Vimix install.sh not found" >&2
  mkdir -p /usr/share/icons/Vimix-White
  echo "[Icon Theme]\nName=Vimix-White\nComment=Minimal Vimix cursor theme\nInherits=default" > /usr/share/icons/Vimix-White/index.theme
  SKIP_VIMIX=1
fi
cd /tmp

# Configure Bluetooth
echo "Configuring Bluetooth..."
rc-update add bluetooth default
cat > /etc/bluetooth/main.conf << EOL
[General]
Name=AlpineWayland
DiscoverableTimeout=0
AlwaysPairable=true
Auto-enable=true
[Policy]
AutoEnable=true
EOL
echo "uinput" >> /etc/modules

# Configure TLP
echo "Configuring TLP..."
rc-update add tlp default
cat > /etc/tlp.conf << EOL
TLP_DEFAULT_MODE=BAT
CPU_SCALING_GOVERNOR_ON_BAT=powersave
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power
CPU_ENERGY_PERF_POLICY_ON_AC=performance
PLATFORM_PROFILE_ON_BAT=low-power
PLATFORM_PROFILE_ON_AC=balanced
WIFI_PWR_ON_BAT=on
WIFI_PWR_ON_AC=off
RUNTIME_PM_ON_BAT=auto
RUNTIME_PM_ON_AC=on
USB_AUTOSUSPEND=1
USB_DENYLIST="usbhid"
SATA_LINKPWR_ON_BAT=min_power
SATA_LINKPWR_ON_AC=max_performance
SOUND_POWER_SAVE_ON_BAT=1
SOUND_POWER_SAVE_ON_AC=0
EOL

# Configure sound services
echo "Configuring sound services..."
for svc in pipewire wireplumber; do
  if ! rc-service $svc status >/dev/null 2>&1; then
    cat > /etc/init.d/$svc << EOL
#!/sbin/openrc-run
description="$svc Multimedia Service"
command=/usr/bin/$svc
command_background=true
pidfile=/run/$svc.pid
depend() {
    need dbus
    after network-online
}
EOL
    chmod +x /etc/init.d/$svc
    rc-update add $svc default
  fi
done
rc-update add alsa default
alsactl init
echo "defaults.pcm.card 0\ndefaults.ctl.card 0" > /etc/asound.conf

# Configure services
echo "Configuring session services..."
for svc in elogind dbus polkit greetd local crond; do
  rc-update add $svc default || echo "Warning: Failed to add $svc to boot services" >&2
done
setup-devd udev || echo "Warning: Failed to configure udev" >&2

# Configure PAM
echo "Configuring PAM..."
cat > /etc/pam.d/greetd << EOL
auth       required   pam_rundir.so
auth       required   pam_unix.so
account    required   pam_unix.so
session    required   pam_rundir.so
session    required   pam_limits.so
session    required   pam_env.so
session    required   pam_unix.so
EOL

# Configure greetd
echo "Configuring greetd..."
cat > /etc/greetd/config.toml << EOL
[terminal]
vt = "next"
switch = true
[default_session]
command = "cage -s -- env GTK_THEME=Orchis-Dark XCURSOR_THEME=Vimix-White gtkgreet --style /etc/greetd/gtkgreet.css"
user = "greetd"
EOL
echo "dbus-run-session -- labwc" > /etc/greetd/environments
for group in video seat input bluetooth; do addgroup greetd $group || true; done

# User setup
echo "User configuration..."
USER_NAME="user"
USER_HOME="/home/$USER_NAME"
setup-user -a -g "audio,bluetooth,pipewire,video,input" "$USER_NAME" || { echo "Failed to create user" >&2; exit 1; }
mkdir -p "$USER_HOME/.config/"{labwc,sfwbar,foot,wlsleephandler-rs,badwolf,mako,clipman,gtk-3.0,gtk-4.0,wofi}
chown -R "$USER_NAME:$USER_NAME" "$USER_HOME"

# Check for user existence
users=$(awk -F: '{if ($3<65000 && $3>=1000) print $1}' /etc/passwd 2>/dev/null)
if [ -z "$users" ]; then
  echo "WARNING: No user account found. Please run: setup-user" >&2
  echo "" >&2
fi

# Configure wlsleephandler-rs or fallback
if [ -z "$SKIP_WLSLEEPHANDLER" ] && command -v wlsleephandler-rs >/dev/null 2>&1; then
  echo "Configuring wlsleephandler-rs..."
  cat > "$USER_HOME/.config/wlsleephandler-rs/config.toml" << EOL
[suspend]
idle_timeout = 300
command = "loginctl suspend"
[lock]
idle_timeout = 120
command = "waylock -fork-on-lock"
EOL
  AUTOSTART="dbus-run-session -- wlsleephandler-rs &"
else
  echo "Configuring fallback idle suspend..."
  cat > /usr/local/bin/idle-suspend.sh << EOL
#!/bin/sh
while true; do
  if loginctl show-session -p IdleHint 2>/dev/null | grep -q "IdleHint=yes"; then
    waylock -fork-on-lock
    loginctl suspend
    sleep 10
  fi
  sleep 60
done
EOL
  AUTOSTART="dbus-run-session -- idle-suspend.sh &"
fi

# Configure GTK theme
if [ -z "$SKIP_ORCHIS_GTK" ]; then
  for ver in 3.0 4.0; do
    cat > "$USER_HOME/.config/gtk-$ver/settings.ini" << EOL
[Settings]
gtk-theme-name=Orchis-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-name=Vimix-White
gtk-font-name=Roboto 10
gtk-application-prefer-dark-theme=true
gtk-button-images=true
gtk-menu-images=true
EOL
  done
  ln -sf /usr/share/themes/Orchis-Dark/gtk-4.0 "$USER_HOME/.config/gtk-4.0"
fi

# Configure gtkgreet
cat > /etc/greetd/gtkgreet.css << EOL
window {
  background: rgba(48,49,52,0.9);
  backdrop-filter: blur(4px);
}
#box {
  background: #202124;
  border-radius: 8px;
  padding: 16px;
  margin: auto;
  width: 400px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.2);
}
#entry, #combo {
  background: #3C4043;
  color: #FFFFFF;
  border-radius: 4px;
  padding: 8px;
  margin: 8px;
}
#button {
  background: #3C4043;
  color: #FFFFFF;
  border-radius: 4px;
  padding: 8px;
}
#button:hover {
  background: #8AB4F8;
  box-shadow: 0 1px 2px rgba(0,0,0,0.1);
}
EOL

# Configure wallpaper color
cat > /usr/local/bin/wallpaper-color.sh << EOL
#!/bin/sh
WALLPAPER="/usr/share/backgrounds/orchis-wallpaper.jpg"
[ -f "$WALLPAPER" ] && magick "$WALLPAPER" -resize 1x1 txt: | grep -o "#[0-9A-F]\{6\}" | head -1 || echo "#8AB4F8"
EOL

# Configure tray popup
cat > /usr/local/bin/tray-popup.sh << EOL
#!/bin/sh
BRIGHTNESS_DEV=$(ls /sys/class/backlight/* 2>/dev/null | head -1)
[ -n "$BRIGHTNESS_DEV" ] && {
  MAX_BRIGHTNESS=$(cat "$BRIGHTNESS_DEV/max_brightness")
  BRIGHTNESS_PERCENT=$(( $(cat "$BRIGHTNESS_DEV/brightness") * 100 / MAX_BRIGHTNESS ))
} || BRIGHTNESS_PERCENT=50
echo "popup {"
echo "  label { text = 'Quick Settings'; font = 'Roboto 12'; color = '#FFFFFF'; }"
echo "  button { text = 'Wi-Fi'; exec = '/usr/local/bin/wifi-toggle.sh'; }"
echo "  button { text = 'Volume'; exec = '/usr/local/bin/volume-toggle.sh'; }"
echo "  button { text = 'Bluetooth'; exec = '/usr/local/bin/bluetooth-toggle.sh'; }"
[ -n "$BRIGHTNESS_DEV" ] && echo "  scale { min = 0; max = 100; value = $BRIGHTNESS_PERCENT; exec = 'echo %d > $BRIGHTNESS_DEV/brightness'; }"
echo "}"
sfwbar -s Network
EOL

# Configure labwc
cat > "$USER_HOME/.config/labwc/rc.xml" << EOL
<?xml version="1.0"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <theme><cornerRadius>4</cornerRadius><titleLayout>#202124</titleLayout><shadow>true</shadow></theme>
  <keyboard>
    <keybind key="Super_L"><action name="Execute"><execute>wofi --show drun</execute></action></keybind>
    <keybind key="Super-space"><action name="Execute"><execute>wofi --show drun</execute></action></keybind>
    <keybind key="Super-d"><action name="ToggleShowDesktop"/></keybind>
    <keybind key="A-Tab"><action name="NextWindow"/></keybind>
    <keybind key="F3"><action name="NextWindow"/></keybind>
    <keybind key="A-F4"><action name="Close"/></keybind>
    <keybind key="Super-e"><action name="Execute"><execute>fm</execute></action></keybind>
    <keybind key="Super-l"><action name="Execute"><execute>waylock</execute></action></keybind>
    <keybind key="Print"><action name="Execute"><execute>grim -g "$(slurp)" /home/$USER_NAME/screenshot-$(date +%s).png</execute></action></keybind>
    <keybind key="Super-Left"><action name="SnapToEdge"><direction>Left</direction></action></keybind>
    <keybind key="Super-Right"><action name="SnapToEdge"><direction>Right</direction></action></keybind>
    <keybind key="Super-r"><action name="Execute"><execute>wofi --show run</execute></action></keybind>
    <keybind key="Super-s"><action name="Execute"><execute>/usr/local/bin/tray-popup.sh</execute></action></keybind>
    <keybind key="Super-b"><action name="Execute"><execute>xdotool key Alt+Left</execute></action></keybind>
    <keybind key="Super-n"><action name="Execute"><execute>makoctl restore</execute></action></keybind>
    <keybind key="Super-t"><action name="Execute"><execute>/usr/local/bin/toggle-theme.sh</execute></action></keybind>
  </keyboard>
  <animations><fadeWindows>true</fadeWindows><fadeMenus>true</fadeMenus></animations>
</openbox_config>
EOL
cat > "$USER_HOME/.config/labwc/menu.xml" << EOL
<?xml version="1.0" encoding="UTF-8"?>
<openbox_menu>
  <menu id="root-menu" label="Menu">
    <item label="Terminal"><action name="Execute"><execute>foot</execute></action></item>
    <item label="Browser"><action name="Execute"><execute>badwolf</execute></action></item>
    $( [ -z "$SKIP_FM" ] && echo '<item label="Files"><action name="Execute"><execute>fm</execute></action></item>' )
    <item label="Player"><action name="Execute"><execute>celluloid</execute></action></item>
    <item label="Drawing"><action name="Execute"><execute>drawing</execute></action></item>
    <item label="PDF"><action name="Execute"><execute>mupdf</execute></action></item>
    <item label="Editor"><action name="Execute"><execute>lite-xl</execute></action></item>
    <item label="Images"><action name="Execute"><execute>image-roll</execute></action></item>
    <item label="Bluetooth"><action name="Execute"><execute>blueman-manager</execute></action></item>
    <item label="Audio"><action name="Execute"><execute>pavucontrol</execute></action></item>
    <item label="Screenshot"><action name="Execute"><execute>grim -g \"$(slurp)\" /home/$USER_NAME/screenshot-$(date +%s).png</execute></action></item>
    <item label="Exit"><action name="Execute"><execute>labwc -e</execute></action></item>
  </menu>
</openbox_menu>
EOL
cat > "$USER_HOME/.config/labwc/environment" << EOL
XDG_SESSION_TYPE=wayland
XDG_SESSION_DESKTOP=labwc
XDG_CURRENT_DESKTOP=labwc:wlroots
WAYLAND_DISPLAY=wayland-0
GDK_BACKEND=wayland,x11
SDL_VIDEODRIVER=wayland
_JAVA_AWT_WM_NONREPARENTING=1
XCURSOR_THEME=Vimix-White
EOL

# Configure sfwbar
cat > "$USER_HOME/.config/sfwbar/sfwbar.config" << EOL
[bar]
location = bottom
height = 48
auto_hide = true
exclusive = true
css = "sfwbar.css"
modules_left = Launcher TaskBar
modules_right = Network Volume Bluetooth Battery Clock Tray
[Launcher]
icon = start-here
exec = wofi --show drun
[TaskBar]
icon_size = 32
pins = foot badwolf fm celluloid drawing mupdf blueman-manager pavucontrol
[Network]
interval = 10
show_icon = true
exec = /usr/local/bin/wifi-popup.sh
action = /usr/local/bin/wifi-toggle.sh
[Volume]
interval = 5
show_icon = true
exec = /usr/local/bin/volume-popup.sh
action = /usr/local/bin/volume-toggle.sh
[Bluetooth]
interval = 10
show_icon = true
exec = /usr/local/bin/bluetooth-popup.sh
action = /usr/local/bin/bluetooth-toggle.sh
[Battery]
interval = 30
show_icon = true
show_percentage = true
[Clock]
interval = 60
format = %H:%M
[Tray]
icon_size = 24
EOL
cat > "$USER_HOME/.config/sfwbar/sfwbar.css" << EOL
* {
  font: Roboto 12;
  color: #FFFFFF;
}
bar {
  background: rgba(32,33,36,0.7);
  border-radius: 4px;
  padding: 4px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.2);
}
taskbar button {
  padding: 8px;
  margin: 0 4px;
  transition: transform 0.2s ease;
}
taskbar button image {
  border-radius: 50%;
  background: #FFFFFF;
}
taskbar button:hover {
  background: #8AB4F8;
  border-radius: 4px;
  transform: scale(1.2);
}
taskbar button:hover image {
  background: #E8EAED;
}
taskbar button:active {
  animation: bounce 0.3s;
}
@keyframes bounce {
  0% { transform: scale(1); }
  50% { transform: scale(1.5); }
  100% { transform: scale(1); }
}
tray { padding: 8px; }
tray image { -gtk-icon-transform: scale(1); }
battery, network, volume, bluetooth, clock {
  padding: 8px;
  font: Roboto 10;
}
popup {
  background: rgba(48,49,52,0.9);
  backdrop-filter: blur(4px);
  border-radius: 8px;
  padding: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.2);
  transition: all 0.2s ease;
}
popup button {
  background: #3C4043;
  color: #FFFFFF;
  border-radius: 16px;
  padding: 8px;
  margin: 4px;
}
popup button:hover {
  background: #8AB4F8;
  box-shadow: 0 1px 2px rgba(0,0,0,0.1);
}
popup scale trough {
  background: #3C4043;
  border-radius: 16px;
}
popup scale highlight {
  background: #8AB4F8;
  border-radius: 16px;
}
popup scale slider {
  background: #FFFFFF;
  border-radius: 16px;
  box-shadow: 0 1px 2px rgba(0,0,0,0.1);
}
EOL

# Configure sfwbar control scripts
cat > /usr/local/bin/wifi-popup.sh << EOL
#!/bin/sh
networks=$(iwctl station wlan0 scan && iwctl station wlan0 get-networks | grep -v "open" | awk 'NR>4 {print $1}')
echo "popup {"
echo "  label { text = 'Wi-Fi Networks'; font = 'Roboto 12'; atop: center; color = '#FFFFFF'; }"
for net in $networks; do
  echo "  button { text = '$net'; exec = 'iwctl station wlan0 connect \"$net\"'; }"
done
echo "}"
EOL

cat > /usr/local/bin/wifi-toggle.sh << EOL
#!/bin/sh
iwctl station wlan0 show | grep -q "connected" && iwctl station wlan0 disconnect || iwctl station wlan0 scan
EOL

cat > /usr/local/bin/volume-popup.sh << EOL
#!/bin/sh
volume=$(amixer get Master | grep -o "[0-9]*%" | head -1 | tr -d '%')
echo "popup {"
echo "  label { text = 'Volume'; font = 'Roboto 12'; color = '#FFFFFF'; }"
echo "  scale { min = 0; max = 100; value = $volume; exec = 'amixer set Master %d%%'; }"
echo "}"
EOL

cat > /usr/local/bin/volume-toggle.sh << EOL
#!/bin/sh
amixer get Master | grep -q "[on]" && amixer set Master mute || amixer set Master unmute
EOL

cat > /usr/local/bin/bluetooth-popup.sh << EOL
#!/bin/sh
devices=$(bluetoothctl devices | awk '{print $2, $3}')
echo "popup {"
echo "  label { text = 'Bluetooth Devices'; font = 'Roboto 12'; color = '#FFFFFF'; }"
[ -n "$devices" ] && while read -r mac name; do
  echo "  button { text = '$name'; exec = 'bluetoothctl connect $mac'; }"
done <<< "$devices" || echo "  label { text = 'No devices found'; font = 'Roboto 10'; color = '#FFFFFF'; }"
echo "}"
EOL

cat > /usr/local/bin/bluetooth-toggle.sh << EOL
#!/bin/sh
bluetoothctl show | grep -q "Powered: yes" && bluetoothctl power off || bluetoothctl power on
EOL

# Configure theme toggle
cat > /usr/local/bin/toggle-theme.sh << EOL
#!/bin/sh
CONFIG="$HOME/.config/gtk-3.0/settings.ini"
SFWBAR_CSS="$HOME/.config/sfwbar/sfwbar.css"
WOFI_CSS="$HOME/.config/wofi/style.css"
MAKO_CONFIG="$HOME/.config/mako/config"
FOOT_CONFIG="$HOME/.config/foot/foot.ini"
ENV_FILE="$HOME/.config/labwc/environment"
GTG_CSS="/etc/greetd/gtkgreet.css"
DYNAMIC_COLOR=$(/usr/local/bin/wallpaper-color.sh)
if grep -q "gtk-theme-name=Orchis-Dark" "$CONFIG"; then
  sed -i -e 's/gtk-theme-name=Orchis-Dark/gtk-theme-name=Orchis-Light/' \
         -e 's/gtk-icon-theme-name=Papirus-Dark/gtk-icon-theme-name=Papirus-Light/' \
         -e 's/gtk-cursor-theme-name=Vimix-White/gtk-cursor-theme-name=Vimix-Black/' \
         -e 's/gtk-application-prefer-dark-theme=true/gtk-application-prefer-dark-theme=false/' "$CONFIG"
  sed -i -e 's/background: rgba(32,33,36,0.7);/background: rgba(241,243,244,0.7);/' \
         -e 's/background: rgba(48,49,52,0.9);/background: rgba(255,255,255,0.9);/' \
         -e 's/color: #FFFFFF;/color: #202124;/' \
         -e 's/taskbar button image { background: #FFFFFF; }/taskbar button image { background: #202124; }/' \
         -e 's/taskbar button:hover { background: #8AB4F8;/taskbar button:hover { background: "'$DYNAMIC_COLOR'";/' \
         -e 's/popup button:hover { background: #8AB4F8;/popup button:hover { background: "'$DYNAMIC_COLOR'";/' \
         -e 's/popup scale highlight { background: #8AB4F8;/popup scale highlight { background: "'$DYNAMIC_COLOR'";/' "$SFWBAR_CSS"
  sed -i -e 's/background: rgba(48,49,52,0.9);/background: rgba(255,255,255,0.9);/' \
         -e 's/color: #FFFFFF;/color: #202124;/' \
         -e 's/background: #3C4043;/background: #E8EAED;/' \
         -e 's/background: #202124;/background: #FFFFFF;/' \
         -e 's/#entry:selected { background: #8AB4F8;/#entry:selected { background: "'$DYNAMIC_COLOR'";/' "$WOFI_CSS"
  sed -i -e 's/background-color=#303134/background-color=#FFFFFF/' \
         -e 's/text-color=#FFFFFF/text-color=#202124/' \
         -e 's/border-color=#3C4043/border-color=#E8EAED/' \
         -e 's/action-color=#8AB4F8/action-color="'$DYNAMIC_COLOR'"/' "$MAKO_CONFIG"
  sed -i -e 's/background=303134/background=F1F3F4/' \
         -e 's/foreground=FFFFFF/foreground=202124/' "$FOOT_CONFIG"
  sed -i 's/XCURSOR_THEME=Vimix-White/XCURSOR_THEME=Vimix-Black/' "$ENV_FILE"
  sed -i 's/#button:hover { background: #8AB4F8;/#button:hover { background: "'$DYNAMIC_COLOR'";/' "$GTG_CSS"
else
  sed -i -e 's/gtk-theme-name=Orchis-Light/gtk-theme-name=Orchis-Dark/' \
         -e 's/gtk-icon-theme-name=Papirus-Light/gtk-icon-theme-name=Papirus-Dark/' \
         -e 's/gtk-cursor-theme-name=Vimix-Black/gtk-cursor-theme-name=Vimix-White/' \
         -e 's/gtk-application-prefer-dark-theme=false/gtk-application-prefer-dark-theme=true/' "$CONFIG"
  sed -i -e 's/background: rgba(241,243,244,0.7);/background: rgba(32,33,36,0.7);/' \
         -e 's/background: rgba(255,255,255,0.9);/background: rgba(48,49,52,0.9);/' \
         -e 's/color: #202124;/color: #FFFFFF;/' \
         -e 's/taskbar button image { background: #202124; }/taskbar button image { background: #FFFFFF; }/' \
         -e 's/taskbar button:hover { background: #[0-9A-F]\{6\};/taskbar button:hover { background: "'$DYNAMIC_COLOR'";/' \
         -e 's/popup button:hover { background: #[0-9A-F]\{6\};/popup button:hover { background: "'$DYNAMIC_COLOR'";/' \
         -e 's/popup scale highlight { background: #[0-9A-F]\{6\};/popup scale highlight { background: "'$DYNAMIC_COLOR'";/' "$SFWBAR_CSS"
  sed -i -e 's/background: rgba(255,255,255,0.9);/background: rgba(48,49,52,0.9);/' \
         -e 's/color: #202124;/color: #FFFFFF;/' \
         -e 's/background: #E8EAED;/background: #3C4043;/' \
         -e 's/background: #FFFFFF;/background: #202124;/' \
         -e 's/#entry:selected { background: #[0-9A-F]\{6\};/#entry:selected { background: "'$DYNAMIC_COLOR'";/' "$WOFI_CSS"
  sed -i -e 's/background-color=#FFFFFF/background-color=#303134/' \
         -e 's/text-color=#202124/text-color=#FFFFFF/' \
         -e 's/border-color=#E8EAED/border-color=#3C4043/' \
         -e 's/action-color=#[0-9A-F]\{6\}/action-color="'$DYNAMIC_COLOR'"/' "$MAKO_CONFIG"
  sed -i -e 's/background=F1F3F4/background=303134/' \
         -e 's/foreground=202124/foreground=FFFFFF/' "$FOOT_CONFIG"
  sed -i 's/XCURSOR_THEME=Vimix-Black/XCURSOR_THEME=Vimix-White/' "$ENV_FILE"
  sed -i 's/#button:hover { background: #[0-9A-F]\{6\};/#button:hover { background: "'$DYNAMIC_COLOR'";/' "$GTG_CSS"
fi
pkill -u "$USER" -USR1 sfwbar mako labwc
EOL

# Configure wofi
cat > "$USER_HOME/.config/wofi/config" << EOL
width=400
height=600
columns=4
icon_size=48
show=drun
matching=fuzzy
sort_order=alphabetical
EOL
cat > "$USER_HOME/.config/wofi/style.css" << EOL
* {
  font-family: Roboto;
  font-size: 12pt;
  color: #FFFFFF;
}
window {
  background: rgba(48,49,52,0.9);
  backdrop-filter: blur(4px);
  border-radius: 8px;
  padding: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.2);
  opacity: 0;
  transition: opacity 0.2s ease;
}
window:ready {
  opacity: 1;
}
#outer-box { padding: 8px; }
#input {
  background: #3C4043;
  color: #FFFFFF;
  border-radius: 4px;
  padding: 8px;
  margin-bottom: 8px;
}
#entry {
  background: #202124;
  border-radius: 4px;
  padding: 8px;
  margin: 4px;
  box-shadow: 0 1px 2px rgba(0,0,0,0.1);
}
#entry image {
  border-radius: 50%;
  background: #FFFFFF;
}
#entry:selected {
  background: #8AB4F8;
  border-radius: 4px;
}
#entry:selected image {
  background: #E8EAED;
}
EOL

# Configure foot
cat > "$USER_HOME/.config/foot/foot.ini" << EOL
[colors]
background=303134
foreground=FFFFFF
EOL

# Configure mako
cat > "$USER_HOME/.config/mako/config" << EOL
background-color=#303134
text-color=#FFFFFF
border-color=#3C4043
border-radius=8
font=Roboto 12
padding=8
margin=8
height=50
width=200
anchor=top-center
default-timeout=5000
action-color=#8AB4F8
box-shadow=0 2px 4px rgba(0,0,0,0.2)
EOL

# Configure clipman
cat > "$USER_HOME/.config/clipman/config" << EOL
[clipman]
history_size = 50
persistent = true
EOL

# Configure labwc autostart
cat > "$USER_HOME/.config/labwc/autostart" << EOL
$AUTOSTART
wbg /usr/share/backgrounds/orchis-wallpaper.jpg &
sfwbar &
mako &
clipman &
xdg-desktop-portal-wlr &
blueman-applet &
pipewire &
wireplumber &
EOL

# Configure badwolf
cat > "$USER_HOME/.config/badwolf/config" << EOL
javascript_enabled = false
EOL

# Function to get total memory in MB
get_total_mem() {
    free -m | awk '/^Mem:/{print $2}'
}

# Function to get current memory usage percentage
get_mem_usage_percent() {
    free -m | awk '/^Mem:/{print int($3/$2*100)}'
}

# Function to get CPU count
get_cpu_count() {
    nproc
}

# Function to get battery level (if applicable)
get_battery_level() {
    local level=100
    for bat in /sys/class/power_supply/BAT*/capacity; do
        [ -f "$bat" ] && level=$(cat "$bat") && break
    done
    echo "$level"
}

# Function to check if system is on battery
is_on_battery() {
    for ac in /sys/class/power_supply/AC*/online /sys/class/power_supply/ADP*/online; do
        [ -f "$ac" ] && [ "$(cat "$ac")" = "0" ] && return 0
    done
    return 1
}

# Function to optimize memory with zram and zswap
optimize_memory() {
    echo "Optimizing memory with zram and zswap..."
    local total_mem=$(get_total_mem)
    local mem_usage=$(get_mem_usage_percent)
    local cpu_count=$(get_cpu_count)
    if modprobe -q zram 2>/dev/null; then
        echo "Setting up zram..."
        local zram_percent=50
        [ "$mem_usage" -gt 80 ] && zram_percent=75
        [ "$mem_usage" -lt 30 ] && zram_percent=25
        local zram_size=$((total_mem * zram_percent / 100))
        echo "${zram_size}M" > /sys/block/zram0/disksize
        mkswap /dev/zram0
        swapon /dev/zram0 -p 32767
        if [ -f /sys/block/zram0/comp_algorithm ]; then
            if [ "$cpu_count" -ge 4 ]; then
                echo zstd > /sys/block/zram0/comp_algorithm 2>/dev/null || echo lz4 > /sys/block/zram0/comp_algorithm
            else
                echo lz4 > /sys/block/zram0/comp_algorithm 2>/dev/null || echo lzo > /sys/block/zram0/comp_algorithm
            fi
        fi
        local swappiness=100
        [ "$mem_usage" -gt 80 ] && swappiness=150
        [ "$mem_usage" -lt 30 ] && swappiness=80
        echo "$swappiness" > /proc/sys/vm/swappiness
    else
        echo "zram not supported by kernel."
    fi
    if [ -d /sys/module/zswap ]; then
        echo "Setting up zswap..."
        echo 1 > /sys/module/zswap/parameters/enabled
        if [ "$cpu_count" -ge 4 ]; then
            echo zstd > /sys/module/zswap/parameters/compressor 2>/dev/null || echo lz4 > /sys/module/zswap/parameters/compressor
        else
            echo lz4 > /sys/module/zswap/parameters/compressor 2>/dev/null || echo lzo > /sys/module/zswap/parameters/compressor
        fi
        echo zbud > /sys/module/zswap/parameters/zpool
        local pool_percent=20
        [ "$mem_usage" -gt 80 ] && pool_percent=30
        [ "$mem_usage" -lt 30 ] && pool_percent=10
        echo "$pool_percent" > /sys/module/zswap/parameters/max_pool_percent
    else
        echo "zswap not supported by kernel."
    fi
    local cache_pressure=10
    [ "$mem_usage" -gt 80 ] && cache_pressure=5
    echo "$cache_pressure" > /proc/sys/vm/vfs_cache_pressure
    echo 500 > /proc/sys/vm/dirty_expire_centisecs
}

# Function to optimize power
optimize_power() {
    echo "Optimizing power settings..."
    local battery_level=$(get_battery_level)
    local on_battery=$(is_on_battery && echo 1 || echo 0)
    # GPU power saving
    for gpu in /sys/class/drm/card*/device/power_dpm_force_performance_level; do
        [ -f "$gpu" ] || continue
        if [ "$on_battery" = "1" ]; then
            echo low > "$gpu"
        else
            echo auto > "$gpu"
        fi
    done
    [ -f /sys/module/nvidia/parameters/modeset ] && echo 0 > /sys/module/nvidia/parameters/modeset
    # Backlight adjustment
    for b in /sys/class/backlight/*/brightness; do
        [ -w "$b" ] || continue
        local max=$(cat "${b%brightness}max_brightness")
        local target_brightness
        if [ "$on_battery" = "1" ]; then
            if [ "$battery_level" -lt 20 ]; then
                target_brightness=$((max * 10 / 100))
            elif [ "$battery_level" -lt 50 ]; then
                target_brightness=$((max * 20 / 100))
            else
                target_brightness=$((max * 30 / 100))
            fi
        else
            target_brightness=$((max * 70 / 100))
        fi
        echo "$target_brightness" > "$b"
    done
}

# Function to optimize disk
optimize_disk() {
    echo "Optimizing disk settings..."
    local io_load=0
    [ -x /usr/bin/iostat ] && io_load=$(iostat -d 1 2 | awk '/^sd|^nvme/{sum+=$3} END{print int(sum)}')
    for disk in /dev/sd[a-z] /dev/nvme[0-9]n[0-9]; do
        [ -b "$disk" ] || continue
        local disk_name=$(basename "$disk")
        local rotational=0
        [ -f "/sys/block/$disk_name/queue/rotational" ] && rotational=$(cat "/sys/block/$disk_name/queue/rotational")
        if [ "${disk:0:8}" = "/dev/nvme" ]; then
            if [ "$io_load" -gt 50 ]; then
                echo mq-deadline > "/sys/block/$disk_name/queue/scheduler" 2>/dev/null
            else
                echo kyber > "/sys/block/$disk_name/queue/scheduler" 2>/dev/null || echo mq-deadline > "/sys/block/$disk_name/queue/scheduler"
            fi
        elif [ "$rotational" = "1" ]; then
            if [ "$io_load" -gt 50 ]; then
                echo cfq > "/sys/block/$disk_name/queue/scheduler" 2>/dev/null || echo bfq > "/sys/block/$disk_name/queue/scheduler"
            else
                echo bfq > "/sys/block/$disk_name/queue/scheduler" 2>/dev/null
            fi
            hdparm -B 128 -S 24 "$disk" 2>/dev/null
            echo 1500 > /proc/sys/vm/dirty_writeback_centisecs 2>/dev/null
        else
            if [ "$io_load" -gt 50 ]; then
                echo mq-deadline > "/sys/block/$disk_name/queue/scheduler" 2>/dev/null
            else
                echo kyber > "/sys/block/$disk_name/queue/scheduler" 2>/dev/null || echo mq-deadline > "/sys/block/$disk_name/queue/scheduler"
            fi
        fi
    done
    local disk_usage=$(df / | awk 'NR==2{print $5}' | tr -d '%')
    [ "$disk_usage" -gt 80 ] && fstrim -v / 2>/dev/null
}

# Main optimization function
main() {
    echo "Starting Setus optimization..."
    optimize_memory
    optimize_power
    optimize_disk
    echo "Optimization complete."
}

# Configure power optimization script
cat > /etc/local.d/power-optimize.start << EOL
#!/bin/sh
$(typeset -f optimize_power)
optimize_power
EOL

# Configure disk optimization script
cat > /etc/local.d/disk-optimize.start << EOL
#!/bin/sh
$(typeset -f optimize_disk)
optimize_disk
EOL

# Configure udev rules
cat > /etc/udev/rules.d/90-power-optimize.rules << EOL
ACTION=="add", SUBSYSTEM=="net", KERNEL=="e*", RUN+="/bin/sh -c '[ -w /sys%p/device/power/control ] && echo auto > /sys%p/device/power/control'"
ACTION=="add|change", KERNEL=="sd[a-z]|nvme[0-9]n[0-9]", RUN+="/etc/local.d/disk-optimize.start"
ACTION=="add|change", KERNEL=="sd[a-z]|nvme[0-9]n[0-9]", ATTR{queue/rotational}=="0", RUN+="/usr/sbin/fstrim -v /"
ACTION=="add", SUBSYSTEM=="drm", RUN+="/bin/sh -c '[ -f /sys/%p/device/power_dpm_force_performance_level ] && echo low > /sys/%p/device/power_dpm_force_performance_level'"
EOL

# Configure suspend/resume
cat > /usr/lib/elogind/system-sleep/00-alpine-power << EOL
#!/bin/sh
case "$1" in
  post)
    /etc/local.d/power-optimize.start
    /etc/local.d/disk-optimize.start
    ;;
esac
exit 0
EOL

# Configure TRIM cron job
echo "0 0 * * 0 /etc/local.d/disk-optimize.start" >> /etc/crontabs/root

# Trap to reset zram on exit
trap 'swapoff /dev/zram0 2>/dev/null; modprobe -r zram 2>/dev/null' EXIT

# Run main
main

# Cleanup
echo "Cleaning up..."
BUILDTIME_DEPS="rust cargo git musl-dev pkgconf lua-dev make sdl2-dev g++ gtk4.0-dev libpanel-dev libadwaita-dev gtksourceview5-dev poppler-dev eudev-dev"
apk del $BUILDTIME_DEPS || echo "Warning: Failed to remove build dependencies" >&2
rm -rf /tmp/*
chmod +x /usr/local/bin/*
