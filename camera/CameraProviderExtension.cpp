/*
 * Copyright (C) 2024 LibreMobileOS Foundation
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include "CameraProviderExtension.h"

#include <fstream>

#define TORCH_BRIGHTNESS "brightness"
#define TORCH_MAX_BRIGHTNESS "max_brightness"
#define TOGGLE_SWITCH "/sys/devices/platform/soc/c440000.qcom,spmi/spmi-0/spmi0-05/c440000.qcom,spmi:qcom,pm8150l@5:qcom,leds@d300/leds/led:switch_2/brightness"

static const std::string kTorchLedPath = "/sys/devices/platform/soc/c440000.qcom,spmi/spmi-0/spmi0-05/c440000.qcom,spmi:qcom,pm8150l@5:qcom,leds@d300/leds/led:torch_0";

template <typename T>
static void set(const std::string& path, const T& value) {
    std::ofstream file(path);
    if (file.is_open()) {
        file << value;
    }
}

template <typename T>
static T get(const std::string& path, const T& def) {
    std::ifstream file(path);
    T result;

    if (!file.is_open()) {
        return def;
    }

    file >> result;
    return file.fail() ? def : result;
}

bool supportsTorchStrengthControlExt() {
    return true;
}

bool supportsSetTorchModeExt() {
    return false;
}

int32_t getTorchDefaultStrengthLevelExt() {
    return 59;
}

int32_t getTorchMaxStrengthLevelExt() {
    return 255;
}

int32_t getTorchStrengthLevelExt() {
    auto node = kTorchLedPath + "/" + TORCH_BRIGHTNESS;
    return get(node, 0);
}

void setTorchStrengthLevelExt(int32_t torchStrength, bool enabled) {
    set(TOGGLE_SWITCH, 0);
    auto node = kTorchLedPath + "/" + TORCH_BRIGHTNESS;
    set(node, torchStrength);
    if (enabled)
        set(TOGGLE_SWITCH, 255);
}

void setTorchModeExt(bool enabled) {
    int32_t strength = getTorchDefaultStrengthLevelExt();
    setTorchStrengthLevelExt(enabled ? strength : 0, enabled);
}
