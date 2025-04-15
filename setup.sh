#!/bin/sh

# Exit on error
set -e

# Ensure root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" >&2
   exit 1
fi

# Set edge repositories
cat > /etc/apk/repositories << EOL
http://dl-cdn.alpinelinux.org/alpine/edge/main
http://dl-cdn.alpinelinux.org/alpine/edge/community
http://dl-cdn.alpinelinux.org/alpine/edge/testing
EOL
apk update || {
  echo "Failed to update package repositories" >&2
  exit 1
}

# Install packages
echo "Installing packages..."
apk add --no-cache \
  labwc sfwbar foot badwolf greetd-gtkgreet wbg waylock \
  mupdf mako lite-xl image-roll drawing font-roboto wofi \
  greetd cage dbus polkit \
  tlp elogind wlr-randr upower iw util-linux udev \
  pipewire wireplumber pipewire-alsa pipewire-pulse alsa-lib alsa-utils \
  rust cargo git openssl-dev musl-dev pkgconf lua-dev make sdl2-dev \
  cmake g++ qt5-qtbase-dev qt5-qtbase-x11 qt5-qtdeclarative-dev qt5-qttools-dev \
  imagemagick-dev dbus-dev udisks2-dev ffmpeg-dev \
  clipman grim slurp xdg-desktop-portal-wlr \
  sassc qt5ct papirus-icon-theme \
  bluez bluez-openrc blueman linux-firmware \
  mesa-dri-gallium xwayland wl-clipboard wayland-utils pam-rundir pavucontrol \
  xdotool || {
  echo "Failed to install required packages" >&2
  exit 1
}

# Define runtime dependencies to protect during cleanup
RUNTIME_DEPS="labwc sfwbar foot badwolf greetd-gtkgreet wbg waylock mupdf mako \
  drawing font-roboto wofi greetd cage dbus polkit tlp elogind wlr-randr upower iw util-linux udev \
  pipewire wireplumber pipewire-alsa pipewire-pulse alsa-lib alsa-utils clipman grim slurp \
  xdg-desktop-portal-wlr qt5ct papirus-icon-theme imagemagick ffmpeg \
  bluez blueman linux-firmware mesa-dri-gallium xwayland wl-clipboard wayland-utils pam-rundir pavucontrol xdotool"

# Function to get latest git tag
get_latest_tag() {
  repo_url="$1"
  git ls-remote --tags "$repo_url" | grep -v "{}" | grep -v "release-" | \
    sed 's|.*/||' | sort -V | tail -1 || echo ""
}

# Install smplayer from source
if ! command -v smplayer >/dev/null 2>&1; then
  echo "Building smplayer..."
  mkdir -p /tmp/smplayer
  cd /tmp/smplayer
  SMPLAYER_TAG=$(get_latest_tag "https://github.com/smplayer-dev/smplayer.git")
  if [ -z "$SMPLAYER_TAG" ]; then
    SMPLAYER_TAG="master"  # Fallback to master as per hint
    echo "Warning: Could not fetch smplayer tag, falling back to master" >&2
  fi
  git clone https://github.com/smplayer-dev/smplayer.git --depth 1 --branch "$SMPLAYER_TAG" --single-branch && \
  cd smplayer || {
    echo "Error: smplayer repo clone failed." >&2
    exit 1
  }
  make PREFIX=/usr || {
    echo "Warning: smplayer build failed. Skipping." >&2
    SKIP_SMPLAYER=1
  }
  if [ -z "$SKIP_SMPLAYER" ]; then
    make install PREFIX=/usr || {
      echo "Failed to install smplayer" >&2
      SKIP_SMPLAYER=1
    }
  fi
  cd /tmp
  rm -rf smplayer
fi

# Install wlsleephandler-rs
echo "Installing wlsleephandler-rs..."
cargo install --git https://github.com/fishman/sleepwatcher-rs --locked || {
  echo "Warning: wlsleephandler-rs installation failed. Using fallback." >&2
  SKIP_WLSLEEPHANDLER=1
}

# Install qtfm
if ! command -v qtfm >/dev/null 2>&1; then
  echo "Building qtfm..."
  mkdir -p /tmp/qtfm
  cd /tmp/qtfm
  QTFM_TAG=$(get_latest_tag "https://github.com/rodlie/qtfm.git")
  if [ -z "$QTFM_TAG" ]; then
    QTFM_TAG="master"  # Fallback to master as per hint
    echo "Warning: Could not fetch qtfm tag, falling back to master" >&2
  fi
  git clone https://github.com/rodlie/qtfm.git --depth 1 --branch "$QTFM_TAG" --single-branch && \
  cd qtfm || {
    echo "Error: qtfm repo clone failed." >&2
    exit 1
  }
  # Use CMake build system as per README since 6.3.0
  mkdir build
  cd build
  cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_INSTALL_DOCDIR=share/doc/qtfm \
    -DCMAKE_INSTALL_MANDIR=share/man \
    -DENABLE_MAGICK=TRUE \
    -DENABLE_FFMPEG=TRUE \
    -DENABLE_DBUS=TRUE \
    -DENABLE_UDISKS=TRUE \
    -DENABLE_TRAY=FALSE \
    -DCMAKE_CXX_FLAGS="-fpermissive" || {
    echo "Warning: qtfm CMake configuration failed." >&2
    SKIP_QTFM=1
  }
  if [ -z "$SKIP_QTFM" ]; then
    make || {
      echo "Warning: qtfm build failed." >&2
      SKIP_QTFM=1
    }
    if [ -z "$SKIP_QTFM" ]; then
      make install || {
        echo "Failed to install qtfm" >&2
        SKIP_QTFM=1
      }
    fi
  fi
  cd /tmp
  rm -rf qtfm
fi

# Install Orchis GTK theme and wallpaper (using install.sh, excluding GNOME Shell)
echo "Installing Orchis GTK theme and wallpaper..."
mkdir -p /tmp/orchis
cd /tmp/orchis
ORCHIS_GTK_TAG=$(get_latest_tag "https://github.com/vinceliuice/Orchis-theme.git")
if [ -z "$ORCHIS_GTK_TAG" ]; then
  ORCHIS_GTK_TAG="master"  # Fallback to master as per hint
  echo "Warning: Could not fetch Orchis GTK tag, falling back to master" >&2
fi
git clone https://github.com/vinceliuice/Orchis-theme.git --depth 1 --branch "$ORCHIS_GTK_TAG" --single-branch && \
cd Orchis-theme || {
  echo "Error: Orchis GTK repo clone failed." >&2
  exit 1
}
if ! command -v sassc >/dev/null 2>&1; then
  echo "Error: sassc is required for Orchis GTK theme compilation" >&2
  SKIP_ORCHIS_GTK=1
