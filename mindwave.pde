// Sample sketch to illustrate MindWave support in Processing

// for graphing
import processing.serial.*;

eegPort eeg;
Serial serialPort;
String portName;
PFont font;
String portNames[];

// Application state
final int APP_SERIAL_SELECT = 1;
final int APP_CONNECTING = 2;
final int APP_CONNECTED = 3;

int appState = APP_SERIAL_SELECT;
int selected = -1;

int width = 800, height = 600;

void setup() {
  size(width, height);
  font = loadFont("HelveticaNeue-20.vlw");
  textFont(font);
  
  portNames = Serial.list();
  for (int i = 0; i < portNames.length; i++) {
    println(portNames[i]);
  }
  
  smooth();
}

void draw() {
  switch (appState) {
    case APP_SERIAL_SELECT:
      drawSerialSelect();
      break;
    case APP_CONNECTING:
      drawConnecting();
      break;
    case APP_CONNECTED:
      drawConnected();
      break;
  }
}

// Drawing when we're connected
void drawConnected() {
  int lastEventInterval = millis() - eeg.lastEvent;
  
  background(255);
  
  if (mousePressed) {
    eeg.refresh();
  }
  
  textAlign(LEFT);
  fill(0);
  text("Port: " + portName, 5, 20);
  text("Dongle state: " + eeg.portDongleState, 5, 40);
  text("Poor signal: " + eeg.poorSignal, 5, 60);
  text("Attention: " + eeg.attention, 5, 80);
  text("Meditation: " + eeg.meditation, 5, 100);
  text("Last event: " + lastEventInterval + " ms ago", 5, 120);
  text("Raw buffer size: " + eeg.rawDataBuffer.size(), 5, 140);
  text("Raw data sequence: " + eeg.rawSequence, 5, 160);
  text("Vector sequence: " + eeg.vectorSequence, 5, 180);
  text("Vector buffer size: " + eeg.vectorBuffer.size(), 5, 200);
  text("Serial read state: " + eeg.portReadState, 5, 220);
  text("Failed checksum count: " + eeg.failedChecksumCount, 5, 240);
  text("Click mouse for a second to reset", 5, 260);
  
  // Draw signal
  noStroke();
  if (eeg.poorSignal < 50 && lastEventInterval < 500) {
    // good signal
    fill(0, 255, 0);
    ellipse(150, 320, 100, 100);
  } else {
    // bad signal
    fill(255, 0, 0);
    ellipse(150, 320, 100, 100);
  }
  
  textAlign(CENTER);
  fill(0);
  text("Attention", 400, 20);
  text("Meditation", 600, 20);
  
  if (eeg.lastAttention > 0) {
    text(millis() - eeg.lastAttention + " ms old", 400, 180);
  }

  if (eeg.lastMeditation > 0) {
    text(millis() - eeg.lastMeditation + " ms old", 600, 180);
  }

  // Draw attention
  noFill();
  stroke(0);
  ellipse(400, 90, 127, 127);
  fill(204, 102, 0);
  noStroke();
  ellipse(400, 90, eeg.attention, eeg.attention);
  
  
  // Draw meditation
  noFill();
  stroke(0);
  ellipse(600, 90, 127, 127);
  fill(108, 102, 240);
  noStroke();
  ellipse(600, 90, eeg.meditation, eeg.meditation);
  
  // Draw signal
  
  
  // Chart vector values
  // first get maximum value
  int maxValue = 0;
  Iterator<eegPort.vectorObs> iterator;
  iterator = eeg.vectorBuffer.iterator();
  int vectorCount = eeg.vectorBuffer.size();

  int skip = 0;
  if (vectorCount > 200) {
    skip = vectorCount - 200;
  }
  
  int i = -1;
  
  while (iterator.hasNext()) {
    eegPort.vectorObs vobs = iterator.next();
    if (++i < skip) {
      continue;
    }
    
    if (vobs.vectorValue > maxValue) {
      maxValue = vobs.vectorValue;
    }
  }
  
  iterator = eeg.vectorBuffer.iterator();

  // we are interested in the last 400 observations
  
  i = -1;
  int j = 0;
  int prevValue = 0;
  int x = 0, y = 0;
  int prevX = 0, prevY = 0;
  
  stroke(0);
  
  // we are drawing between 0 and 800 in width, and between 400 and 600 in height
  while (iterator.hasNext()) {
    eegPort.vectorObs vobs = iterator.next();
    if (++i < skip) {
      continue;
    }
    
    x = j*4;
    y = (int)(580 - 200.0*vobs.vectorValue/maxValue);
    if (j > 0) {
      line(prevX, prevY, x, y);
    }
    
    prevValue = vobs.vectorValue;
    prevX = x;
    prevY = y;
    j++;
  }
  
  // chart attention
  int attentionCount = eeg.attentionBuffer.size();

  skip = 0;
  if (attentionCount > 200) {
    skip = attentionCount - 200;
  }
  
  Iterator<Integer> attentionIterator = eeg.attentionBuffer.iterator();

  // we are interested in the last 200 observations
  
  i = -1;
  j = 0;
  prevValue = 0;
  x = 0; y = 0;
  prevX = 0; prevY = 0;
  
  stroke(204, 102, 0);
  
  // we are drawing between 0 and 800 in width, and between 400 and 600 in height
  while (attentionIterator.hasNext()) {
    int attention = attentionIterator.next();
    if (++i < skip) {
      continue;
    }
    
    x = j*4;
    y = (int)(580 - 200.0*attention/255);
    if (j > 0) {
      line(prevX, prevY, x, y);
    }
    
    prevValue = attention;
    prevX = x;
    prevY = y;
    j++;
  }

  // chart meditation
  int meditationCount = eeg.meditationBuffer.size();

  skip = 0;
  if (meditationCount > 200) {
    skip = meditationCount - 200;
  }
  
  Iterator<Integer> meditationIterator = eeg.meditationBuffer.iterator();

  // we are interested in the last 200 observations
  
  i = -1;
  j = 0;
  prevValue = 0;
  x = 0; y = 0;
  prevX = 0; prevY = 0;
  
  stroke(108, 102, 240);
  
  // we are drawing between 0 and 800 in width, and between 400 and 600 in height
  while (meditationIterator.hasNext()) {
    int meditation = meditationIterator.next();
    if (++i < skip) {
      continue;
    }
    
    x = j*4;
    y = (int)(580 - 200.0*meditation/255);
    if (j > 0) {
      line(prevX, prevY, x, y);
    }
    
    prevValue = meditation;
    prevX = x;
    prevY = y;
    j++;
  }
}

void drawConnecting() {
  background(255);
  
  text("Connecting to " + portName + ", please wait…", 5, 20);
}

// Serial selection
void drawSerialSelect() {
  background(255);
  
  int hover = (int)Math.round(Math.floor(mouseY/20));
  
  if (mousePressed) {
    selected = hover;
  }
  
  for (int i = 0; i < portNames.length; i++) {
    if (i == selected) {
      fill(0);
      rect(0, i*20, width, 20);
      fill(255);
      
      portName = portNames[i];
      println("selected " + portName);
      serialPort = new Serial(this, portName, 115200);
      appState = APP_CONNECTING;
      eeg = new eegPort(this, serialPort);
      delay(500);
      eeg.refresh();
    } else if (i == hover) {
      fill(200, 200, 240);
      noStroke();
      rect(0, i*20, width, 20);
      fill(0);
    } else {
      fill(0);
    }
    text(portNames[i], 5, (i+1)*20);
  }
}

void serialEvent(Serial p) {
  while (p.available() > 0) {
    int inByte = p.read();
    eeg.serialByte(inByte);
    if (inByte == 170 && appState < APP_CONNECTED) {
      println("Connected");
      appState = APP_CONNECTED;
      frameRate(10);
    }
  }
}

