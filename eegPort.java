// eeg states, indicates the next value we are expecting
import processing.serial.*;
import processing.core.*;
import java.nio.ByteBuffer;
import org.apache.commons.collections.buffer.CircularFifoBuffer;

public class eegPort {
  Serial serialPort;
  
  // Parsing state machine
  // The name describes the data we are currently waiting for
  public static enum readState {
    SYNC1,
    SYNC2,
    LENGTH,
    DATA,
    CHECKSUM
  }

  public static enum dongleState {
    DISCONNECTED,
    STANDBY,
    CONNECTED
  }

// various state variables for display of EEG information
  public int packetLength = 0;
  public int packetCode = 0;
  public int poorSignal = 255;
  public int readIndex = 0;
  public int attention = 0;
  public int meditation = 0;
  public int lastEvent = 0;
  public int lastAttention = 0;
  public int lastMeditation = 0;
  int vectorBytesLeft = 0;
  public dongleState portDongleState = dongleState.DISCONNECTED;
  public readState portReadState = readState.SYNC1;
  
  public int rawSequence = 0;
  public int vectorSequence = 0;
  
  public int failedChecksumCount = 0;
  
  int readBuffer[];
  
  CircularFifoBuffer rawDataBuffer;
  CircularFifoBuffer vectorBuffer;
  CircularFifoBuffer attentionBuffer;
  CircularFifoBuffer meditationBuffer;
  
  // buffer for raw values
  
  PApplet app;
  
  public class rawObs {
    int timestamp;
    int sequence;
    short rawValue;
  }
  
  public class vectorObs {
    int timestamp;
    int sequence;
    int vectorValue;
  }
  
  public eegPort(PApplet applet, Serial serial) {
    app = applet;
    serialPort = serial;
    
    rawDataBuffer = new CircularFifoBuffer(4096);
    vectorBuffer = new CircularFifoBuffer(4096);
    attentionBuffer = new CircularFifoBuffer(3600);
    meditationBuffer = new CircularFifoBuffer(3600);
  }
  
  public void refresh() {
    portReadState = readState.SYNC1;
    serialPort.write((byte)0xc1);
    app.delay(200);
    serialPort.write((byte)0xc2);
  }
  
  int signedByte(int inByte) {
    ByteBuffer bb = ByteBuffer.allocate(4);
    bb.putInt(inByte);
    return bb.get(3);
  }
  
  public void serialByte(int inByte) {
    switch (portReadState) {
      case SYNC1:
        readBuffer = new int[170];
        packetLength = 0;
        readIndex = 0;
        if (inByte == 170) {
          portReadState = readState.SYNC2;
        }
        break;
      case SYNC2:
        if (inByte == 170) {
          portReadState = readState.LENGTH;
        }
        break;
      case LENGTH:
        packetLength = inByte;
        if (packetLength > 169 || packetLength <= 0) {
          portReadState = readState.SYNC1;
        } else {
          readIndex = 0;
          portReadState = readState.DATA;
//          app.println("reading " + bytesLeft + " bytes");
        }
        break;
      case DATA:
        readBuffer[readIndex++] = inByte;
        if (readIndex == packetLength) {
          portReadState = readState.CHECKSUM;
        }
        break;
      case CHECKSUM:
        portReadState = readState.SYNC1;
        // run checksum
        int checksum = 0;
        for (int i = 0; i < packetLength; i++) {
          checksum = (checksum + readBuffer[i])%256;
        }
        if (255 - checksum != inByte) {
//          app.println("checksum fail, calculated " + checksum + ", provided " + inByte +
//              " for length " + packetLength);
          failedChecksumCount++;
        } else if (packetLength > 0) {
          lastEvent = app.millis();
          parse();
        }
        break;
    }
  }
  
  public void parse() {
    int inByte;
    
    for (int i = 0; i < packetLength; i++) {
      switch(readBuffer[i]) {
        case 212:      // standby
          portDongleState = dongleState.STANDBY;
          break;
        case 208:      // connected
          portDongleState = dongleState.CONNECTED;
          break;
        case 2:      // poor signal
          inByte = readBuffer[++i];
          if (inByte == 255 && poorSignal == 0) {
            inByte = 49;
          } else if (inByte < 200 && poorSignal == 200) {
            inByte = 254;
          }
          poorSignal = inByte;
          break;
        case 4:      // attention
          inByte = signedByte(readBuffer[++i]);
          if (inByte > 0) {
            attention = inByte;
          }
        
          lastAttention = app.millis();
          attentionBuffer.add(attention);
          break;
        case 5:      // meditation
          inByte = signedByte(readBuffer[++i]);
          if (inByte > 0) {
            meditation = inByte;
          }
        
          lastMeditation = app.millis();
          meditationBuffer.add(meditation);
          break;
        case 128:      // raw value
          int rawRowLength = readBuffer[++i];
          int rawA = readBuffer[++i];
          int rawB = readBuffer[++i];
          
          ByteBuffer bbA = ByteBuffer.allocate(4);
          bbA.putInt(rawA);
          ByteBuffer bbB = ByteBuffer.allocate(4);
          bbB.putInt(rawB);
        
          ByteBuffer bb = ByteBuffer.allocate(2);
          // value from NeuroSky is little endian, so swap around
          bb.put(1, bbA.get(3));
          bb.put(0, bbB.get(3));
        
          short rawValue = bb.getShort(0);

          rawSequence++;
          rawObs obs = new rawObs();
          obs.sequence = rawSequence;
          obs.timestamp = app.millis();
          obs.rawValue = rawValue;
        
          rawDataBuffer.add(obs);
          break;
        case 131:      // vector
          int vectorLength = readBuffer[++i];
          if (vectorLength != 24) {
            // something wrong
            break;
          }
          
          for (int j = 0; j < 8; j++) {
            int vecA = readBuffer[++i];
            int vecB = readBuffer[++i];
            int vecC = readBuffer[++i];
            vectorObs vobs = new vectorObs();
            vobs.timestamp = app.millis();
            vobs.sequence = ++vectorSequence;
            vobs.vectorValue = vecA*255*255 + vecB*255 + vecC;
            vectorBuffer.add(vobs);
          }
        default:      // unknown
//          app.println("unknown code " + packetCode);
          break;
      }
    }
  }
}