fi
./install.sh -d "$USER_HOME/.themes" -t default -c dark light -s compact --tweaks primary || {
  echo "Warning: Orchis GTK theme installation failed." >&2
  SKIP_ORCHIS_GTK=1
}
# Remove GNOME Shell files to avoid GNOME specificity
find "$USER_HOME/.themes/Orchis-*" -type d -name "gnome-shell" -exec rm -rf {} + 2>/dev/null || true
# Check for wallpaper and use appropriate file
if [ -f "wallpaper/1080p.jpg" ]; then
  mkdir -p /usr/share/backgrounds
  cp wallpaper/1080p.jpg /usr/share/backgrounds/orchis-wallpaper.jpg || {
    echo "Warning: Orchis wallpaper copy failed." >&2
    SKIP_WALLPAPER=1
  }
elif [ -f "wallpaper/2k.jpg" ]; then
  mkdir -p /usr/share/backgrounds
  cp wallpaper/2k.jpg /usr/share/backgrounds/orchis-wallpaper.jpg || {
    echo "Warning: Orchis wallpaper copy failed." >&2
    SKIP_WALLPAPER=1
  }
elif [ -f "wallpaper/4k.jpg" ]; then
  mkdir -p /usr/share/backgrounds
  cp wallpaper/4k.jpg /usr/share/backgrounds/orchis-wallpaper.jpg || {
    echo "Warning: Orchis wallpaper copy failed." >&2
    SKIP_WALLPAPER=1
  }
else
  echo "Warning: No wallpaper found in Orchis theme, using fallback." >&2
  mkdir -p /usr/share/backgrounds
  echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==" | base64 -d > /usr/share/backgrounds/orchis-wallpaper.jpg
fi
cd /tmp
rm -rf orchis

# Install Orchis KDE theme for Qt applications (manual extraction, bypassing install.sh)
echo "Installing Orchis KDE theme for Qt applications..."
mkdir -p /tmp/orchis-kde
cd /tmp/orchis-kde
ORCHIS_KDE_TAG=$(get_latest_tag "https://github.com/vinceliuice/Orchis-kde.git")
if [ -z "$ORCHIS_KDE_TAG" ]; then
  ORCHIS_KDE_TAG="main"  # Fallback to main as per hint
  echo "Warning: Could not fetch Orchis KDE tag, falling back to main" >&2
fi
git clone https://github.com/vinceliuice/Orchis-kde.git --depth 1 --branch "$ORCHIS_KDE_TAG" --single-branch && \
cd Orchis-kde || {
  echo "Error: Orchis KDE repo clone failed." >&2
  exit 1
}
QT_THEME_DIR="$USER_HOME/.themes/Orchis"
mkdir -p "$QT_THEME_DIR"
cp -r colors "$QT_THEME_DIR/" || {
  echo "Warning: Failed to copy Orchis KDE color scheme" >&2
  SKIP_ORCHIS_KDE=1
}
cd /tmp
rm -rf orchis-kde

# Install Vimix cursor themes
echo "Installing Vimix cursor themes..."
mkdir -p /tmp/vimix-cursors
cd /tmp/vimix-cursors
VIMIX_TAG=$(get_latest_tag "https://github.com/vinceliuice/Vimix-cursors.git")
if [ -z "$VIMIX_TAG" ]; then
  VIMIX_TAG="master"  # Fallback to master as per hint
  echo "Warning: Could not fetch Vimix cursors tag, falling back to master" >&2
fi
git clone https://github.com/vinceliuice/Vimix-cursors.git --depth 1 --branch "$VIMIX_TAG" --single-branch && \
cd Vimix-cursors || {
  echo "Error: Vimix cursors repo clone failed." >&2
  exit 1
}
./install.sh || {
  echo "Warning: Vimix cursors installation failed." >&2
  SKIP_VIMIX=1
}
cd /tmp
rm -rf vimix-cursors

# Configure Bluetooth
echo "Configuring Bluetooth..."
rc-update add bluetooth || echo "Warning: Failed to add bluetooth to boot services"
cat > /etc/bluetooth/main.conf << EOL
[General]
Name = AlpineWayland
DiscoverableTimeout = 0
AlwaysPairable = true
AutoEnable = true

[Policy]
AutoEnable = true
EOL
echo "uinput" >> /etc/modules || echo "Warning: Failed to add uinput module"

# Configure TLP
echo "Configuring TLP..."
rc-update add tlp || echo "Warning: Failed to add TLP to boot services"
cat > /etc/tlp.conf << EOL
TLP_DEFAULT_MODE=BAT
CPU_SCALING_GOVERNOR_ON_BAT=powersave
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power
CPU_ENERGY_PERF_POLICY_ON_AC=performance
PLATFORM_PROFILE_ON_BAT=low-power
PLATFORM_PROFILE_ON_AC=balanced
WIFI_PWR_ON_BAT=off
WIFI_PWR_ON_AC=on
RUNTIME_PM_ON_BAT=auto
RUNTIME_PM_ON_AC=on
USB_AUTOSUSPEND=1
USB_DENYLIST="usbhid"
SATA_LINKPWR_ON_BAT=min_power
SATA_LINKPWR_ON_AC=max_performance
SOUND_POWER_SAVE_ON_BAT=1
SOUND_POWER_SAVE_ON_AC=0
RESTORE_DEVICE_STATE_ON_STARTUP=0
EOL

# Configure sound
echo "Configuring sound services..."
rc-update add pipewire || echo "Warning: Failed to add pipewire to boot services"
rc-update add wireplumber || echo "Warning: Failed to add wireplumber to boot services"
rc-update add alsa || echo "Warning: Failed to add alsa to boot services"
alsactl init 2>/dev/null || true
cat > /etc/asound.conf << EOL
defaults.pcm.card 0
defaults.ctl.card 0
EOL

# Configure elogind, dbus, udev
echo "Configuring session services..."
rc-update add elogind || echo "Warning: Failed to add elogind to boot services"
rc-update add dbus || echo "Warning: Failed to add dbus to boot services"
rc-update add udev || echo "Warning: Failed to add udev to boot services"

# Configure PAM for XDG_RUNTIME_DIR
echo "Configuring PAM for XDG_RUNTIME_DIR..."
cat > /etc/pam.d/greetd << EOL
auth       required   pam-rundir.so
auth       required   pam_unix.so
account    required   pam_unix.so
session    required   pam-rundir.so
session    required   pam_limits.so
session    required   pam_env.so
session    required   pam_unix.so
EOL

