#!/bin/bash

# ==========================================
# Terminal Colors
# ==========================================
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
NC="\033[0m" # No Color

# Helper Logging Functions
fatal() {
    echo -e "${RED}[FATAL] $1${NC}"
    exit 1
}

info() {
    echo -e "${CYAN}==> $1${NC}"
}

success() {
    echo -e "${GREEN}==> $1${NC}"
}

warn() {
    echo -e "${YELLOW}==> $1${NC}"
}

# ==========================================
# ROM Root Detection & Verification
# ==========================================
find_rom_root() {
    if [ -n "$ANDROID_BUILD_TOP" ] && [ -f "$ANDROID_BUILD_TOP/build/envsetup.sh" ]; then
        echo "$ANDROID_BUILD_TOP"
        return
    fi

    # Walk upward from the script's directory until build/envsetup.sh is located
    local DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    while [ "$DIR" != "/" ]; do
        if [ -f "$DIR/build/envsetup.sh" ]; then
            echo "$DIR"
            return
        fi
        DIR="$(dirname "$DIR")"
    done

    # Fall back to current working directory
    pwd
}

ROM_ROOT="$(find_rom_root)"

if [ ! -f "$ROM_ROOT/build/envsetup.sh" ]; then
    fatal "Could not locate root of Android source tree (build/envsetup.sh not found)!"
fi

echo -e "${BLUE}====================================================${NC}"
echo -e "${GREEN}   ROM Dependency Sync for POCO F4 (munch)          ${NC}"
echo -e "${BLUE}====================================================${NC}"
info "Target ROM root: $ROM_ROOT"

FAILED_REPOS=()

# Function to clone safely
clone_repo() {
    local NAME="$1"
    local URL="$2"
    local BRANCH="$3"
    local DEST="$ROM_ROOT/$4"
    local DEPTH="$5"

    if [ -d "$DEST/.git" ]; then
        info "$NAME already exists at $DEST. Skipping clone."
        return 0
    elif [ -d "$DEST" ]; then
        warn "$DEST exists but is not a valid git repository. Removing..."
        rm -rf "$DEST"
    fi

    local ARGS=()
    if [ -n "$BRANCH" ]; then
        ARGS+=("-b" "$BRANCH")
    fi

    if [ "$DEPTH" = "shallow" ]; then
        ARGS+=("--depth" "1")
    fi

    info "Cloning $NAME into $DEST..."
    mkdir -p "$(dirname "$DEST")"
    if ! git clone "${ARGS[@]}" "$URL" "$DEST"; then
        echo -e "${RED}[ERROR] Failed to clone $NAME ($DEST)${NC}"
        rm -rf "$DEST"
        FAILED_REPOS+=("$NAME -> $DEST")
    fi
}

