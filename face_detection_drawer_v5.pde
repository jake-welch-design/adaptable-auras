// FACE DETECTION DATA TO PLOTTER INTERFACE
// JAKEWELCH.DESIGIN
// VERSION 5

import ml.*;
import processing.video.*;
import java.awt.*;
import processing.serial.*;

// Global variables
FaceDetector detector;
Capture cam;
Serial myPort;
PGraphics feed, data;
PFont font;
String[] cameras = Capture.list();
int cameraSelect = 0;
int frames = 30;
String portName = "/dev/cu.usbmodem142201";
boolean isOkReceived = false;
boolean isGrblInitialized = false;
color bg = 0;
color primary = color(255, 0, 0);
color circleSize = 50;
float speed = 2000;
float boundaryX = 260;  // in mm
float boundaryY = 190;  // in mm
ArrayList<String> serialMessages = new ArrayList<String>();

void sendInitGcode() {
  if (isGrblInitialized) {
    String[] commands = {
      "$X", "G10 P0 L20 X0 Y0 Z0", "G90", "G21", "G17", "G94", "M3S0",
      "G0Z5", "G0X2Y4.005", "G0Z0", "G1F400X2Y4.005Z-0", "G1F1000X2Y4.005Z-0",
      "G1X2Y25.1Z-0", "G1X5.084Y25.1Z-0"
    };
    for (String command : commands) {
      sendCommand(command);
      delay(1000);
    }
  }
}

void serialEvent(Serial p) {
  String data = p.readStringUntil('\n');
  if (data != null) {
    data = data.trim();
    logMessage("Received: " + data);
    myPort.clear();
    if (data.equals("ok")) {
      println("Received OK");
      isOkReceived = true;
    } else if (data.startsWith("error")) {
      println("Received Error: " + data);
    } else if (data.contains("[MSG:'$H'|'$X' to unlock]")) {
      delay(500);
      isGrblInitialized = true;
      sendInitGcode();
    }
  }
}

void logMessage(String message) {
  serialMessages.add(message);
  if (serialMessages.size() > 50) {
    serialMessages.remove(0);
  }
}

void displaySerialMessages() {
  fill(255, 0, 0);  // Set text color
  textAlign(RIGHT, BOTTOM);
  textFont(font, 12);
  float lineHeight = 14;  // Height of each line of text
  float yPos = height - 10;  // Start from the bottom of the screen, with a small margin

  // Calculate the maximum number of messages that can fit on the screen
  int maxMessages = int(height / lineHeight) - 1;

  // Limit the size of the serialMessages list to maxMessages
  while (serialMessages.size() > maxMessages) {
    serialMessages.remove(0);
  }

  // Display the messages
  for (int i = serialMessages.size() - 1; i >= 0; i--) {
    String msg = serialMessages.get(i);
    text(msg, width - 10, yPos);
    yPos -= lineHeight;  // Move up for the next message
  }
}


void sendCommand(String command) {
  myPort.write(command + "\n");
  logMessage("Sent: " + command);
}

void setup() {
  fullScreen();
  noCursor();
  frameRate(frames);
  font = createFont("IBMPlexMono-Text.ttf", 24);
  feed = createGraphics(width / 2, width / 2);
  data = createGraphics(width / 2, width / 2);
  println("Available Cameras: ");
  printArray(cameras);
  cam = new Capture(this, width, height, cameras[cameraSelect]);
  cam.start();
  detector = new FaceDetector(this);
  myPort = new Serial(this, portName, 115200);
  myPort.write("\r\n\r\n");
  delay(2000);
  myPort.bufferUntil('\n');
}

void draw() {
  background(bg);
  if (cam.available()) {
    cam.read();
  }
  MLFace[] faces = detector.predict(cam);
  float newWidth = feed.height * (cam.width / (float) cam.height);
  float xOffset = (feed.width - newWidth) / 2.0;
  float scaleX = newWidth / cam.width;
  float scaleY = (float) feed.height / cam.height;
  drawFeed(faces, xOffset, scaleX, scaleY);
  drawData(faces, xOffset, scaleX, scaleY);
  image(feed, 0, (height - (width / 2)) / 2, width / 2, width / 2);
  image(data, width / 2, (height - (width / 2)) / 2, width / 2, width / 2);
  //displaySerialMessages();
}

void drawFeed(MLFace[] faces, float xOffset, float scaleX, float scaleY) {
  feed.beginDraw();
  float newWidth = feed.height * (cam.width / (float) cam.height);
  feed.image(cam, xOffset, 0, newWidth, feed.height);
  feed.noFill();
  feed.stroke(0);
  feed.rect(0, 0, feed.width - 1, feed.height - 1);
  feed.filter(GRAY);
  for (MLFace face : faces) {
    float x = (face.getX() * scaleX) + xOffset;
    float y = face.getY() * scaleY;
    float w = face.getWidth() * scaleX;
    float h = face.getHeight() * scaleY;
    feed.stroke(primary); // Use the primary color for the rectangle
    feed.noFill();
    feed.rect(x, y, w, h);
  }
  feed.endDraw();
}

void drawData(MLFace[] faces, float xOffset, float scaleX, float scaleY) {
  data.beginDraw();
  data.background(255);
  data.noFill();
  data.stroke(0);
  data.rect(0, 0, data.width - 1, data.height - 1);
  for (MLFace face : faces) {
    float centerX = (face.getX() * scaleX) + xOffset + (face.getWidth() * scaleX) / 2;
    float centerY = (face.getY() * scaleY) + (face.getHeight() * scaleY) / 2;
    float mappedCenterX = map(centerX, 0, data.width, 0, boundaryX);
    float mappedCenterY = map(data.height - centerY, 0, data.height, 0, boundaryY);
    if (mappedCenterX >= 0 && mappedCenterX <= boundaryX && mappedCenterY >= 0 && mappedCenterY <= boundaryY) {
      String formattedX = nf(mappedCenterX, 0, 3);
      String formattedY = nf(mappedCenterY, 0, 3);
      if (isOkReceived && isGrblInitialized) {
        sendCommand("M3 S255");  // Pen down
      String serialData = "G1X" + formattedX + "Y" + formattedY + "F" + speed + "\n";
        sendCommand(serialData);
        isOkReceived = false;
      }
      data.fill(primary);
      data.noStroke();
      data.ellipse(centerX, centerY, circleSize, circleSize);
      data.textAlign(CENTER, CENTER);
      data.text("X: " + formattedX + "\n" + "Y: " + formattedY, centerX, centerY - 50);
    } else {
      println("Coordinates out of bounds: X=" + mappedCenterX + ", Y=" + mappedCenterY);
      println("Machine paused. Waiting for valid coordinates...");
    }
  }
  data.endDraw();
}

void keyPressed() {
  if (key == 'x' || key == 'X') {
    sendCommand("M5");  // Pen up
    myPort.write(0x18);  // ASCII control character for soft reset
    println(">>> Sent soft reset command.");
    delay(1000);
    exit();
  }
}

void exit() {
  myPort.stop();
  super.exit();
}
