# I2C::BME280

[![Gem Version](https://badge.fury.io/rb/i2c-bme280.svg)](https://badge.fury.io/rb/i2c-bme280)

Ruby driver for the Bosch BME280 sensor over the I2C protocol.

The driver uses the i2c gem which relies on the i2c-dev package.

It was mainly ported from the bme280_sample.py script.

Thanks and credits to:
- https://cdn-shop.adafruit.com/datasheets/BST-BME280_DS001-10.pdf
- https://github.com/SWITCHSCIENCE/BME280/blob/master/Python27/bme280_sample.py
- https://github.com/andec/i2c

## Installation

The library depends on the i2c-dev package.
Furthermore the I2C kernel module has to be enabled manually if you are using the Raspberry Pi.

### i2c-dev

Debian based systems:

`sudo apt-get install i2c-dev`

### Enable I2C (Raspberry Pi)

`sudo raspi-config` -> Select `Advanced Options` -> Select `I2C` -> Select `Yes` (2 times) -> Reboot

### Gemfile

Just include the following line to your `Gemfile` to use the driver.

```ruby
gem 'i2c-bme280'
```

## Usage

Example:

```ruby
require 'i2c/bme280'
require 'json'

# Make sure you specify the i2c device id in the constructor.
# The default device id on the raspberry pi is 1.
# You can also pass a string that points to the device file: e.g. '/dev/i2c-1'
bme280 = I2C::Driver::BME280.new(device: 1)

puts "Temperature: #{'%7.2f' % bme280.temperature} [°C]"
puts "Pressure:    #{'%7.2f' % bme280.pressure} [hPa]"
puts "Humidity:    #{'%7.2f' % bme280.humidity} [%]"
puts
puts "JSON: #{bme280.all.to_json}"
```

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
