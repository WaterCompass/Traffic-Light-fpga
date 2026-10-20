// traffic_light.ino
// The same traffic light as the Verilog version, written in C for an Arduino Uno.
// Same 6 states, same pedestrian button rules, same safety checks.
// Blue LEDs are used in place of amber.

// ---- Pins ----
const int N_RED = 2, N_AMB = 3, N_GRN = 4;
const int E_RED = 5, E_AMB = 6, E_GRN = 7;
const int BUTTON   = 8;
const int WALK_LED = 13;   // the Uno's built-in "L" LED

// ---- Times in milliseconds (like GREEN_TICKS etc. in the Verilog) ----
const unsigned long ALL_RED_TIME = 2000;
const unsigned long GREEN_TIME   = 5000;
const unsigned long AMBER_TIME   = 2000;
const unsigned long WALK_TIME    = 4000;

// ---- States (same order as the Verilog, so the numbers match) ----
enum State { ALL_RED, NORTH_GREEN, NORTH_AMBER, EAST_GREEN, EAST_AMBER, WALK };
const char* STATE_NAMES[] = {
  "ALL_RED", "NORTH_GREEN", "NORTH_AMBER", "EAST_GREEN", "EAST_AMBER", "WALK"
};

State state          = ALL_RED;
State afterWalk      = NORTH_GREEN;  // which green comes after WALK
bool  walkRequested  = false;        // remembers a button press
unsigned long stateStart = 0;        // when we entered the current state

// Move to a new state and remember when it started
void changeState(State next) {
  state = next;
  stateStart = millis();
  Serial.print(millis());
  Serial.print(" ms -> ");
  Serial.println(STATE_NAMES[state]);
}

// Set all the lights, with the same safety rules as the testbench
void setLights(bool nR, bool nA, bool nG, bool eR, bool eA, bool eG, bool walk) {
  // Rule 1: never both green.  Rule 3: WALK only when both roads are red.
  if ((nG && eG) || (walk && !(nR && eR))) {
    Serial.println("SAFETY ERROR! Forcing all red.");
    nR = 1; nA = 0; nG = 0;
    eR = 1; eA = 0; eG = 0;
    walk = 0;
  }
  digitalWrite(N_RED, nR); digitalWrite(N_AMB, nA); digitalWrite(N_GRN, nG);
  digitalWrite(E_RED, eR); digitalWrite(E_AMB, eA); digitalWrite(E_GRN, eG);
  digitalWrite(WALK_LED, walk);
}

void setup() {
  for (int pin = 2; pin <= 7; pin++) pinMode(pin, OUTPUT);
  pinMode(WALK_LED, OUTPUT);
  pinMode(BUTTON, INPUT_PULLUP);   // pressed = LOW, not pressed = HIGH
  Serial.begin(9600);
  Serial.println("Traffic light starting");
  changeState(ALL_RED);            // safe start, like the Verilog reset
}

void loop() {
  // 1. Remember a button press (ignored during WALK), same as the Verilog
  if (digitalRead(BUTTON) == LOW && state != WALK && !walkRequested) {
    walkRequested = true;
    Serial.println("Button pressed: WALK requested");
  }

  // 2. How long have we been in this state?
  unsigned long timeInState = millis() - stateStart;

  // 3. Set the lights for this state, and move on when the time is up
  switch (state) {
    case ALL_RED:
      setLights(1,0,0, 1,0,0, 0);
      if (timeInState >= ALL_RED_TIME) changeState(NORTH_GREEN);
      break;

    case NORTH_GREEN:
      setLights(0,0,1, 1,0,0, 0);
      if (timeInState >= GREEN_TIME) changeState(NORTH_AMBER);
      break;

    case NORTH_AMBER:
      setLights(0,1,0, 1,0,0, 0);
      if (timeInState >= AMBER_TIME) {
        if (walkRequested) { afterWalk = EAST_GREEN; changeState(WALK); }
        else changeState(EAST_GREEN);
      }
      break;

    case EAST_GREEN:
      setLights(1,0,0, 0,0,1, 0);
      if (timeInState >= GREEN_TIME) changeState(EAST_AMBER);
      break;

    case EAST_AMBER:
      setLights(1,0,0, 0,1,0, 0);
      if (timeInState >= AMBER_TIME) {
        if (walkRequested) { afterWalk = NORTH_GREEN; changeState(WALK); }
        else changeState(NORTH_GREEN);
      }
      break;

    case WALK:
      setLights(1,0,0, 1,0,0, 1);
      if (timeInState >= WALK_TIME) {
        walkRequested = false;           // request served
        changeState(afterWalk);
      }
      break;
  }
}