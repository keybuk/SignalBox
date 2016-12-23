# SignalBox
DCC Project

## Wiring Setup

| App| Pi | Motorshield | Other |
| --- | --- | --- | --- |
| RailCom | #17 | PWM A | |
| DCC | #18 | DIR A | Oscilloscope Ch.B |
| Debug | #19 | | Oscilloscope Ch.A |
| | 5.0V | 5V | |
| | GND | GND | |
| | | A+ | Track* |
| | | A- | Track* |

\* do not connect Oscilloscope to Track and Pi at the same time
