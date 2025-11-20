import oscP5.*;
import netP5.*;

Table cars;
int totalRows;

float[] timePos;      
int[] brandIndex;     
float[] priceNorm;    
float[] engineNorm;   
float[] mileageNorm;  
float[] yearNorm;     
float[] hitGlow;      

float minPrice, maxPrice;
float minEngine, maxEngine;
float minMileage, maxMileage;
float minYear, maxYear;

OscP5 osc;
NetAddress pd;

float playhead = 0.0;        
float prevPlayhead = 0.0;
float bpm = 110;             
boolean playing = true;

int lastMillis;


boolean[] muteBrand = new boolean[7];  

void setup() {
  size(1200, 700);
  smooth();
  colorMode(HSB, 360, 100, 100, 100);
  textAlign(LEFT, TOP);
  textSize(12);

  cars = loadTable("car_price_prediction_.csv", "header");
  if (cars == null) {
    println("No se pudo cargar car_price_prediction_.csv");
    exit();
  }


  cars.sort("Year");

  totalRows   = cars.getRowCount();
  timePos     = new float[totalRows];
  brandIndex  = new int[totalRows];
  priceNorm   = new float[totalRows];
  engineNorm  = new float[totalRows];
  mileageNorm = new float[totalRows];
  yearNorm    = new float[totalRows];
  hitGlow     = new float[totalRows];

  computeRanges();
  preprocessRows();

  // OSC
  osc = new OscP5(this, 12000);             
  pd  = new NetAddress("127.0.0.1", 8000);  

  lastMillis = millis();

  sendBpmToPD();
}

void draw() {
  background(0);

  int marginTop    = 80;
  int marginBottom = 80;
  int marginLeft   = 80;
  int marginRight  = 60;

 
  updatePlayhead();


  drawBrandLanes(marginLeft, marginRight, marginTop, marginBottom);

  
  drawHits(marginLeft, marginRight, marginTop, marginBottom);


  drawPlayhead(marginLeft, marginRight, marginTop, marginBottom);

  drawHUD();
}

void computeRanges() {
  minPrice   =  Float.MAX_VALUE;
  maxPrice   = -Float.MAX_VALUE;
  minEngine  =  Float.MAX_VALUE;
  maxEngine  = -Float.MAX_VALUE;
  minMileage =  Float.MAX_VALUE;
  maxMileage = -Float.MAX_VALUE;
  minYear    =  Float.MAX_VALUE;
  maxYear    = -Float.MAX_VALUE;

  for (TableRow row : cars.rows()) {
    float price   = row.getFloat("Price");
    float engine  = row.getFloat("Engine Size");
    float mileage = row.getFloat("Mileage");
    float year    = row.getFloat("Year");

    if (price   < minPrice)   minPrice   = price;
    if (price   > maxPrice)   maxPrice   = price;
    if (engine  < minEngine)  minEngine  = engine;
    if (engine  > maxEngine)  maxEngine  = engine;
    if (mileage < minMileage) minMileage = mileage;
    if (mileage > maxMileage) maxMileage = mileage;
    if (year    < minYear)    minYear    = year;
    if (year    > maxYear)    maxYear    = year;
  }
}


float norm1(float v, float vmin, float vmax) {
  if (vmax == vmin) return 0.0;
  return (v - vmin) / (vmax - vmin);
}

int brandToIndex(String brand) {
  if (brand.equals("Tesla"))    return 0;
  if (brand.equals("BMW"))      return 1;
  if (brand.equals("Audi"))     return 2;
  if (brand.equals("Ford"))     return 3;
  if (brand.equals("Honda"))    return 4;
  if (brand.equals("Mercedes")) return 5;
  if (brand.equals("Toyota"))   return 6;
  return 0;
}

String indexToBrand(int idx) {
  switch(idx) {
  case 0: return "Tesla";
  case 1: return "BMW";
  case 2: return "Audi";
  case 3: return "Ford";
  case 4: return "Honda";
  case 5: return "Mercedes";
  case 6: return "Toyota";
  }
  return "?";
}

void preprocessRows() {
  int i = 0;
  for (TableRow row : cars.rows()) {
    // tiempo distribuido a lo largo del loop según posición en la tabla
    timePos[i] = (totalRows == 1) ? 0.0 : i / float(totalRows - 1);

    float price   = row.getFloat("Price");
    float engine  = row.getFloat("Engine Size");
    float mileage = row.getFloat("Mileage");
    float year    = row.getFloat("Year");
    String brand  = row.getString("Brand");

    brandIndex[i]  = brandToIndex(brand);
    priceNorm[i]   = norm1(price,   minPrice,  maxPrice);
    engineNorm[i]  = norm1(engine,  minEngine, maxEngine);
    mileageNorm[i] = norm1(mileage, minMileage, maxMileage);
    yearNorm[i]    = norm1(year,    minYear,   maxYear);
    hitGlow[i]     = 0;

    i++;
  }
}


void updatePlayhead() {
  int now = millis();
  float dt = (now - lastMillis) / 1000.0; // segundos desde el frame anterior
  lastMillis = now;

  prevPlayhead = playhead;

  if (playing) {
    float beatsPerSec = bpm / 60.0;
    float loopsPerSec = beatsPerSec / 4.0;  // asumiendo loop de 4 tiempos
    playhead += loopsPerSec * dt;
  }

  if (playhead >= 1.0) playhead -= 1.0;
  if (playhead < 0.0)  playhead += 1.0;

  triggerHitsBetween(prevPlayhead, playhead);

  for (int i = 0; i < totalRows; i++) {
    hitGlow[i] *= 0.90; // decay suave
  }
}