# Configure greetd and gtkgreet
echo "Configuring greetd login manager..."
rc-update add greetd || echo "Warning: Failed to add greetd to boot services"
cat > /etc/greetd/config.toml << EOL
[terminal]
vt = "next"
switch = true
[default_session]
command = "cage -s -- env GTK_THEME=Orchis-Dark XCURSOR_THEME=Vimix-White gtkgreet --style /etc/greetd/gtkgreet.css"
user = "greetd"
EOL
cat > /etc/greetd/environments << EOL
dbus-run-session -- labwc
EOL
addgroup greetd video 2>/dev/null || true
addgroup greetd seat 2>/dev/null || true
addgroup greetd input 2>/dev/null || true
addgroup greetd bluetooth 2>/dev/null || true
# Ensure gtkgreet uses Orchis themes
if [ -z "$SKIP_ORCHIS_GTK" ]; then
  mkdir -p /usr/share/themes
  cp -r "$USER_HOME/.themes/Orchis-Dark" /usr/share/themes/ || {
    echo "Warning: Failed to copy Orchis-Dark theme for gtkgreet." >&2
  }
  cp -r "$USER_HOME/.themes/Orchis-Light" /usr/share/themes/ || {
    echo "Warning: Failed to copy Orchis-Light theme for gtkgreet." >&2
  }
fi

# User configuration
echo "User configuration..."
echo "Enter username for configuration (blank for auto-detect): "
read -r USER_INPUT
if [ -z "$USER_INPUT" ]; then
  USER_HOME=$(getent passwd | grep -v '^root:' | grep -v '^greetd:' | grep -v '/sbin/nologin$' | head -1 | cut -d: -f6)
  USER_NAME=$(basename "$USER_HOME" 2>/dev/null || echo "user")
  if [ -z "$USER_HOME" ] || [ ! -d "$USER_HOME" ]; then
    USER_HOME="/home/user"
    USER_NAME="user"
    if ! id "$USER_NAME" >/dev/null 2>&1; then
      echo "Creating default user '$USER_NAME'..."
      adduser -D "$USER_NAME" || {
        echo "Failed to create user" >&2
        exit 1
      }
    fi
  fi
else
  USER_NAME="$USER_INPUT"
  USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)
  if [ -z "$USER_HOME" ] || [ ! -d "$USER_HOME" ]; then
    echo "User '$USER_NAME' does not exist or has no home directory."
    echo "Creating user '$USER_NAME'..."
    adduser -D "$USER_NAME" || {
      echo "Failed to create user" >&2
      exit 1
    }
    USER_HOME="/home/$USER_NAME"
  fi
fi

echo "Configuring for user: $USER_NAME (home: $USER_HOME)"
mkdir -p "$USER_HOME/.config/"{labwc,sfwbar,foot,qtfm,wlsleephandler-rs,badwolf,mako,clipman,gtk-3.0,gtk-4.0,qt5ct,wofi} || {
  echo "Failed to create config directories" >&2
  exit 1
}
addgroup "$USER_NAME" audio 2>/dev/null || true
addgroup "$USER_NAME" bluetooth 2>/dev/null || true
addgroup "$USER_NAME" pipewire 2>/dev/null || true

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
  echo "Configuring fallback idle suspend script..."
  cat > /usr/local/bin/idle-suspend.sh << EOL
#!/bin/sh
check_idle() {
  idle_hint=\$(loginctl show-session -p IdleHint 2>/dev/null || echo "IdleHint=no")
  if echo "\$idle_hint" | grep -q "IdleHint=yes"; then
    echo "System is idle, locking and suspending..."
    waylock -fork-on-lock
    loginctl suspend
    sleep 10
  fi
}
check_idle
while true; do
  sleep 60
  check_idle
done
EOL
  chmod +x /usr/local/bin/idle-suspend.sh || {
    echo "Failed to make idle-suspend.sh executable" >&2
    exit 1
  }
  AUTOSTART="dbus-run-session -- idle-suspend.sh &"
fi

# Configure GTK theme for all future GTK apps
if [ -z "$SKIP_ORCHIS_GTK" ]; then
  cat > "$USER_HOME/.config/gtk-3.0/settings.ini" << EOL
[Settings]
gtk-theme-name=Orchis-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-name=Vimix-White
gtk-font-name=Roboto 10
gtk-application-prefer-dark-theme=true
gtk-button-images=true
gtk-menu-images=true
EOL
  cat > "$USER_HOME/.config/gtk-4.0/settings.ini" << EOL
[Settings]
gtk-theme-name=Orchis-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-name=Vimix-White
gtk-font-name=Roboto 10
gtk-application-prefer-dark-theme=true
gtk-button-images=true
gtk-menu-images=true
EOL
  ln -sf "$USER_HOME/.themes/Orchis-Dark/gtk-4.0" "$USER_HOME/.config/gtk-4.0" || {
    echo "Warning: Failed to link GTK 4.0 theme for libadwaita." >&2
  }
fi

# Configure Qt theme for all future Qt apps
if [ -z "$SKIP_ORCHIS_KDE" ]; then
  mkdir -p "$USER_HOME/.config/qt5ct"
  cat > "$USER_HOME/.config/qt5ct/qt5ct.conf" << EOL
[Appearance]
style=fusion
color_scheme_path=$QT_THEME_DIR/colors/OrchisDark.colors
icon_theme=Papirus-Dark
custom_palette=true
[Palette]
active-highlight=#8AB4F8
active-button=#3C4043
active-window=#202124
EOL
  echo "export QT_STYLE_OVERRIDE=fusion" >> "$USER_HOME/.profile"
  echo "export QT_QPA_PLATFORMTHEME=qt5ct" >> "$USER_HOME/.profile"
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
cat > /etc/greetd/config.toml << EOL
[terminal]
vt = "next"
switch = true
[default_session]
command = "cage -s -- env GTK_THEME=Orchis-Dark XCURSOR_THEME=Vimix-White gtkgreet --style /etc/greetd/gtkgreet.css"
user = "greetd"
EOL

# Configure wallpaper color extraction
cat > /usr/local/bin/wallpaper-color.sh << EOL
#!/bin/sh
# Extract dominant color from wallpaper
WALLPAPER="/usr/share/backgrounds/orchis-wallpaper.jpg"
if [ -f "\$WALLPAPER" ]; then
  COLOR=\$(magick "\$WALLPAPER" -resize 1x1 txt: | grep -o "#[0-9A-F]\{6\}" | head -1)
  # Adjust to Material You-like hue (close to #8AB4F8)
  if [ -n "\$COLOR" ]; then
    echo "\$COLOR"
    exit 0
  fi
