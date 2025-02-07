# GrowFan
ESP32 Tasmota berry based Automatic fan speed control (hysteresis) based on Humidity and Temperatuere for Inline Duct Fans DF100-A like Vevor, SpiderFarmer, Mars Hydro, Aygrochy that are controlled with PWM Signal.

Tasmota Gui:

<img width="430" alt="Bildschirmfoto 2024-11-05 um 11 49 47" src="https://github.com/user-attachments/assets/d8100166-7f3e-4f48-ad41-4b9412179564">

<img width="573" alt="Bildschirmfoto 2024-11-05 um 11 50 33" src="https://github.com/user-attachments/assets/74fac2a6-6747-404c-ab1a-bf0a5fae64d8">

example for Home Assistant:

<img width="482" alt="Bildschirmfoto 2024-11-05 um 11 56 34" src="https://github.com/user-attachments/assets/dc5285e8-6ef4-42d5-af67-b5b2433b3583">

# Tasmota on ESP32 with SHT3X and Fan Control

## 1. Flash Tasmota to your ESP32  

Follow the standard procedure to flash Tasmota onto your ESP32.

## 2. Connect the SHT3X Sensor  

Wire the SHT3X sensor to the ESP32 as follows:  

| SHT3X Pin | ESP32 Pin |
|-----------|----------|
| SDA       | GPIO (e.g., 21) |
| SCL       | GPIO (e.g., 22) |
| VCC       | 3.3V or 5V |
| GND       | GND |

## 3. Fan Wiring  

### Power  
- Use a **buck converter (5V)** to supply power to the fan.  
- If you **don’t** use a buck converter, **at least connect the fan GND to the ESP32**.  

### PWM Control  
- Identify the **third wire** (responsible for fan speed control).  
- Connect it to the ESP32 (e.g., **GPIO 14**).  

## 4. Tasmota Configuration  

1. Open **Configuration** in Tasmota.  
2. Set the correct **pin numbers** for SDA, SCL, and PWM.  
3. In the dropdown menu, select:  
   - **SDA** (e.g., GPIO 21)  
   - **SCL** (e.g., GPIO 22)  
   - **PWM** (e.g., GPIO 14)  

## 5. Autostart Configuration  

To ensure automatic execution on startup, create a file named **`autoexec.be`** in the **filesystem**, with the following content:  


`load('Growfan.be')`

## ⚠️ Important Note  
Check the **pinout of your ESP32** to ensure that the chosen pins for **SDA, SCL, and PWM** are suitable!