check_step() {
    local STEP_NAME="$1"
    if [ ${#FAILED_REPOS[@]} -eq 0 ]; then
        success "$STEP_NAME completed successfully!"
    else
        echo -e "${RED}----------------------------------------------------${NC}"
        echo -e "${RED}[FATAL] $STEP_NAME failed! Missing components:${NC}"
        for failed in "${FAILED_REPOS[@]}"; do
            echo -e "${RED}  - $failed${NC}"
        done
        echo -e "${RED}----------------------------------------------------${NC}"
        exit 1
    fi
}

# ==========================================
# Step 1: Device-Side Core Resources
# ==========================================
info "Step 1: Cloning core device resources (CDT, VT, CVT, KT)..."

clone_repo "Common Device Tree (CDT)" "https://github.com/DeadlyShroud/device_xiaomi_sm8250-common" "aosp-17" "device/xiaomi/sm8250-common" "shallow"
clone_repo "Device Vendor Tree (VT)" "https://github.com/DeadlyShroud/vendor_xiaomi_munch" "aosp-17" "vendor/xiaomi/munch" "shallow"
clone_repo "Common Vendor Tree (CVT)" "https://github.com/DeadlyShroud/vendor_xiaomi_sm8250-common" "aosp-17" "vendor/xiaomi/sm8250-common" "shallow"
clone_repo "Kernel Tree (KT)" "https://github.com/munch-devs/android_kernel_xiaomi_munch" "main" "kernel/xiaomi/sm8250" "full"

check_step "Step 1 (Core Device Resources)"

# ==========================================
# Step 2: Firmware & Camera Blobs
# ==========================================
info "Step 2: Cloning firmware package and MIUI camera blobs..."

clone_repo "Device Firmware" "https://codeberg.org/munch-devs/android_vendor_xiaomi_munch-firmware" "17" "vendor/xiaomi/munch-firmware" "shallow"
clone_repo "MIUI Camera Vendor" "https://github.com/munch-devs/android_vendor_xiaomi_miuicamera" "17" "vendor/xiaomi/miuicamera" "shallow"

check_step "Step 2 (Firmware & Camera Blobs)"

# ==========================================
# Step 3: Hardware Interfaces & HALs
# ==========================================
info "Step 3: Cloning hardware HALs (Xiaomi & Dolby)..."

clone_repo "Hardware Xiaomi" "https://github.com/LineageOS/android_hardware_xiaomi" "lineage-24.0" "hardware/xiaomi" "full"
clone_repo "Hardware Dolby" "https://github.com/Tsaritsa-Prjkt/android_hardware_dolby" "lineage-24.0" "hardware/dolby" "full"

check_step "Step 3 (Hardware Interfaces)"

# ==========================================
# Step 4: Packages & Custom Apps
# ==========================================
info "Step 4: Cloning supplementary apps & audio enhancements..."

clone_repo "GameBar" "https://github.com/kenway214/packages_apps_GameBar.git" "lineage-23.2" "packages/apps/GameBar" "full"
clone_repo "ViPER4AndroidFX" "https://github.com/swiitch-OFF-Lab/packages_apps_ViPER4AndroidFX" "main" "packages/apps/ViPER4AndroidFX" "full"

check_step "Step 4 (Packages & Custom Apps)"

# ==========================================
# Step 5: Signing & Release Keys
# ==========================================
info "Step 5: Cloning private release keys..."

clone_repo "Lineage Private Keys" "https://github.com/Tsaritsa-Prjkt/android_vendor_lineage-priv_keys" "lineage-24.0" "vendor/lineage-priv/keys" "shallow"

check_step "Step 5 (Signing Keys)"

# ==========================================
# Step 6: Kernel Submodules (KernelSU)
# ==========================================
info "Step 6: Initializing and updating KernelSU submodules..."

if [ -d "$ROM_ROOT/kernel/xiaomi/sm8250" ]; then
    cd "$ROM_ROOT/kernel/xiaomi/sm8250" || fatal "Failed to enter kernel directory"
    
    info "Updating submodules to pinned commits..."
    if git submodule update --init --recursive; then
        success "Kernel submodules updated successfully!"
    else
        echo -e "${RED}[ERROR] Failed to update kernel submodules!${NC}"
        FAILED_REPOS+=("Kernel submodules -> kernel/xiaomi/sm8250")
    fi
    
    cd "$ROM_ROOT" || fatal "Failed to return to ROM root"
else
    echo -e "${RED}[ERROR] kernel/xiaomi/sm8250 does not exist!${NC}"
    FAILED_REPOS+=("Kernel directory missing -> kernel/xiaomi/sm8250")
fi

check_step "Step 6 (Kernel Submodule Update)"

# ==========================================
# Step 7: Signing Keys Setup
# ==========================================
info "Step 7: Configuring release signing keys..."

if [ -d "$ROM_ROOT/vendor/lineage-priv/keys" ]; then
    cd "$ROM_ROOT/vendor/lineage-priv/keys" || fatal "Failed to enter keys directory"
    
    if [ -f "keys.sh" ]; then
        info "Executing keys.sh..."
        chmod +x keys.sh
        if bash ./keys.sh; then
            success "Signing keys configured successfully!"
        else
            echo -e "${RED}[ERROR] Failed while running keys.sh!${NC}"
            FAILED_REPOS+=("Keys script execution -> vendor/lineage-priv/keys/keys.sh")
        fi
    else
        warn "keys.sh not found inside vendor/lineage-priv/keys! Skipping."
    fi

    cd "$ROM_ROOT" || fatal "Failed to return to ROM root"
else
    echo -e "${RED}[ERROR] vendor/lineage-priv/keys does not exist!${NC}"
    FAILED_REPOS+=("Keys directory missing -> vendor/lineage-priv/keys")
fi

check_step "Step 7 (Signing Keys Execution)"

# ==========================================
# Final Status
# ==========================================
echo -e "${BLUE}====================================================${NC}"
success "All munch resources have been successfully verified and prepared!"
echo -e "${BLUE}====================================================${NC}"

exit 0