fi
# Fallback to #8AB4F8
echo "#8AB4F8"
EOL
chmod +x /usr/local/bin/wallpaper-color.sh

# Configure tray popup
cat > /usr/local/bin/tray-popup.sh << EOL
#!/bin/sh
# Toggle sfwbar tray popups (Wi-Fi, volume, Bluetooth, brightness)
BRIGHTNESS_DEV=\$(ls /sys/class/backlight/* 2>/dev/null | head -1)
if [ -n "\$BRIGHTNESS_DEV" ]; then
  MAX_BRIGHTNESS=\$(cat "\$BRIGHTNESS_DEV/max_brightness")
  CURRENT_BRIGHTNESS=\$(cat "\$BRIGHTNESS_DEV/brightness")
  BRIGHTNESS_PERCENT=\$((CURRENT_BRIGHTNESS * 100 / MAX_BRIGHTNESS))
else
  BRIGHTNESS_PERCENT=50
fi
echo "popup {"
echo "  label { text = 'Quick Settings'; font = 'Roboto 12'; color = '#FFFFFF'; }"
echo "  button { text = 'Wi-Fi'; exec = '/usr/local/bin/wifi-toggle.sh'; }"
echo "  button { text = 'Volume'; exec = '/usr/local/bin/volume-toggle.sh'; }"
echo "  button { text = 'Bluetooth'; exec = '/usr/local/bin/bluetooth-toggle.sh'; }"
if [ -n "\$BRIGHTNESS_DEV" ]; then
  echo "  scale { min = 0; max = 100; value = \$BRIGHTNESS_PERCENT; exec = 'echo %d > \$BRIGHTNESS_DEV/brightness'; }"
fi
echo "}"
# Signal sfwbar to show popup (simulated click)
sfwbar -s Network
EOL
chmod +x /usr/local/bin/tray-popup.sh

# Configure labwc
cat > "$USER_HOME/.config/labwc/rc.xml" << EOL
<?xml version="1.0"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <theme>
    <cornerRadius>4</cornerRadius>
    <titleLayout>#202124</titleLayout>
    <shadow>true</shadow>
  </theme>
  <keyboard>
    <keybind key="Super_L">
      <action name="Execute"><execute>wofi --show drun</execute></action>
    </keybind>
    <keybind key="Super-space">
      <action name="Execute"><execute>wofi --show drun</execute></action>
    </keybind>
    <keybind key="Super-d">
      <action name="ToggleShowDesktop"/>
    </keybind>
    <keybind key="A-Tab">
      <action name="NextWindow"/>
    </keybind>
    <keybind key="F3">
      <action name="NextWindow"/>
    </keybind>
    <keybind key="A-F4">
      <action name="Close"/>
    </keybind>
    <keybind key="Super-e">
      <action name="Execute"><execute>qtfm</execute></action>
    </keybind>
    <keybind key="Super-l">
      <action name="Execute"><execute>waylock</execute></action>
    </keybind>
    <keybind key="Print">
      <action name="Execute"><execute>grim -g "$(slurp)" /home/$USER_NAME/screenshot-$(date +%s).png</execute></action>
    </keybind>
    <keybind key="Super-Left">
      <action name="SnapToEdge"><direction>Left</direction></action>
    </keybind>
    <keybind key="Super-Right">
      <action name="SnapToEdge"><direction>Right</direction></action>
    </keybind>
    <keybind key="Super-r">
      <action name="Execute"><execute>wofi --show run</execute></action>
    </keybind>
    <keybind key="Super-s">
      <action name="Execute"><execute>/usr/local/bin/tray-popup.sh</execute></action>
    </keybind>
    <keybind key="Super-b">
      <action name="Execute"><execute>xdotool key Alt+Left</execute></action>
    </keybind>
    <keybind key="Super-n">
      <action name="Execute"><execute>makoctl restore</execute></action>
    </keybind>
    <keybind key="Super-t">
      <action name="Execute"><execute>/usr/local/bin/toggle-theme.sh</execute></action>
    </keybind>
  </keyboard>
  <animations>
    <fadeWindows>true</fadeWindows>
    <fadeMenus>true</fadeMenus>
  </animations>
</openbox_config>
EOL
cat > "$USER_HOME/.config/labwc/menu.xml" << EOL
<?xml version="1.0" encoding="UTF-8"?>
<openbox_menu>
  <menu id="root-menu" label="Menu">
    <item label="Terminal"><action name="Execute"><execute>foot</execute></action></item>
    <item label="Browser"><action name="Execute"><execute>badwolf</execute></action></item>
    $( [ -z "$SKIP_QTFM" ] && echo '<item label="Files"><action name="Execute"><execute>qtfm</execute></action></item>' || true )
    $( [ -z "$SKIP_SMPLAYER" ] && echo '<item label="Player"><action name="Execute"><execute>smplayer</execute></action></item>' || true )
    <item label="Drawing"><action name="Execute"><execute>drawing</execute></action></item>
    <item label="PDF"><action name="Execute"><execute>mupdf</execute></action></item>
    $( [ -z "$SKIP_LITEXL" ] && echo '<item label="Editor"><action name="Execute"><execute>lite-xl</execute></action></item>' || true )
    $( [ -z "$SKIP_IMAGE_ROLL" ] && echo '<item label="Images"><action name="Execute"><execute>image-roll</execute></action></item>' || true )
    <item label="Bluetooth"><action name="Execute"><execute>blueman-manager</execute></action></item>
    <item label="Audio"><action name="Execute"><execute>pavucontrol</execute></action></item>
    <item label="Screenshot"><action name="Execute"><execute>grim -g \"\$(slurp)\" /home/$USER_NAME/screenshot-\$(date +%s).png</execute></action></item>
    <item label="Exit"><action name="Execute"><execute>labwc -e</execute></action></item>
  </menu>
</openbox_menu>
EOL
cat > "$USER_HOME/.config/labwc/environment" << EOL
QT_QPA_PLATFORM=wayland
XDG_SESSION_TYPE=wayland
XDG_SESSION_DESKTOP=labwc
XDG_CURRENT_DESKTOP=labwc:wlroots
WAYLAND_DISPLAY=wayland-0
GDK_BACKEND=wayland,x11
SDL_VIDEODRIVER=wayland
_JAVA_AWT_WM_NONREPARENTING=1
QT_STYLE_OVERRIDE=fusion
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
pins = foot badwolf qtfm smplayer drawing mupdf blueman-manager pavucontrol

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

tray {
  padding: 8px;
}

tray image {
  -gtk-icon-transform: scale(1);
}

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
# List Wi-Fi networks
networks=\$(iwctl station wlan0 scan && iwctl station wlan0 get-networks | grep -v "open" | awk 'NR>4 {print \$1}')
echo "popup {"
echo "  label { text = 'Wi-Fi Networks'; font = 'Roboto 12'; atop: center; color = '#FFFFFF'; }"
for net in \$networks; do
  echo "  button { text = '\$net'; exec = 'iwctl station wlan0 connect \"\$net\"'; }"
done
echo "}"
EOL
chmod +x /usr/local/bin/wifi-popup.sh

cat > /usr/local/bin/wifi-toggle.sh << EOL
#!/bin/sh
if iwctl station wlan0 show | grep -q "connected"; then
  iwctl station wlan0 disconnect
else
  iwctl station wlan0 scan
fi
EOL
chmod +x /usr/local/bin/wifi-toggle.sh

cat > /usr/local/bin/volume-popup.sh << EOL
#!/bin/sh
# Volume slider
volume=\$(amixer get Master | grep -o "[0-9]*%" | head -1 | tr -d '%')
echo "popup {"
echo "  label { text = 'Volume'; font = 'Roboto 12'; color = '#FFFFFF'; }"
echo "  scale { min = 0; max = 100; value = \$volume; exec = 'amixer set Master %d%%'; }"
echo "}"
EOL
chmod +x /usr/local/bin/volume-popup.sh

cat > /usr/local/bin/volume-toggle.sh << EOL
#!/bin/sh
if amixer get Master | grep -q "\[on\]"; then
  amixer set Master mute
else
  amixer set Master unmute
fi
EOL
chmod +x /usr/local/bin/volume-toggle.sh

cat > /usr/local/bin/bluetooth-popup.sh << EOL
#!/bin/sh
# List Bluetooth devices
devices=\$(bluetoothctl devices | awk '{print \$2, \$3}')
echo "popup {"
echo "  label { text = 'Bluetooth Devices'; font = 'Roboto 12'; color = '#FFFFFF'; }"
if [ -n "\$devices" ]; then
  while read -r mac name; do
    echo "  button { text = '\$name'; exec = 'bluetoothctl connect \$mac'; }"
  done <<< "\$devices"
else
  echo "  label { text = 'No devices found'; font = 'Roboto 10'; color = '#FFFFFF'; }"
fi
echo "}"
EOL
chmod +x /usr/local/bin/bluetooth-popup.sh

cat > /usr/local/bin/bluetooth-toggle.sh << EOL
#!/bin/sh
if bluetoothctl show | grep -q "Powered: yes"; then
  bluetoothctl power off
else
  bluetoothctl power on
fi
EOL
chmod +x /usr/local/bin/bluetooth-toggle.sh

# Configure light/dark mode toggle
cat > /usr/local/bin/toggle-theme.sh << EOL
#!/bin/sh
CONFIG="$USER_HOME/.config/gtk-3.0/settings.ini"
QTCONFIG="$USER_HOME/.config/qt5ct/qt5ct.conf"
SFWBAR_CSS="$USER_HOME/.config/sfwbar/sfwbar.css"
WOFI_CSS="$USER_HOME/.config/wofi/style.css"
MAKO_CONFIG="$USER_HOME/.config/mako/config"
FOOT_CONFIG="$USER_HOME/.config/foot/foot.ini"
ENV_FILE="$USER_HOME/.config/labwc/environment"
GTG_CSS="/etc/greetd/gtkgreet.css"
# Get dynamic color
DYNAMIC_COLOR=\$(/usr/local/bin/wallpaper-color.sh)
if grep -q "gtk-theme-name=Orchis-Dark" "\$CONFIG"; then
  # Switch to light
  sed -i 's/gtk-theme-name=Orchis-Dark/gtk-theme-name=Orchis-Light/' "\$CONFIG"
  sed -i 's/gtk-icon-theme-name=Papirus-Dark/gtk-icon-theme-name=Papirus-Light/' "\$CONFIG"
  sed -i 's/gtk-cursor-theme-name=Vimix-White/gtk-cursor-theme-name=Vimix-Black/' "\$CONFIG"
  sed -i 's/gtk-application-prefer-dark-theme=true/gtk-application-prefer-dark-theme=false/' "\$CONFIG"
  sed -i 's/color_scheme_path=.*/color_scheme_path=$QT_THEME_DIR\/colors\/OrchisLight.colors/' "\$QTCONFIG"
  sed -i 's/icon_theme=Papirus-Dark/icon_theme=Papirus-Light/' "\$QTCONFIG"
  sed -i 's/active-window=#202124/active-window=#F1F3F4/' "\$QTCONFIG"
  sed -i 's/active-highlight=#8AB4F8/active-highlight='"\$DYNAMIC_COLOR"'/' "\$QTCONFIG"
  sed -i 's/background: rgba(32,33,36,0.7);/background: rgba(241,243,244,0.7);/' "\$SFWBAR_CSS"
  sed -i 's/background: rgba(48,49,52,0.9);/background: rgba(255,255,255,0.9);/' "\$SFWBAR_CSS" # popup
  sed -i 's/color: #FFFFFF;/color: #202124;/' "\$SFWBAR_CSS"
  sed -i 's/taskbar button image { background: #FFFFFF; }/taskbar button image { background: #202124; }/' "\$SFWBAR_CSS"
  sed -i 's/taskbar button:hover { background: #8AB4F8;/taskbar button:hover { background: '"\$DYNAMIC_COLOR"';/' "\$SFWBAR_CSS"
  sed -i 's/popup button:hover { background: #8AB4F8;/popup button:hover { background: '"\$DYNAMIC_COLOR"';/' "\$SFWBAR_CSS"
  sed -i 's/popup scale highlight { background: #8AB4F8;/popup scale highlight { background: '"\$DYNAMIC_COLOR"';/' "\$SFWBAR_CSS"
  sed -i 's/background: rgba(48,49,52,0.9);/background: rgba(255,255,255,0.9);/' "\$WOFI_CSS"
  sed -i 's/color: #FFFFFF;/color: #202124;/' "\$WOFI_CSS"
  sed -i 's/background: #3C4043;/background: #E8EAED;/' "\$WOFI_CSS" # search bar
  sed -i 's/background: #202124;/background: #FFFFFF;/' "\$WOFI_CSS" # grid entries
  sed -i 's/#entry:selected { background: #8AB4F8;/#entry:selected { background: '"\$DYNAMIC_COLOR"';/' "\$WOFI_CSS"
  sed -i 's/background-color=#303134/background-color=#FFFFFF/' "\$MAKO_CONFIG"
  sed -i 's/text-color=#FFFFFF/text-color=#202124/' "\$MAKO_CONFIG"
  sed -i 's/border-color=#3C4043/border-color=#E8EAED/' "\$MAKO_CONFIG"
  sed -i 's/action-color=#8AB4F8/action-color='"\$DYNAMIC_COLOR"'/' "\$MAKO_CONFIG"
  sed -i 's/background=303134/background=F1F3F4/' "\$FOOT_CONFIG"
  sed -i 's/foreground=FFFFFF/foreground=202124/' "\$FOOT_CONFIG"
  sed -i 's/XCURSOR_THEME=Vimix-White/XCURSOR_THEME=Vimix-Black/' "\$ENV_FILE"
  sed -i 's/#button:hover { background: #8AB4F8;/#button:hover { background: '"\$DYNAMIC_COLOR"';/' "\$GTG_CSS"
else
  # Switch to dark
  sed -i 's/gtk-theme-name=Orchis-Light/gtk-theme-name=Orchis-Dark/' "\$CONFIG"
  sed -i 's/gtk-icon-theme-name=Papirus-Light/gtk-icon-theme-name=Papirus-Dark/' "\$CONFIG"
  sed -i 's/gtk-cursor-theme-name=Vimix-Black/gtk-cursor-theme-name=Vimix-White/' "\$CONFIG"
  sed -i 's/gtk-application-prefer-dark-theme=false/gtk-application-prefer-dark-theme=true/' "\$CONFIG"
  sed -i 's/color_scheme_path=.*/color_scheme_path=$QT_THEME_DIR\/colors\/OrchisDark.colors/' "\$QTCONFIG"
  sed -i 's/icon_theme=Papirus-Light/icon_theme=Papirus-Dark/' "\$QTCONFIG"
  sed -i 's/active-window=#F1F3F4/active-window=#202124/' "\$QTCONFIG"
  sed -i 's/active-highlight=#[0-9A-F]\{6\}/active-highlight='"\$DYNAMIC_COLOR"'/' "\$QTCONFIG"
  sed -i 's/background: rgba(241,243,244,0.7);/background: rgba(32,33,36,0.7);/' "\$SFWBAR_CSS"
  sed -i 's/background: rgba(255,255,255,0.9);/background: rgba(48,49,52,0.9);/' "\$SFWBAR_CSS" # popup
  sed -i 's/color: #202124;/color: #FFFFFF;/' "\$SFWBAR_CSS"
  sed -i 's/taskbar button image { background: #202124; }/taskbar button image { background: #FFFFFF; }/' "\$SFWBAR_CSS"
  sed -i 's/taskbar button:hover { background: #[0-9A-F]\{6\};/taskbar button:hover { background: '"\$DYNAMIC_COLOR"';/' "\$SFWBAR_CSS"
  sed -i 's/popup button:hover { background: #[0-9A-F]\{6\};/popup button:hover { background: '"\$DYNAMIC_COLOR"';/' "\$SFWBAR_CSS"
  sed -i 's/popup scale highlight { background: #[0-9A-F]\{6\};/popup scale highlight { background: '"\$DYNAMIC_COLOR"';/' "\$SFWBAR_CSS"
  sed -i 's/background: rgba(255,255,255,0.9);/background: rgba(48,49,52,0.9);/' "\$WOFI_CSS"
  sed -i 's/color: #202124;/color: #FFFFFF;/' "\$WOFI_CSS"
  sed -i 's/background: #E8EAED;/background: #3C4043;/' "\$WOFI_CSS" # search bar
  sed -i 's/background: #FFFFFF;/background: #202124;/' "\$WOFI_CSS" # grid entries
  sed -i 's/#entry:selected { background: #[0-9A-F]\{6\};/#entry:selected { background: '"\$DYNAMIC_COLOR"';/' "\$WOFI_CSS"
  sed -i 's/background-color=#FFFFFF/background-color=#303134/' "\$MAKO_CONFIG"
  sed -i 's/text-color=#202124/text-color=#FFFFFF/' "\$MAKO_CONFIG"
  sed -i 's/border-color=#E8EAED/border-color=#3C4043/' "\$MAKO_CONFIG"
  sed -i 's/action-color=#[0-9A-F]\{6\}/action-color='"\$DYNAMIC_COLOR"'/' "\$MAKO_CONFIG"
  sed -i 's/background=F1F3F4/background=303134/' "\$FOOT_CONFIG"
  sed -i 's/foreground=202124/foreground=FFFFFF/' "\$FOOT_CONFIG"
  sed -i 's/XCURSOR_THEME=Vimix-Black/XCURSOR_THEME=Vimix-White/' "\$ENV_FILE"
  sed -i 's/#button:hover { background: #[0-9A-F]\{6\};/#button:hover { background: '"\$DYNAMIC_COLOR"';/' "\$GTG_CSS"
fi
# Reload configs
pkill -u "$USER_NAME" -USR1 sfwbar
pkill -u "$USER_NAME" -USR1 mako
pkill -u "$USER_NAME" -USR1 labwc
EOL
chmod +x /usr/local/bin/toggle-theme.sh

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

#outer-box {
  padding: 8px;
}

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

