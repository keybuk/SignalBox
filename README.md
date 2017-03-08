# SignalBox
Project to build a DCC computer control system that will allow completely autonomous operation of simple to complex layouts with train behaviors written in a scripting language.

For hardware a Raspberry Pi is used as the "command station" component, with both the Booster and RailCom components based on custom boards managed by Arduino/AVR microcontrollers.

[See the Wiki](https://github.com/keybuk/SignalBox/wiki) for more information and documentation.

## Why not use JMRI or Arduino DCC++?

For the same reason that some modellers enjoy kit or scratch-building their models or scenery instead of using ready-to-run items.

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
