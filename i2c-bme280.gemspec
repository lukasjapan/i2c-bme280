# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'i2c/bme280/version'

Gem::Specification.new do |spec|
  spec.name          = 'i2c-bme280'
  spec.version       = I2C::BME280::VERSION
  spec.authors       = ['Lukas Prasuhn']
  spec.email         = ['lukas@cvguy.de']

  spec.summary       = 'Ruby driver for the Bosch BME280 sensor.'
  spec.homepage      = 'https://github.com/lukasjapan/i2c-bme280'
  spec.license       = 'MIT'
  spec.files         = %w(lib/i2c/bme280.rb lib/i2c/bme280/version.rb)
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'i2c', '~> 0.4'
end