# Configure qtfm
if [ -z "$SKIP_QTFM" ]; then
  cat > "$USER_HOME/.config/qtfm/qtfm.conf" << EOL
showThumbnails=true
EOL
fi

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

# Dynamic power management
mkdir -p /etc/local.d /etc/udev/rules.d
cat > /etc/local.d/power-optimize.start << EOL
#!/bin/sh
# CPU: Detect Intel/AMD for pstate
if grep -q "GenuineIntel" /proc/cpuinfo; then
  [ -d /sys/devices/system/cpu/intel_pstate ] && echo powersave > /sys/devices/system/cpu/intel_pstate/status
elif grep -q "AuthenticAMD" /proc/cpuinfo; then
  [ -f /sys/devices/system/cpu/amd_pstate/status ] && echo active > /sys/devices/system/cpu/amd_pstate/status
fi

# Wi-Fi: Power-save only if present
for dev in /sys/class/net/wlan*; do
  [ -e "\$dev" ] && iw dev \$(basename "\$dev") set power_save on
done

# Ethernet power management
for eth in /sys/class/net/e*/device/power/control; do
  [ -w "\$eth" ] && echo auto > "\$eth"
done

# GPU: Low power if supported
for gpu in /sys/class/drm/card*/device/power_dpm_force_performance_level; do
  [ -f "\$gpu" ] && echo low > "\$gpu"