void triggerHitsBetween(float startPos, float endPos) {
  if (startPos <= endPos) {
    // caso normal: avance sin wrap
    for (int i = 0; i < totalRows; i++) {
      float t = timePos[i];
      if (t >= startPos && t < endPos && !muteBrand[brandIndex[i]]) {
        hitGlow[i] = 1.0;
        sendHitToPD(i);
      }
    }
  } else {
    // caso wrap: el playhead pasó de ~0.98 a ~0.02
    for (int i = 0; i < totalRows; i++) {
      float t = timePos[i];
      if ((t >= startPos || t < endPos) && !muteBrand[brandIndex[i]]) {
        hitGlow[i] = 1.0;
        sendHitToPD(i);
      }
    }
  }
}

void drawBrandLanes(int marginLeft, int marginRight, int marginTop, int marginBottom) {
  stroke(0, 0, 50, 60);
  strokeWeight(1);
  fill(0, 0, 100);

  int lanes = 7;
  float usableHeight = height - marginTop - marginBottom;
  float laneH = usableHeight / lanes;

  for (int b = 0; b < lanes; b++) {
    float y = marginTop + laneH * (b + 0.5);

    // línea base de la pista
    stroke(0, 0, 40, 70);
    line(marginLeft, y, width - marginRight, y);

    // nombre de la marca + estado mute
    String label = indexToBrand(b);
    if (muteBrand[b]) label += " (MUTE)";
    fill(0, 0, 80);
    textAlign(LEFT, CENTER);
    text(label, 10, y);
  }

  // marco del área de timeline
  noFill();
  stroke(0, 0, 80, 80);
  rectMode(CORNERS);
  rect(marginLeft, marginTop, width - marginRight, height - marginBottom);
}

void drawHits(int marginLeft, int marginRight, int marginTop, int marginBottom) {
  int lanes = 7;
  float usableHeight = height - marginTop - marginBottom;
  float laneH = usableHeight / lanes;

  for (int i = 0; i < totalRows; i++) {
    int b = brandIndex[i];
    float t = timePos[i];

    float laneCenterY = marginTop + laneH * (b + 0.5);

    float x = map(t, 0, 1, marginLeft, width - marginRight);

    float jitter = map(yearNorm[i], 0, 1, -laneH * 0.2, laneH * 0.2);
    float y = laneCenterY + jitter;

    float hue = lerp(220, 20, yearNorm[i]);       
    float sat = 40 + 60 * engineNorm[i];          
    float bri = 30 + 70 * (1.0 - mileageNorm[i]); 

    float baseSize = 6 + 18 * priceNorm[i];       
    float glow = hitGlow[i];                      
    float size = baseSize * (1.0 + 0.6 * glow);

    noStroke();
    // halo
    if (glow > 0.01) {
      fill(hue, sat, bri, 30);
      ellipse(x, y, size * 1.8, size * 1.8);
    }
    // núcleo
    fill(hue, sat, bri, muteBrand[b] ? 30 : 90);
    ellipse(x, y, size, size);
  }
}

void drawPlayhead(int marginLeft, int marginRight, int marginTop, int marginBottom) {
  float x = map(playhead, 0, 1, marginLeft, width - marginRight);
  stroke(200, 0, 100, 90);
  strokeWeight(2);
  line(x, marginTop, x, height - marginBottom);
}

void drawHUD() {
  fill(0, 0, 100);
  textAlign(LEFT, TOP);
  String s = "";
  s += "Car Groove Sequencer\n";
  s += "SPACE: Play/Pause   |   ↑/↓: BPM +/-   |   1..7: mute/unmute marcas   |   R: reset loop\n";
  s += "BPM: " + nf(bpm, 0, 1) + "   |   Playhead: " + nf(playhead, 0, 3) + "\n";
  s += "Playing: " + playing + "\n";
  text(s, 10, 10);
}


void sendHitToPD(int i) {
  OscMessage m = new OscMessage("/hit");
  m.add(brandIndex[i]);   // 0..6
  m.add(timePos[i]);      // posición en el loop 0..1
  m.add(priceNorm[i]);
  m.add(engineNorm[i]);
  m.add(mileageNorm[i]);
  m.add(yearNorm[i]);
  osc.send(m, pd);
}

void sendBpmToPD() {
  OscMessage m = new OscMessage("/bpm");
  m.add(bpm);
  osc.send(m, pd);
}


void keyPressed() {
  // Barra espaciadora: play / pause
  if (key == ' ') {
    playing = !playing;
  }

  // R / r: reset del loop
  else if (key == 'r' || key == 'R') {
    playhead = 0;
    prevPlayhead = 0;
  }

  // Teclas especiales (flechas, F1, etc.)
  else if (key == CODED) {
    if (keyCode == UP) {
      bpm += 5;
      sendBpmToPD();
    } else if (keyCode == DOWN) {
      bpm = max(20, bpm - 5);
      sendBpmToPD();
    }
  }

  // 1..7: mute / unmute de cada marca
  else if (key >= '1' && key <= '7') {
    int idx = key - '1';      // '1'->0, '2'->1...
    if (idx >= 0 && idx < 7) {
      muteBrand[idx] = !muteBrand[idx];
    }
  }
}
