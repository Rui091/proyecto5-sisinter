# Car Groove Sequencer – Audio-Visual Sonification of a Car Dataset
# Autores: Rui Yu Lei Wu y Juan David Bernal

*Video*: [https://www.youtube.com/watch?v=JUFd7heKBa4]


This project connects **Processing** and **Pure Data** through **OSC** to transform a real car dataset into an **interactive audiovisual groove engine**.

- **Processing** visualizes the dataset as a timeline-based sequencer and sends OSC messages.
- **Pure Data** receives those OSC events and generates a **generative soundscape**: chords, melodic lines, partials, pulses, FM textures, delays, pads, and stereo spatial effects.

Everything you hear and see is driven by the parameters of real cars.

## 1. Requirements

### Software
- **Processing 4.x**
- Processing libraries:
  - `oscP5`
  - `netP5`
- **Pure Data Vanilla** (0.51 or later)
- A sound output device (headphones recommended)

### Files Included
- `CarGrooveSequencer.pde` → Processing sketch (visual + OSC generator)
- `car_price_prediction_.csv` → dataset (must be placed inside `/data`)
- `car_sonification.pd` → Pure Data patch (sound engine)

## 2. System Architecture

### 2.1 Processing Overview

Processing does the following:

### A. Dataset Processing

The CSV file `car_price_prediction_.csv` is loaded using `loadTable("...", "header")`.

For each car:
- Brand → `brandIndex` (mapped to 0–6)
- Normalized values:
  - `priceNorm`
  - `engineNorm`
  - `mileageNorm`
  - `yearNorm`
- `timePos` determines when the hit occurs in the loop

### B. Visual Sequencer
- 7 lanes (one per car brand)
- A looping vertical playhead
- Each car represented as a circle whose:
  - X = position in loop
  - Y = brand lane
  - Size = price
  - Color hue = year
  - Saturation = engine size
  - Brightness = mileage

### C. OSC communication
Processing sends two kinds of messages:

Hit messages (one per car when playhead crosses):
```
/hit brandIndex timePos priceNorm engineNorm mileageNorm yearNorm
```

Tempo updates:
```
/bpm currentBPM
```

Processing → PD:
- From port: 12000  
- To port: 8000  
- Destination IP: `127.0.0.1` (local machine)

### D. Keyboard Controls

| Key | Action |
|-----|--------|
| SPACE | Play / Pause loop |
| R | Reset playhead |
| ↑ / ↓ | Increase / decrease BPM (sends /bpm to PD) |
| 1–7 | Toggle mute for each brand |

## 2.2 Pure Data Overview (car_sonification.pd)

The Pure Data patch performs:

### A. OSC decoding
```
[netreceive -u -b 8000]
|
[oscparse]
|
[list trim]
|
[route hit]
|
[unpack f f f f f f]
```

You receive:
1. brandIndex
2. timePos
3. priceNorm
4. engineNorm
5. mileageNorm
6. yearNorm

### B. Brand router (0–6)

Each brand index triggers a different sound module:

| Brand Index | Behavior |
|-------------|----------|
| 0 | Generative chords / triads |
| 1 | Percussive tonal blip |
| 2 | Additive partial layer |
| 3 | Harmonic partial |
| 4 | Another partial |
| 5 | Filtered partial |
| 6 | Upper harmonic / FX |

### C. Generative chord engine (brand 0)
Contains random generators, oscillators, band-pass filters, stereo mixing, delay processing, and timing logic.  
Produces evolving multi-note chords based on dataset hits.

### D. Additive synthesis (brands 2–6)
- 5 additive oscillators
- Harmonic multipliers: ×1, ×2, ×3, ×4, ×5
- Independent gains
- Low-pass filtering
- Summed into stereo output

### E. Percussive Pulse (brandIndex = 1)
Simple osc-based percussive blip.

### F. Delay & Mixing Network
Multi-tap delay using:
- delwrite~
- delread~
- lop~
- throw~/catch~ buses

Final audio:
```
catch~ left  → dac~ 1  
catch~ right → dac~ 2
```

## 3. How to Run the Project

### Step 1 — Setup Processing

1. Open Processing.
2. Create a new sketch folder.
3. Place:
   ```
   CarGrooveSequencer.pde
   ```
   inside the folder.
4. Create a folder:
   ```
   data/
   ```
5. Place:
   ```
   car_price_prediction_.csv
   ```
   inside `/data`.
6. Install Processing libraries:
   - oscP5
   - netP5

Do **NOT** run yet.

### Step 2 — Setup Pure Data

1. Open Pure Data.
2. Load:
   ```
   car_sonification.pd
   ```
3. Enable DSP:
   ```
   Media → DSP On
   ```
4. Confirm no errors.

### Step 3 — Run Everything

1. Return to Processing → Press RUN.
2. You will see:
   - The 7 brand lanes
   - Moving playhead
   - Animated circles (cars)
3. Pure Data will begin receiving OSC `/hit` messages.
4. The full generative sound system starts:
   - Chords  
   - Harmonic partials  
   - Percussion  
   - Pads  
   - Delays  
   - Stereo textures  

You are now hearing the sonified car dataset.

## 4. Data → Sound Mapping

| Car Attribute | Influences |
|---------------|------------|
| brandIndex | Which instrument is triggered |
| timePos | Timing & rhythm |
| priceNorm | Amplitude |
| engineNorm | Pitch base |
| mileageNorm | Filter/noise variation |
| yearNorm | Timbre brightness |

## 5. Extensions

- Add FM or granular synthesis.
- Create GUI controls in PD.
- Add OSC feedback PD → Processing.
- Implement rhythmic quantization.
- Allow real-time performance controls.

## 6. Credits

- Processing Visual + OSC Engine: CarGrooveSequencer.pde  
- Pure Data Audio Engine: car_sonification.pd  
- Dataset: car_price_prediction_.csv  