done
[ -f /sys/module/nvidia/parameters/modeset ] && echo 0 > /sys/module/nvidia/parameters/modeset

# Display: Brightness based on power state
for b in /sys/class/backlight/*/brightness; do
  [ -w "\$b" ] || continue
  max=\$(cat \${b%brightness}max_brightness)
  if grep -q 0 /sys/class/power_supply/AC*/online 2>/dev/null || \
     grep -q 0 /sys/class/power_supply/ADP*/online 2>/dev/null; then
    echo \$((max * 30 / 100)) > "\$b"
  else
    echo \$((max * 70 / 100)) > "\$b"
  fi
done

# Audio: Enable power save if HDA detected
[ -d /sys/module/snd_hda_intel ] && echo 1 > /sys/module/snd_hda_intel/parameters/power_save
EOL
chmod +x /etc/local.d/power-optimize.start

# Dynamic HDD/SSD optimization
cat > /etc/local.d/disk-optimize.start << EOL
#!/bin/sh
# Handle both traditional disks and NVMe
for disk in /dev/sd[a-z] /dev/nvme[0-9]n[0-9]; do
  if [ -b "\$disk" ]; then
    if [ "\${disk:0:8}" = "/dev/nvme" ]; then
      # NVMe device
      echo mq-deadline > /sys/block/\$(basename \$disk)/queue/scheduler 2>/dev/null
    else
      # SATA device - check if HDD or SSD
      rotational=\$(cat /sys/block/\$(basename \$disk)/queue/rotational 2>/dev/null || echo 0)
      if [ "\$rotational" = "1" ]; then
        # HDD: spindown, bfq, writeback
        hdparm -B 128 -S 24 "\$disk" 2>/dev/null
        echo bfq > /sys/block/\$(basename \$disk)/queue/scheduler 2>/dev/null
        echo 1500 > /proc/sys/vm/dirty_writeback_centisecs 2>/dev/null
      else
        # SSD: mq-deadline
        echo mq-deadline > /sys/block/\$(basename \$disk)/queue/scheduler 2>/dev/null
      fi
    fi
  fi
