# ESP32 STB Image (Lightweight)

A lightweight PlatformIO package for [stb_image.h](https://github.com/nothings/stb/blob/master/stb_image.h) and [stb_image_write.h](https://github.com/nothings/stb/blob/master/stb_image_write.h).

## Why this exists

The full `stb` repository contains test files and dependencies (like `tm.h`) that cause build failures when included directly in ESP32 PlatformIO projects. This repository hosts *only* the necessary header files, ensuring a clean build.

This library was created for **[LTDev-LLC/inky-renderer](https://github.com/LTDev-LLC/inky-renderer)** to enable **Inkplate** devices to display images from arbitrary APIs.

## The Problem: Progressive JPEGs on Inkplate

Most ESP32 E-Ink libraries (like the Inkplate Arduino library) typically rely on hardware-optimized decoders (like `TJpgDec`) that **only support Baseline JPEGs**.

However, many modern web APIs (Unsplash, etc.) serve **Progressive JPEGs** by default. Attempting to render these directly on an Inkplate usually results in a blank screen or a decoding error.

## The Solution

This library allows you to:
1. **Decode** the incoming Progressive JPEG (or PNG/BMP) into raw RGB/Grayscale pixel data using `stb_image`.
2. **Re-encode** that raw data into a **Baseline JPEG** using `stb_image_write`.
3. Pass the new Baseline JPEG to the Inkplate's native renderer.

## Installation

Add this repository to your `platformio.ini`:

```ini
lib_deps =
    https://github.com/LTDev-LLC/esp32-stb-image.git

```

## Usage Example: Converting Progressive to Baseline

The following example demonstrates how to convert a downloaded image buffer into a format safe for the Inkplate.

**Crucial Note:** This operation is memory-intensive. You **must** use an ESP32 with PSRAM (like the Inkplate 10 or 6COLOR) and configure `stb` to use `ps_malloc`.

```cpp
#include <Arduino.h>
#include <vector>

// Configure STB to use PSRAM (Essential for large E-Ink resolutions)
#define STBI_MALLOC ps_malloc
#define STBI_REALLOC ps_realloc
#define STBI_FREE free
#define STBI_NO_STDIO // We use memory buffers, not files

// Implement the libraries
#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

// Helper: Callback for stbi_write to append to a std::vector
void stbiWriteFunc(void *context, void *data, int size) {
    auto *vec = static_cast<std::vector<uint8_t> *>(context);
    const auto *bytes = static_cast<const uint8_t *>(data);
    vec->insert(vec->end(), bytes, bytes + size);
}

/**
 * Converts any STB-supported image (Progressive JPEG, PNG, etc.) to a Baseline JPEG.
 * * @param source The input image buffer (passed by value to allow clearing early)
 * @return std::vector<uint8_t> The new Baseline JPEG buffer
 */
std::vector<uint8_t> convertToBaseline(std::vector<uint8_t> source) {
    int w, h, c;

    // Optimize: Inkplate 6COLOR needs 3 channels (RGB), standard Inkplate needs 1 (Gray).
    // Using 1 channel saves ~66% of RAM during decoding.
    #if defined(ARDUINO_INKPLATECOLOR)
        const int channels = 3;
    #else
        const int channels = 1;
    #endif

    // Decode: stbi_load handles Progressive JPEGs natively
    unsigned char *imgData = stbi_load_from_memory(
        source.data(), source.size(), &w, &h, &c, channels);

    if (!imgData) {
        Serial.printf("STB Decode Failed: %s\n", stbi_failure_reason());
        return {};
    }

    // Free Input: Release source memory immediately to make room for the encoder
    source.clear();
    source.shrink_to_fit();

    // Encode: Write back to a buffer as a standard Baseline JPEG
    std::vector<uint8_t> output;
    if (psramFound()) {
        output.reserve((w * h * channels) / 4); // Estimate output size
    }

    // Quality 85 is a good balance for E-Ink
    int result = stbi_write_jpg_to_func(stbiWriteFunc, &output, w, h, channels, imgData, 85);

    // Free the raw pixel data
    free(imgData);

    if (!result) {
        Serial.println("STB Encode Failed");
        return {};
    }

    return output;
}
```

## Credits
* **Original Libraries**: [stb](https://github.com/nothings/stb) by Sean Barrett (Public Domain).
* **Packaged For**: [LTDev-LLC/inky-renderer](https://github.com/LTDev-LLC/inky-renderer).