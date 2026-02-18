# ESP32 Firmware Update Guide for iOS Background Support

To enable **reliable** background wake-up on iOS, the door hardware (ESP32) must act as a **connectable peripheral** that advertises a specific **Service UUID**.

Currently, your devices filter based on `Manufacturer Data (0x5054)`. iOS **does NOT** support waking up apps in the background based *only* on Manufacturer Data. It requires a **Service UUID**.

## Required Firmware Changes

You need to modify the BLE advertising packet in your ESP32 firmware code.

### 1. Generate a Unique Service UUID
You need a custom 128-bit UUID.
**Example UUID:** `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
*(You can generate your own using `uuidgen` or an online tool)*

### 2. Update Advertisement Data (C++ / Arduino Example)

If you are using the standard `BLEDevice` library on ESP32:

```cpp
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// 1. Define the Service UUID (MUST match the one in Flutter app)
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
// Keep your existing Politek Manufacturer ID (0x5054)
#define MANUFACTURER_ID     0x5054

// ... inside your setup() or initBLE() function ...

void initBLE() {
  BLEDevice::init("Politek Door");
  BLEServer *pServer = BLEDevice::createServer();
  
  // Create Service
  BLEService *pService = pServer->createService(SERVICE_UUID);
  pService->start();

  // Setup Advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  
  // CRITICAL STEP 1: Add Service UUID to Advertisement
  // This tells iOS: "Hey, I am the device you are looking for!"
  pAdvertising->addServiceUUID(SERVICE_UUID);

  // CRITICAL STEP 2: Keep Manufacturer Data (for your existing logic)
  // Example data: 0x50 0x54 + Random Password ...
  std::string mfgData = "";
  char header[2] = {0x50, 0x54};
  mfgData += std::string(header, 2); 
  // ... add your existing password/random logic here ...
  
  BLEAdvertisementData oAdvertisementData = BLEAdvertisementData();
  oAdvertisementData.setManufacturerData(mfgData);
  
  // Important: If data is too long, you might need to put ServiceUUID 
  // in the "Scan Response" packet instead of the main "Advertisement" packet.
  // But iOS prefers it in the main packet for fastest wake-up.
  
  pAdvertising->setAdvertisementData(oAdvertisementData);
  
  // If you split data, use setScanResponseData for the manufacturer data
  // pAdvertising->setScanResponseData(oScanResponseData); 

  pAdvertising->start();
}
```

### 3. Key Technical Constraints and Solution: "Scan Response"
BLE advertising packets are limited to **31 bytes**.

*   **Problem:** 128-bit Service UUID (16 bytes + 2 header) + Manufacturer Data (Header + Password + Name > 15 bytes) **cannot fit in a single packet**.

*   **Required Solution: Split the Data**
    You must use the **Scan Response** feature to split the payload into two packets:

    1.  **Primary Advertisement Packet (31 Bytes):**
        *   Contains **ONLY** the Service UUID (plus mandatory flags).
        *   **Purpose:** Wakes up the iOS app from background.

    2.  **Scan Response Packet (31 Bytes):**
        *   Contains the **Manufacturer Data** (0x5054 + Password + Name).
        *   **Purpose:** Delivers the payload to the app after wake-up.

    The app will first see the UUID, wake up, and then automatically request the Scan Response to get the rest of the data. This is standard BLE behavior.

    **Code Example Update:**
    ```cpp
    // 1. Set Primary Advertisement Data (Service UUID ONLY)
    BLEAdvertisementData oAdvertisementData = BLEAdvertisementData();
    oAdvertisementData.setFlags(0x04); // BR_EDR_NOT_SUPPORTED
    oAdvertisementData.setCompleteServices(BLEUUID(SERVICE_UUID)); 
    pAdvertising->setAdvertisementData(oAdvertisementData);

    // 2. Set Scan Response Data (Manufacturer Data)
    BLEAdvertisementData oScanResponseData = BLEAdvertisementData();
    // Re-construct your existing manufacturer data logic here
    std::string mfgData = "";
    char header[2] = {0x50, 0x54};
    mfgData += std::string(header, 2); 
    // ... add password and name ...
    oScanResponseData.setManufacturerData(mfgData);
    
    pAdvertising->setScanResponseData(oScanResponseData); 
    ```

## Flutter App Changes (Once Firmware is Updated)

After updating the firmware, we need to update `BleManager.dart`:

```dart
// 1. Define the Service UUID
final Uuid _doorServiceUuid = Uuid.parse("4fafc201-1fb5-459e-8fcc-c5c9c331914b");

## Impact on Mobile App (Android & iOS)

You might be wondering: *"Will splitting the data break my current app logic?"*
**Answer: NO.**

Here is why:

### 1. Automatic Packet Merging
Both **iOS (CoreBluetooth)** and **Android (BluetoothLeScanner)** automatically "stitch" the **Advertisement Packet** and **Scan Response Packet** together before giving the data to the Flutter app.

*   When your Flutter code receives a `DiscoveredDevice`:
    *   `device.serviceUuids` will come from **Packet 1**.
    *   `device.manufacturerData` will come from **Packet 2**.
*   **Result:** The Flutter app sees a **single device** with ALL the data combined. Your existing password parsing logic (`extractPassword`, etc.) will continue to work EXACTLY as it does now.

### 2. Foreground Behavior (iOS & Android)
*   **No Change.** The app will scan, see the device, request the Scan Response (automatically handled by OS), and present the data.

### 3. Background Behavior
*   **iOS Background:**
    *   **Before:** App slept and ignored the device.
    *   **After:** iOS sees the **Service UUID** in Packet 1 -> **Wakes App** -> App requests Packet 2 -> App gets Manufacturer Data -> App opens door.
*   **Android Background:**
    *   **Before:** App scanned periodically.
    *   **After:** App can now use **Hardware Filtering** (filtering by Service UUID in the Bluetooth chip). This saves huge amounts of battery on Android because the main CPU doesn't need to wake up for every random BLE device, only for yours.

### Summary
This change is **purely beneficial**. It enables iOS background support and improves Android battery efficiency, without requiring complex changes to your existing data parsing logic.

## Summary for Firmware Engineer
> "Please modify the BLE Advertisement to include a specific 128-bit Service UUID. If the payload is too large, move the Manufacturer Data (0x5054...) to the Scan Response packet, but ensure the Service UUID remains in the primary Advertisement Packet."
