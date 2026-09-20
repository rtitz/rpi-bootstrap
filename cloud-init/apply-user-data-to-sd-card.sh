#!/bin/zsh
# ==============================================================================
# UNIVERSAL MACOS FIRST-BOOT IMAGE PROVISIONING SYSTEM
# AUTOMATICALLY DETECTS RASPBERRY PI OS (BOOTFS) OR UBUNTU (SYSTEM-BOOT)
# ==============================================================================

USERDATA_FILE="user-data"
NETWORK_FILE="${NETWORK_FILE:-}"
# Leave NETWORK_FILE empty to use DHCP; set it explicitly to a file such as
# "network-config-pi01" or "network-config-pi02" to deploy a static IP config.

IS_UBUNTU=false

# 1. Dynamically target the active mounted storage media partition layout
if [ -d "/Volumes/bootfs" ]; then
    BOOT_PATH="/Volumes/bootfs"
    USERDATA_FILE=$USERDATA_FILE
    NETWORK_FILE=$NETWORK_FILE
    echo "🎯 TARGET DETECTED: Raspberry Pi OS Flash Partition Layout"
elif [ -d "/Volumes/system-boot" ]; then
    BOOT_PATH="/Volumes/system-boot"
    IS_UBUNTU=true
    USERDATA_FILE=${USERDATA_FILE}-ubuntu
    if [ -n "$NETWORK_FILE" ]; then
      NETWORK_FILE=${NETWORK_FILE}-ubuntu
    fi
    echo "🎯 TARGET DETECTED: Ubuntu Server Flash Partition Layout"
else
    echo "❌ ERROR: No active Raspberry Pi OS or Ubuntu boot volume found in /Volumes/"
    echo "Please verify your SD card or SSD is correctly attached to your Mac."
    exit 1
fi

# 2. Deploy your master universal cloud-init automation files
echo "📦 Injecting unified core automation configuration blueprints..."
cp -v "$USERDATA_FILE" "$BOOT_PATH/user-data"

# Conditional Check: Copy custom file, drop working DHCP fallback for Ubuntu, or skip for Pi OS
if [ -n "$NETWORK_FILE" ]; then
    cp -v "$NETWORK_FILE" "$BOOT_PATH/network-config"
elif [ "$IS_UBUNTU" = true ]; then
    echo "ℹ️  NETWORK_FILE is empty. Overwriting Ubuntu default layout to force DHCP on end0..."
    cat << 'EOF' > "$BOOT_PATH/network-config"
version: 2
ethernets:
  end0:
    dhcp4: true
    optional: true
EOF
else
    echo "ℹ️  INFO: NETWORK_FILE is empty. Skipping deployment for Pi OS (defaults to NetworkManager DHCP)."
fi

# 3. Apply safety-guarded kernel optimizations to cmdline.txt
if [ -f "$BOOT_PATH/cmdline.txt" ]; then
    echo "🛠️ Patching kernel execution line arguments inside cmdline.txt..."

    # 4. Check if the card is Raspberry Pi OS vs Ubuntu Server
    if [ "$IS_UBUNTU" = false ]; then
        # SAFE CHECK: Only inject the NoCloud source flag to Pi OS if it is missing
        if ! grep -q "cloud-init=sources:NoCloud" "$BOOT_PATH/cmdline.txt"; then
            echo "   -> Detected Raspberry Pi OS media. Injecting NoCloud source requirement..."
            sed -i '' 's/$/ cloud-init=sources:NoCloud/' "$BOOT_PATH/cmdline.txt"
            echo "=============================================================================="
            echo "📝 FINAL CMDLINE MATRIX:"
            cat "$BOOT_PATH/cmdline.txt"
            echo -e "\n=============================================================================="
        else
            echo "   -> NoCloud fallback already injected into Pi OS config. Skipping."
        fi
    else
        echo "   -> Detected Ubuntu Server media. Skipping NoCloud seed (handled natively)."
    fi
fi

echo "💾 Flushing internal block cache layers to disk media..."
sync

BOOT_DISK_ID=$(diskutil info "$BOOT_PATH" 2>/dev/null | awk -F': ' '/Device Identifier/ {print $2}')
if [ -n "$BOOT_DISK_ID" ]; then
    BOOT_DISK_PATH="/dev/${BOOT_DISK_ID%s[0-9]*}"
    echo "🔌 Safely ejecting the full removable media device: $BOOT_DISK_PATH"
    diskutil eject "$BOOT_DISK_PATH"
else
    echo "⚠️  Unable to resolve the backing disk; falling back to the mounted boot volume."
    diskutil eject "$BOOT_PATH"
fi

echo "🎉 Success! The storage media is ready to be loaded into your Raspberry Pi node."
