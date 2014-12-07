require 'hansi'

class NodeLogger < Logger
  attr_writer :color

  def initialize(device = $stdout)
    super device
  end

  def log(what)
    super Logger::DEBUG, ::Hansi.render(@color, what)
  end

  def self.colors
    colors = []
    steps  = (0..255).step(15)

    steps.each do |red|
      steps.each { |green| colors << Hansi[ red: red, green: green ]}
      steps.each { |blue|  colors << Hansi[ red: red, green: 255 - blue, blue: blue]}
      steps.each { |blue|  colors << Hansi[ red: red, blue: 255 - blue ]}
    end
    colors
  end
end

