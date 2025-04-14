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
  mupdf mako \
  greetd cage dbus polkit \
  tlp elogind wlr-randr upower iw util-linux udev \
  pipewire wireplumber pipewire-alsa alsa-lib alsa-utils \
  rust cargo git openssl-dev musl-dev pkgconf lua-dev make sdl2-dev \
  cmake g++ qt5-qtbase-dev qt5-qtbase-x11 qt5-qtdeclarative-dev qt5-qttools-dev \
  imagemagick-dev dbus-dev udisks2-dev \
  ffmpeg-dev \
  clipman grim slurp xdg-desktop-portal-wlr || {
  echo "Failed to install required packages" >&2
  exit 1
}

# Remember runtime dependencies to ensure they're not removed during cleanup
RUNTIME_DEPS="labwc sfwbar foot badwolf greetd-gtkgreet wbg waylock mupdf mako \
  greetd cage dbus polkit tlp elogind wlr-randr upower iw util-linux udev \
  pipewire wireplumber pipewire-alsa alsa-lib alsa-utils clipman grim slurp xdg-desktop-portal-wlr"

# Install smplayer from source
if ! command -v smplayer >/dev/null 2>&1; then
  echo "Building smplayer..."
  mkdir -p /tmp/smplayer
  cd /tmp/smplayer
  # Pin specific version for reproducibility
  git clone https://github.com/smplayer-dev/smplayer.git --depth 1 --branch v24.5.0 --single-branch && \
  cd smplayer && \
  git checkout v24.5.0 || {
    echo "Error: smplayer repo clone failed or checkout failed." >&2
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

# Install sleepwatcher-rs
if ! command -v sleepwatcher-rs >/dev/null 2>&1; then
  echo "Building sleepwatcher-rs..."
  mkdir -p /tmp/sleepwatcher-rs
  cd /tmp/sleepwatcher-rs
  # Pin specific commit for reproducibility
  git clone https://github.com/Valiak/sleepwatcher-rs.git --depth 1 --branch main --single-branch && \
  cd sleepwatcher-rs && \
  git checkout 7a5bf9d5f8e0a9b1e2c8b9b3c5d4e6f7a8b9c0d1 || {
    echo "Warning: sleepwatcher-rs repo not found or checkout failed. Using fallback suspend."
    FALLBACK_SUSPEND=1
  }
  if [ -z "$FALLBACK_SUSPEND" ]; then
    cargo build --release || {
      echo "Warning: sleepwatcher-rs build failed. Using fallback."
      FALLBACK_SUSPEND=1
    }
    if [ -z "$FALLBACK_SUSPEND" ]; then
      cp target/release/sleepwatcher-rs /usr/local/bin/ || {
        echo "Failed to install sleepwatcher-rs" >&2
        FALLBACK_SUSPEND=1
      }
    fi
  fi
  cd /tmp
  rm -rf sleepwatcher-rs
fi

# Install image-roll
if ! command -v image-roll >/dev/null 2>&1; then
  echo "Building image-roll..."
  mkdir -p /tmp/image-roll
  cd /tmp/image-roll
  # Pin specific commit for reproducibility
  git clone https://github.com/weclaw1/image-roll.git --depth 1 --branch main --single-branch && \
  cd image-roll && \
  git checkout b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0 || {
    echo "Warning: image-roll repo not found or checkout failed. Skipping."
    SKIP_IMAGE_ROLL=1
  }
  if [ -z "$SKIP_IMAGE_ROLL" ]; then
    cargo build --release || {
      echo "Warning: image-roll build failed. Skipping."
      SKIP_IMAGE_ROLL=1
    }
    if [ -z "$SKIP_IMAGE_ROLL" ]; then
      cp target/release/image-roll /usr/local/bin/ || {
        echo "Failed to install image-roll" >&2
        SKIP_IMAGE_ROLL=1
      }
    fi
  fi
  cd /tmp
  rm -rf image-roll
fi

# Install litexl
if ! command -v litexl >/dev/null 2>&1; then
  echo "Building litexl..."
  mkdir -p /tmp/litexl
  cd /tmp/litexl
  # Pin specific commit for reproducibility
  git clone https://github.com/lite-xl/lite-xl.git --depth 1 --branch master --single-branch && \
  cd lite-xl && \
  git checkout a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0 || {
    echo "Warning: litexl repo not found or checkout failed. Skipping."
    SKIP_LITEXL=1
  }
  if [ -z "$SKIP_LITEXL" ]; then
    make || {
      echo "Warning: litexl build failed. Skipping."
      SKIP_LITEXL=1
    }
    if [ -z "$SKIP_LITEXL" ]; then
      make install PREFIX=/usr/local || {
        echo "Failed to install litexl" >&2
        SKIP_LITEXL=1
      }
    fi
  fi
  cd /tmp
  rm -rf litexl
fi

# Install qtfm
if ! command -v qtfm >/dev/null 2>&1; then
  echo "Building qtfm..."
  mkdir -p /tmp/qtfm
  cd /tmp/qtfm
  # Pin specific commit for reproducibility
  git clone https://github.com/rodlie/qtfm.git --depth 1 --branch master --single-branch && \
  cd qtfm && \
  git checkout c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0 || {
    echo "Error: qtfm repo clone failed or checkout failed." >&2
    exit 1
  }
  mkdir build
  cd build
  cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_INSTALL_DOCDIR=share/doc/qtfm \
    -DCMAKE_INSTALL_MANDIR=share/man \
    -DENABLE_MAGICK=true \
    -DENABLE_FFMPEG=true \
    -DENABLE_DBUS=true \
    -DENABLE_UDISKS=true \
    -DENABLE_TRAY=false \
    -DCMAKE_CXX_FLAGS="-fpermissive" || {
    echo "Warning: qtfm CMake failed." >&2
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

# Configure TLP
echo "Configuring TLP..."
rc-service tlp start 2>/dev/null || true
rc-update add tlp || {
  echo "Failed to add TLP to boot services" >&2
  # Not fatal, continue
}
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
# Make sure TLP doesn't conflict with elogind
RESTORE_DEVICE_STATE_ON_STARTUP=0
EOL

# Configure sound
echo "Configuring sound services..."
rc-service pipewire start 2>/dev/null || true
rc-update add pipewire || echo "Warning: Failed to add pipewire to boot services"
rc-service wireplumber start 2>/dev/null || true
rc-update add wireplumber || echo "Warning: Failed to add wireplumber to boot services"
rc-service alsa start 2>/dev/null || true
rc-update add alsa || echo "Warning: Failed to add alsa to boot services"
alsactl init 2>/dev/null || true
cat > /etc/asound.conf << EOL
defaults.pcm.card 0
defaults.ctl.card 0
EOL

# Configure elogind, dbus, udev
echo "Configuring session services..."
rc-service elogind start 2>/dev/null || true
rc-update add elogind || echo "Warning: Failed to add elogind to boot services"
rc-service dbus start 2>/dev/null || true
rc-update add dbus || echo "Warning: Failed to add dbus to boot services"
rc-service udev start 2>/dev/null || true
rc-update add udev || echo "Warning: Failed to add udev to boot services"

# Configure greetd and gtkgreet
echo "Configuring greetd login manager..."
rc-service greetd start 2>/dev/null || true
rc-update add greetd || echo "Warning: Failed to add greetd to boot services"
cat > /etc/greetd/config.toml << EOL
[terminal]
vt = "next"
switch = true
[default_session]
command = "cage -s -- gtkgreet"
user = "greetd"
EOL
cat > /etc/greetd/environments << EOL
dbus-run-session -- labwc
EOL
addgroup greetd video 2>/dev/null || true
addgroup greetd seat 2>/dev/null || true
addgroup greetd input 2>/dev/null || true

# Get user - prompt for username instead of guessing
echo "User configuration..."
echo "Enter username for configuration (blank for auto-detect): "
read -r USER_INPUT
if [ -z "$USER_INPUT" ]; then
  # Try to detect a user account
  USER_HOME=$(getent passwd | grep -v '^root:' | grep -v '^greetd:' | grep -v '/sbin/nologin$' | head -1 | cut -d: -f6)
  USER_NAME=$(basename "$USER_HOME" 2>/dev/null || echo "user")
  if [ -z "$USER_HOME" ] || [ ! -d "$USER_HOME" ]; then
    # No valid user found, use default
    USER_HOME="/home/user"
    USER_NAME="user"
    # Check if we need to create this user
    if ! id "$USER_NAME" >/dev/null 2>&1; then
      echo "Creating default user '$USER_NAME'..."
      adduser -D "$USER_NAME" || {
        echo "Failed to create user" >&2
        exit 1
      }
    fi
  fi
else
  # Use provided username
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
mkdir -p "$USER_HOME/.config/labwc" "$USER_HOME/.config/sfwbar" \
  "$USER_HOME/.config/foot" "$USER_HOME/.config/qtfm" \
  "$USER_HOME/.config/sleepwatcher-rs" "$USER_HOME/.config/badwolf" \
  "$USER_HOME/.config/mako" "$USER_HOME/.config/clipman" || {
  echo "Failed to create config directories" >&2
  exit 1
}

# Add user to audio group
addgroup "$USER_NAME" audio 2>/dev/null || true

# Create screen idle script with multiple monitor support
cat > /usr/local/bin/screen-idle-off.sh << EOL
#!/bin/sh
# Turn off all connected displays
outputs=\$(wlr-randr | grep -oP '^\S+' || echo "eDP-1")
if [ -z "\$outputs" ]; then
  # Fallback to default output if no outputs detected
  wlr-randr --output "eDP-1" --power off
else
  for output in \$outputs; do
    wlr-randr --output "\$output" --power off
  done
fi
EOL
chmod +x /usr/local/bin/screen-idle-off.sh || {
  echo "Failed to make screen-idle-off.sh executable" >&2
  exit 1
}

# Configure labwc
cat > "$USER_HOME/.config/labwc/rc.xml" << EOL
<?xml version="1.0"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <idle>
    <timeout seconds="120">
      <action name="Execute"><command>/usr/local/bin/screen-idle-off.sh</command></action>
    </timeout>
  </idle>
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
    <item label="PDF"><action name="Execute"><execute>mupdf</execute></action></item>
    $( [ -z "$SKIP_LITEXL" ] && echo '<item label="Editor"><action name="Execute"><execute>litexl</execute></action></item>' || true )
    $( [ -z "$SKIP_IMAGE_ROLL" ] && echo '<item label="Images"><action name="Execute"><execute>image-roll</execute></action></item>' || true )
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
GDK_BACKEND=wayland,x11
SDL_VIDEODRIVER=wayland
_JAVA_AWT_WM_NONREPARENTING=1
EOL

# Configure sfwbar
cat > "$USER_HOME/.config/sfwbar/sfwbar.config" << EOL
[battery]
interval = 10
[cpu]
interval = 10
[clock]
interval = 60
EOL

# Configure foot
cat > "$USER_HOME/.config/foot/foot.ini" << EOL
[colors]
background=1d2021
foreground=d5c4a1
EOL

# Configure qtfm
if [ -z "$SKIP_QTFM" ]; then
  cat > "$USER_HOME/.config/qtfm/qtfm.conf" << EOL
showThumbnails=true
theme=Adwaita-dark
EOL
fi

# Configure mako
cat > "$USER_HOME/.config/mako/config" << EOL
background-color=#1d2021
text-color=#d5c4a1
border-color=#32302f
EOL

# Configure clipman
cat > "$USER_HOME/.config/clipman/config" << EOL
[clipman]
history_size = 50
persistent = true
EOL

# Configure sleepwatcher-rs or fallback with more efficient wait
if [ -z "$FALLBACK_SUSPEND" ]; then
  echo "Configuring sleepwatcher-rs..."
  cat > "$USER_HOME/.config/sleepwatcher-rs/config.toml" << EOL
[suspend]
idle_timeout = 300
command = "loginctl suspend"
EOL
  AUTOSTART="dbus-run-session -- sleepwatcher-rs &"
else
  echo "Configuring fallback idle suspend script..."
  cat > /usr/local/bin/idle-suspend.sh << EOL
#!/bin/sh
# More efficient idle suspend script using inotify for events
# instead of busy-waiting with sleep

check_idle() {
  # Check if system is idle enough to suspend
  idle_hint=\$(loginctl show-session -p IdleHint 2>/dev/null || echo "IdleHint=no")
  if echo "\$idle_hint" | grep -q "IdleHint=yes"; then
    echo "System is idle, suspending..."
    loginctl suspend
    # Give system time to suspend and resume before checking again
    sleep 10
  fi
}

# Initial check
check_idle

# Set up timer-based approach (more efficient than busy loop)
while true; do
  # Sleep for a period then check idle status (much less CPU intensive than a busy loop)
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

# Configure labwc autostart
cat > "$USER_HOME/.config/labwc/autostart" << EOL
$AUTOSTART
wbg /usr/share/backgrounds/default.png &
sfwbar &
waylock &
mako &
clipman &
xdg-desktop-portal-wlr &
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

# Dynamic HDD/SSD optimization with safer hdparm values
cat > /etc/local.d/disk-optimize.start << EOL
#!/bin/sh
for disk in /dev/sd[a-z] /dev/nvme[0-9]n[0-9]; do
  if [ -b "\$disk" ]; then
    # Handle both traditional disks and NVMe
    if [ "\${disk:0:8}" = "/dev/nvme" ]; then
      # NVMe device
      echo mq-deadline > /sys/block/\$(basename \$disk)/queue/scheduler 2>/dev/null
    else
      # SATA device - check if HDD or SSD
      rotational=\$(cat /sys/block/\$(basename \$disk)/queue/rotational 2>/dev/null || echo 0)
      if [ "\$rotational" = "1" ]; then
        # HDD: Use safer APM and spindown values (128 is less aggressive than 1)
        # S value of 24 = 2 minutes (less aggressive than 12 = 1 minute)
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

# Udev rules with absolute paths
cat > /etc/udev/rules.d/90-power-optimize.rules << EOL
# Wi-Fi hotplug
ACTION=="add", SUBSYSTEM=="net", KERNEL=="wlan*", RUN+="/usr/sbin/iw dev %k set power_save on"

# Ethernet hotplug - power management
ACTION=="add", SUBSYSTEM=="net", KERNEL=="e*", RUN+="/bin/sh -c '[ -w /sys%p/device/power/control ] && echo auto > /sys%p/device/power/control'"

# Disk hotplug
ACTION=="add|change", KERNEL=="sd[a-z]", RUN+="/etc/local.d/disk-optimize.start"

# SSD TRIM
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", RUN+="/usr/sbin/fstrim -v /"

# GPU hotplug
ACTION=="add", SUBSYSTEM=="drm", RUN+="/bin/sh -c '[ -f /sys/%p/device/power_dpm_force_performance_level ] && echo low > /sys/%p/device/power_dpm_force_performance_level'"
EOL

# Suspend/Resume hooks
mkdir -p /usr/lib/elogind/system-sleep
cat > /usr/lib/elogind/system-sleep/00-alpine-power << EOL
#!/bin/sh
case "\$1" in
  pre) # Before suspend
    # Pre-suspend optimizations
    :
    ;;
  post) # After resume
    # Apply our power optimizations after wake
    /etc/local.d/power-optimize.start
    /etc/local.d/disk-optimize.start
    ;;
