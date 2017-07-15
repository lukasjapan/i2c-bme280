require 'i2c'

module I2C
  module Driver
    class BME280
      I2C_ADDRESS = 0x76 # I2C Bus address

      # @param [Integer|String|I2C::Dev] device The I2C device id of i2c-dev, a string that points to the i2c-dev device file or an already initialized I2C::Dev instance
      # @param [Fixnum] i2c_address The i2c address of the BME280. Factory default is 0x76.
      def initialize(device:, i2c_address: I2C_ADDRESS)
        device = "/dev/i2c-#{device}" if device.is_a?(Integer)

        if device.is_a?(String)
          raise ArgumentError, "I2C device #{device} not found. Is the I2C kernel module enabled?" unless File.exists?(device)
          device = I2C.create(device)
        end

        raise ArgumentError unless device.is_a?(I2C::Dev)

        @device = device
        @i2c_address = i2c_address
      end

      # returns all sensor values in a hash
      # t: temperature
      # p: pressure
      # h: humidity
      # @return [Hash] All sensor values
      def all
        data
      end

      # @return [Float] The temperature in Celsius
      def temperature
        data[:t]
      end

      # @return [Float] The pressure in hectoPascal
      def pressure
        data[:p]
      end

      # @return [Float] The humidity in percent (0.0-100.0)
      def humidity
        data[:h]
      end

      private

      # tells the chip to update its data registers
      def update(
        s_t: 1,    # Temperature oversampling = x1
        s_h: 1,    # Humidity oversampling = x1
        s_p: 1,    # Pressure oversampling = x1
        mode: 1,   # Normal mode
        t_s: 5,    # Standby time = 1000ms
        filter: 0, # Disable filter
        spi: 0     # Disable SPI
        )

        tp_reg     = 0xF4      # Register address for temperature/pressure settings
        h_reg      = 0xF2      # Register address for humidity settings
        config_reg = 0xF5      # Register address for config settings

        tp_val     = (s_t << 5) | (s_p << 2) | mode
        h_val      = s_h
        config_val = (t_s << 5) | (filter << 2) | spi

        write(tp_reg, tp_val)
        write(h_reg, h_val)
        write(config_reg, config_val)
      end

      # Read calibration parameters of the BME280
      # https://cdn-shop.adafruit.com/datasheets/BST-BME280_DS001-10.pdf Page 22
      def calib_params
        # data addresses
        dig_t_reg  = 0x88
        dig_p_reg  = 0x8E
        dig_h_reg1 = 0xA1
        dig_h_reg2 = 0xE1

        # read calibration bytes
        dig_t = read(dig_t_reg, 6).unpack("S1s2")
        dig_p = read(dig_p_reg, 18).unpack("S1s8")
        dig_h = (read(dig_h_reg1, 1) + read(dig_h_reg2, 7)).unpack("C1s1C1C3c1")

        # H4,H5 are saved in an inconvenient format
        dig_h4 = (dig_h[3] << 4) + (dig_h[4] & 0x0f)
        dig_h5 = (dig_h[4] >> 4) + (dig_h[5] << 4)

        # reassemble dig_h
        dig_h = dig_h[0..2] + [ dig_h4, dig_h5 ] + dig_h[6..6]

        {
          t: dig_t,
          p: dig_p,
          h: dig_h
        }
      end

      # return all compensated values
      # ported from bme280_sample.py
      def data
        # tell the chip to update its data
        update

        # read calibration data
        calib = calib_params

        # read raw data
        data_reg = 0xF7
        data = read(data_reg, 8).unpack("C8")
        raw_t = (data[3] << 12) | (data[4] << 4) | (data[5] >> 4)
        raw_p = (data[0] << 12) | (data[1] << 4) | (data[2] >> 4)
        raw_h = (data[6] << 8)  |  data[7]

        # commonly used for compensation
        v1 = (raw_t / 16384.0 - calib[:t][0] / 1024.0) * calib[:t][1]
        v2 = (raw_t / 131072.0 - calib[:t][0] / 8192.0) * (raw_t / 131072.0 - calib[:t][0] / 8192.0) * calib[:t][2]
        t_fine = v1 + v2

        # compensate temperature
        t = t_fine / 5120.0

        # compensate pressure
        v1 = (t_fine / 2.0) - 64000.0
        v2 = (((v1 / 4.0) * (v1 / 4.0)) / 2048) * calib[:p][5]
        v2 = v2 + ((v1 * calib[:p][4]) * 2.0)
        v2 = (v2 / 4.0) + (calib[:p][3] * 65536.0)
        v1 = (((calib[:p][2] * (((v1 / 4.0) * (v1 / 4.0)) / 8192)) / 8)  + ((calib[:p][1] * v1) / 2.0)) / 262144
        v1 = ((32768 + v1) * calib[:p][0]) / 32768

        if v1 == 0
          p = 0.0
        else
          p = ((1048576 - raw_p) - (v2 / 4096)) * 3125
          p = p < 0x80000000 ? (p * 2.0) / v1 : (p / v1) * 2.0
          v1 = (calib[:p][8] * (((p / 8.0) * (p / 8.0)) / 8192.0)) / 4096
          v2 = ((p / 4.0) * calib[:p][7]) / 8192.0
          p = p + ((v1 + v2 + calib[:p][6]) / 16.0)
          p = p / 100.0
        end

        # compensate humidity
        h = t_fine - 76800.0
        if h != 0
          h = (raw_h - (calib[:h][3] * 64.0 + calib[:h][4]/16384.0 * h)) * (calib[:h][1] / 65536.0 * (1.0 + calib[:h][5] / 67108864.0 * h * (1.0 + calib[:h][2] / 67108864.0 * h)))
          h = h * (1.0 - calib[:h][0] * h / 524288.0)
          h = 100.0 if h > 100.0
          h = 0.0 if h < 0.0
        end

        # return as hash
        {
          t: t,
          p: p,
          h: h
        }
      end

      # write to device
      def write(reg_address, data)
        @device.write(@i2c_address, reg_address, data)
      end

      # read from device
      def read(reg_address, size = 1)
        @device.read(@i2c_address, size, reg_address)
      end
    end
  end
end
