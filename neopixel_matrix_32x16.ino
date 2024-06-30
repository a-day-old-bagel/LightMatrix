#include <Adafruit_NeoPixel.h>
#define PIN 6
#define NUMPIXELS 512

Adafruit_NeoPixel pixels(NUMPIXELS, PIN, NEO_GRB + NEO_KHZ800);

byte pixelBuffer[3];
uint32_t byteStep = 0;
bool compressedMethod = true;

bool splashAnimate = true;
int x = 11, y = 8, dx = 1, dy = 1;
byte r = 30, g = 30, b = 30, radius = 1;
bool rAsc = true, gAsc = false, bAsc = true;

void setup() {
  Serial.begin(115200);
  pixels.begin();
}

void loop() {
  if (compressedMethod) readCompressed(); else readUncompressed();
  if (splashAnimate) animateBouncingSquare();
}

void readCompressed() {
  if (byteStep >= NUMPIXELS * 2) {
    byteStep = 0;
    pixels.show();
  }
  if (Serial.available() > 0) {
    splashAnimate = false;
    pixelBuffer[byteStep % 2] = Serial.read();
    if ((++byteStep) % 2 == 0) {
      byte red = pixelBuffer[0] & 0b11111000;
      byte green = ((pixelBuffer[0] & 0b00000111) << 5) | ((pixelBuffer[1] & 0b11100000) >> 3);
      byte blue = (pixelBuffer[1] & 0b00011111) << 3;
      pixels.setPixelColor(byteStep / 2 - 1, pixels.gamma32(pixels.Color(red | 0b00000100, green | 0b00000010, blue | 0b00000100)));
    }
  }
}

void readUncompressed() {
  if (byteStep >= NUMPIXELS * 3) {
    byteStep = 0;
    pixels.show();
  }
  if (Serial.available() > 0) {
    splashAnimate = false;
    pixelBuffer[byteStep % 3] = Serial.read();
    if ((++byteStep) % 3 == 0) {
      pixels.setPixelColor(byteStep / 3 - 1, pixels.gamma32(pixels.Color(pixelBuffer[0], pixelBuffer[1], pixelBuffer[2])));
    }
  }
}

void animateBouncingSquare() {
  pixels.clear();
  for (int pen_x = x - radius; pen_x <= x + radius; ++pen_x) {
    for (int pen_y = y - radius; pen_y <= y + radius; ++pen_y) {
      int center = pen_x * 16;
      if (pen_x % 2 == 1) center += 15 - pen_y;
      else center += pen_y;
      pixels.setPixelColor(center, pixels.gamma32(pixels.Color(r, g, b)));
    }
  }
  pixels.show();

  if (r <= 12 || r > 83) rAsc = !rAsc;
  if (g <= 9 || g > 79) gAsc = !gAsc;
  if (b <= 14 || b > 85) bAsc = !bAsc;

  r += 3 * (1 - rAsc * 2);
  g += 2 * (1 - gAsc * 2);
  b += 4 * (1 - bAsc * 2);

  if ((dx > 0 && x >= 31 - radius) || (dx < 0 && x <= radius)) dx *= -1;
  if ((dy > 0 && y >= 15 - radius) || (dy < 0 && y <= radius)) dy *= -1;
  x += dx;
  y += dy;
}