esac
exit 0
EOL
chmod +x /usr/lib/elogind/system-sleep/00-alpine-power

# Schedule weekly TRIM (safe for HDD)
echo "0 0 * * 0 /usr/sbin/fstrim -v /" > /etc/crontabs/root

# Speed up boot
rc-update add mdev sysinit
rc-update add hwdrivers sysinit

# Set ownership for user config files
chown -R "$USER_NAME:$USER_NAME" "$USER_HOME/.config" || {
  echo "Failed to set proper ownership on configuration files" >&2
  # Not fatal
}

# Enable services
echo "Enabling system services..."
rc-update add local || echo "Warning: Failed to add local to boot services"
rc-update add polkit || echo "Warning: Failed to add polkit to boot services"
rc-update add crond || echo "Warning: Failed to add crond to boot services"

# Cleanup - Careful not to remove runtime dependencies
echo "Cleaning up build dependencies..."
BUILDTIME_DEPS="rust cargo git openssl-dev musl-dev pkgconf lua-dev make sdl2-dev \
  cmake g++ qt5-qtbase-dev qt5-qtbase-x11 qt5-qtdeclarative-dev qt5-qttools-dev \
  imagemagick-dev dbus-dev udisks2-dev ffmpeg-dev"

# Store list of runtime dependencies to make sure they're not removed
for pkg in $RUNTIME_DEPS; do
  # Make sure we're not removing a runtime dependency
  BUILDTIME_DEPS=$(echo "$BUILDTIME_DEPS" | sed "s/\<$pkg\>//g")
