# i2c-tiny-sniffer

**i2c-tiny-sniffer** is a simple sniffer of I2C bus based on ATtiny2313A MCU.

  - I2C speed up to 400Kbps (in theory may be increased to 1Mbps @20MHz @5VDD)
  - Output data in ASCII code from USART (start: `#`, stop: `!`)
  - Pins: PB5: SDA, PB7: SCL, PD1: TXD

Project for AtmelStudio 7.0 IDE.