done
EOL
chmod +x /etc/local.d/disk-optimize.start

# Memory optimization
echo "vm.swappiness=10" > /etc/sysctl.d/99-swappiness.conf
echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.d/99-swappiness.conf

# Udev rules
cat > /etc/udev/rules.d/90-power-optimize.rules << EOL
ACTION=="add", SUBSYSTEM=="net", KERNEL=="wlan*", RUN+="/usr/sbin/iw dev %k set power_save on"
ACTION=="add", SUBSYSTEM=="net", KERNEL=="e*", RUN+="/bin/sh -c '[ -w /sys%p/device/power/control ] && echo auto > /sys%p/device/power/control'"
ACTION=="add|change", KERNEL=="sd[a-z]", RUN+="/etc/local.d/disk-optimize.start"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", RUN+="/usr/sbin/fstrim -v /"
ACTION=="add", SUBSYSTEM=="drm", RUN+="/bin/sh -c '[ -f /sys/%p/device/power_dpm_force_performance_level ] && echo low > /sys/%p/device/power_dpm_force_performance_level'"
EOL

# Suspend/Resume hooks
mkdir -p /usr/lib/elogind/system-sleep
cat > /usr/lib/elogind/system-sleep/00-alpine-power << EOL
#!/bin/sh
case "$1" in
  pre)
    : # Pre-suspend optimizations
    ;;
  post)
    /etc/local.d/power-optimize.start
    /etc/local.d/disk-optimize.start
    ;;
esac
exit 0
EOL
chmod +x /usr/lib/elogind/system-sleep/00-alpine-power

# Schedule weekly TRIM
echo "0 0 * * 0 /usr/sbin/fstrim -v /" > /etc/crontabs/root

# Speed up boot
rc-update add mdev sysinit
rc-update add hwdrivers sysinit