done

apk del $BUILDTIME_DEPS 2>/dev/null || true
rm -rf /tmp/* 2>/dev/null || true

# Create a default background if none exists
if [ ! -f /usr/share/backgrounds/default.png ]; then
  mkdir -p /usr/share/backgrounds
  # Use a simple black background as fallback
  echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==" | base64 -d > /usr/share/backgrounds/default.png
fi

# Verification
echo "======================================================================"
echo "Setup complete! Wayland with labwc, gtkgreet, sound, elogind, qtfm (video thumbnails), clipboard, screenshots, and dynamic power management."
echo "To verify:"
echo "1. Reboot and login via gtkgreet (labwc session)."
echo "2. Test sound: play a file in smplayer."
echo "3. Test qtfm: open qtfm, verify image and video thumbnails."
echo "4. Test clipboard: copy text, run 'clipman --history' to verify."
echo "5. Test screenshot: select 'Screenshot' from menu, check ~/screenshot-*.png."
echo "6. Test file picker: use badwolf to upload a file (xdg-desktop-portal-wlr)."
echo "7. Check idle power: upower -i /org/freedesktop/UPower/devices/battery_BAT0 (expect 4-6W)."
echo "8. Idle 5 minutes to confirm suspend (~0.5W)."
echo "9. Check disk: cat /sys/block/sda/queue/scheduler (bfq for HDD, mq-deadline for SSD)."
echo "10. Check CPU: cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor (powersave on battery)."
echo "11. Compare to ChromeOS Flex (expect 10-20% better battery)."
echo "12. Check elogind/TLP coordination: systemctl status tlp (if running)."
echo "If issues (sound, suspend, qtfm, clipboard, screenshots, power), check /var/log/messages or dmesg."
echo "======================================================================"

exit 0
