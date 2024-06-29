#include <Adafruit_NeoPixel.h>
#define PIN 6
#define NUMPIXELS 512
#define NUMBYTES NUMPIXELS * 3

Adafruit_NeoPixel pixels(NUMPIXELS, PIN, NEO_GRB + NEO_KHZ800);

byte pixelBuffer[3];
uint32_t byteStep = 0;

void setup() {
  Serial.begin(115200);
  pixels.begin();
  splash();
}

void loop() {
  if (byteStep >= NUMBYTES) {
    byteStep = 0;
    pixels.show();
  }
  if (Serial.available() > 0) {
    pixelBuffer[byteStep % 3] = Serial.read();
    if ((++byteStep) % 3 == 0) {
      pixels.setPixelColor(byteStep / 3 - 1, pixels.gamma32(pixels.Color(pixelBuffer[0], pixelBuffer[1], pixelBuffer[2])));
    }
  }
}

void splash() {
  for (int i = 0; i < 512; ++i) {
    pixels.setPixelColor(i, pixels.gamma32(pixels.Color(48, 32, 0)));
  }
  pixels.show();
}