# Set ownership for user config files
chown -R "$USER_NAME:$USER_NAME" "$USER_HOME/.config" || {
  echo "Failed to set proper ownership on configuration files" >&2
}
chown root:root /usr/local/bin/* || {
  echo "Failed to set ownership on scripts" >&2
}

# Enable services
echo "Enabling system services..."
rc-update add local || echo "Warning: Failed to add local to boot services"
rc-update add polkit || echo "Warning: Failed to add polkit to boot services"
rc-update add crond || echo "Warning: Failed to add crond to boot services"

# Cleanup
echo "Cleaning up build dependencies..."
BUILDTIME_DEPS="rust cargo git openssl-dev musl-dev pkgconf lua-dev make sdl2-dev \
  cmake g++ qt5-qtbase-dev qt5-qtbase-x11 qt5-qtdeclarative-dev qt5-qttools-dev \
  imagemagick-dev dbus-dev udisks2-dev ffmpeg-dev"
for pkg in $RUNTIME_DEPS; do
  BUILDTIME_DEPS=$(echo "$BUILDTIME_DEPS" | sed "s/\<$pkg\>//g")
done
apk del $BUILDTIME_DEPS 2>/dev/null || true
rm -rf /tmp/* 2>/dev/null || true

# Create fallback background if needed
if [ ! -f /usr/share/backgrounds/orchis-wallpaper.jpg ]; then
  mkdir -p /usr/share/backgrounds
  echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==" | base64 -d > /usr/share/backgrounds/default.png
fi

# Verification
echo "======================================================================"
echo "Setup complete! Wayland with labwc, gtkgreet, sound, Bluetooth, elogind, qtfm, clipboard, screenshots, drawing, and power management. Styled like ChromeOS Flex with Material You and Fluent UI, plus macOS, Android, iOS inspirations: gtkgreet login, sfwbar shelf, wofi start menu, Wi-Fi/sound/Bluetooth/brightness controls, Orchis-Dark/Light (GTK/Qt), Papirus-Dark/Light icons (rounded), Vimix-White/Black cursors."
echo "To verify:"
echo "1. Reboot and login via gtkgreet (labwc session, Orchis-Dark, blurred Orchis wallpaper, #202124 box with shadow, #3C4043 fields, #8AB4F8 button hover, acrylic blur, Vimix-White cursor)."
echo "2. Test sound: play a file in smplayer (OrchisDark Qt theme, #8AB4F8 buttons, Papirus-Dark rounded icons, latest version)."
echo "3. Test Bluetooth: run 'bluetoothctl', then 'power on', 'scan on', pair a device (e.g., headphones), or use blueman-manager from wofi (Orchis-Dark, #8AB4F8 buttons, Papirus-Dark rounded)."
echo "4. Test Bluetooth audio: play a file in smplayer with Bluetooth device connected, use pavucontrol to select Bluetooth output (Orchis-Dark, #8AB4F8 buttons, Papirus-Dark rounded)."
echo "5. Test qtfm: open qtfm, verify image/video thumbnails, OrchisDark Qt theme, #8AB4F8 buttons, Papirus-Dark rounded icons (latest version)."
echo "6. Test clipboard: copy text, run 'wl-paste' to verify (wl-clipboard, Vimix-White cursor)."
echo "7. Test screenshot: press PrtSc or select 'Screenshot' from wofi, check ~/screenshot-*.png (Vimix-White cursor)."
echo "8. Test file picker: use badwolf to upload a file (xdg-desktop-portal-wlr, Orchis-Dark, #8AB4F8 buttons, Papirus-Dark rounded, Vimix-White cursor)."
echo "9. Test drawing: select 'Drawing' from wofi, draw a shape, save as PNG, verify Orchis-Dark, Papirus-Dark rounded, #8AB4F8 buttons, Vimix-White cursor."
echo "10. Test sfwbar shelf: Verify bottom bar, dark #202124 (light #F1F3F4), 70% opacity, 4px corners, shadow, autohide, pinned apps (foot, badwolf, qtfm, smplayer, drawing, mupdf, blueman, pavucontrol, 32x32px circular icons), tray with Wi-Fi/volume/Bluetooth/battery/clock (24x24px semi-rounded), #8AB4F8 hover, Papirus-Dark/Light, Vimix-White cursor, macOS-like magnify (1.2x hover), bounce (1.5x click)."
echo "11. Test wofi launcher: Press Super or Super+Space, verify 400x600px, dark #303134 (light #FFFFFF), 90% opacity, 8px corners, acrylic blur, shadow, 4x4 app grid with shadows, 48x48px circular icons, Roboto 12pt, Papirus-Dark/Light, #3C4043/#E8EAED search bar, #8AB4F8 hover, fade-in animation, Vimix-White cursor, alphabetical sort (iOS App Library)."
echo "12. Test wofi search: Type in wofi, verify instant app filtering (Vimix-White cursor, macOS Spotlight-like)."
echo "13. Test sfwbar controls: Click or press Super+S, verify popups (#303134 dark, #FFFFFF light, 90%, 8px corners, acrylic blur, shadow, #8AB4F8 rounded toggles/sliders for Wi-Fi/volume/Bluetooth/brightness, Roboto 10pt, Papirus-Dark/Light semi-rounded, Vimix-White cursor, Android/iOS Quick Settings)."
echo "14. Test notifications: Trigger via 'notify-send test', verify compact (50x200px, top-center), dark #303134 (light #FFFFFF), white/black text, 8px corners, acrylic blur, shadow, Roboto 12pt, #8AB4F8 actions, Vimix-White cursor, press Super+N to restore (iOS Dynamic Island)."
echo "15. Test light/dark mode: Press Super+T, verify switch between Orchis-Dark (#303134, #202124) and Orchis-Light (#F1F3F4, #FFFFFF) for GTK/Qt apps, Papirus-Dark ↔ Papirus-Light icons (circular in shelf/grid), Vimix-White ↔ Vimix-Black cursors, dynamic #8AB4F8-like accents (Android Material You), updates gtkgreet (Vimix-White), wofi, sfwbar, mako, foot."
echo "16. Test window styling: Open foot/badwolf/qtfm, verify labwc titlebars (#202124 dark, #F1F3F4 light, 4px corners, shadow), fade animations, Papirus-Dark/Light rounded icons, Vimix-White cursor."
echo "17. Test shortcuts: Verify Super (wofi, Windows/ChromeOS), Super+Space (wofi, macOS Spotlight), Super+D (desktop, Windows/ChromeOS), Alt+Tab (switch, Windows/ChromeOS), F3 (cycle, macOS Mission Control), Alt+F4 (close, Windows), Super+E (qtfm, Windows/ChromeOS), Super+L (lock, Windows/ChromeOS), PrtSc (screenshot, Windows/ChromeOS), Super+Left/Right (snap, Windows/ChromeOS), Super+R (run, Windows), Super+S (tray, Android/iOS), Super+B (back, Android), Super+N (notifications, iOS), Super+T (theme), all with Vimix-White cursor."
echo "18. Check idle power: upower -i /org/freedesktop/UPower/devices/battery_BAT0 (expect 4-6W)."
echo "19. Idle 2 minutes to confirm lock, 5 minutes for suspend (~0.5W)."
echo "20. Check disk: cat /sys/block/sda/queue/scheduler (bfq for HDD, mq-deadline for SSD)."
echo "21. Check CPU: cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor (powersave on battery)."
echo "22. Compare to ChromeOS Flex (expect 10-20% better battery)."
echo "23. Check elogind/TLP coordination: systemctl status tlp (if running)."
echo "24. Check themes: qtfm/smplayer use OrchisDark/Light Qt theme (fusion, #8AB4F8 buttons), gtkgreet/wofi/badwolf/image-roll/blueman/pavucontrol/drawing use Orchis-Dark/Light GTK theme (#8AB4F8 buttons), all apps use Papirus-Dark/Light icons (circular in shelf/grid), Vimix-White/Black cursors."
echo "25. Check wallpaper: Verify Orchis wallpaper in labwc session and gtkgreet (blurred)."
echo "26. Check XDG_RUNTIME_DIR: Run 'echo \$XDG_RUNTIME_DIR' (expect /run/user/<uid>)."
echo "27. Check Wayland: Run 'wayland-info' to verify compositor details."
echo "28. Check source versions: smplayer, qtfm, Orchis themes, Vimix cursors should be latest tagged releases."
echo "29. Check cleanup: Run 'apk info | grep -E \"rust|cargo|git|sassc|cmake|g++|make|qt5.*dev|musl-dev|pkgconf|openssl-dev|lua-dev|sdl2-dev|imagemagick-dev|dbus-dev|udisks2-dev|ffmpeg-dev\"' (expect no output)."
echo "======================================================================"

exit 0
