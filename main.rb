require 'gosu'

Tile = Struct.new :x, :y, :type, :img
class Map
  TILE_SIZE = 32
  
  def initialize(width, height)
    @width = width
    @height = height
    @tiles = {}
    width.times do |x|
      @tiles[x] ||= {}
      height.times do |y|
        @tiles[x][y] = Tile.new(x, y, :Ground, AssetManager.load_tile(:Gras))
      end
    end
    update
  end
  
  def update
    @image = Gosu.record(@width*TILE_SIZE, @height*TILE_SIZE) do
      @tiles.each do |x, rows|
        rows.each do |y, tile|
          tile.img.draw(x*TILE_SIZE, y*TILE_SIZE, 0)
        end
      end
    end
  end
  
  def draw
    @image.draw(0,0,0)
  end
  
  def tile_at(x,y)
    x = (x / TILE_SIZE).floor
    @tiles[x] && @tiles[x][(y / TILE_SIZE).floor]
  end
end

class Camera
  attr_reader :x, :y, :zoom
  def initialize()
    @x = 0
    @y = 0
    @zoom = 1.0
  end
  
  # TODO: Set scroll limits
  def x=(v)
    @x = v
  end

  # TODO: Set scroll limits  
  def y=(v)
    @y = v
  end
    
  def zoom=(v)
    @zoom = v
    @zoom = 0.5 if v < 0.5
  end
  
  def speed
    20 / @zoom
  end
  
  def to_s
    format "Zoom: %.2f | x: %d | y: %d", @zoom, @x, @y
  end
end    

module AssetManager
  def self.load_tile(name)
    return @tiles[name] if @tiles && @tiles[name]
    @tiles ||= {} 
    @tiles[name] = Gosu::Image.new(File.join(__dir__, 'assets', "#{name}.png"))
  end
end

class Window < Gosu::Window
  VERSION = '0.1.0'
  CAPTION = "BaseBuilder v#{VERSION}"
  
  def initialize
    super(1280, 768)
    self.caption = CAPTION
    
    @log = Gosu::Font.new(12)
    @messages = []
    @last_tick = Hash.new(0)
    
    @map = Map.new(50,50)
    
    @camera = Camera.new
  end
  
  def update
    @camera.y += @camera.speed if Gosu.button_down?(Gosu::KB_UP)
    @camera.y -= @camera.speed if Gosu.button_down?(Gosu::KB_DOWN)
    @camera.x -= @camera.speed if Gosu.button_down?(Gosu::KB_RIGHT)
    @camera.x += @camera.speed if Gosu.button_down?(Gosu::KB_LEFT)
    
    if (Gosu.milliseconds - @last_tick[2000]) > 2000
      self.caption = CAPTION + " | FPS: #{Gosu.fps} | #{@camera}"
      
      @messages.shift
      @last_tick[2000] = Gosu.milliseconds 
    end    
  end
  
  def draw
    @log.draw(@messages.first, 10, 10, 50, 1, 1, 0xff_ff00ff)
    
    Gosu.scale(@camera.zoom) do
      Gosu.translate(@camera.x, @camera.y) do
        @map.draw
      end
    end
  end
  
  def button_down(id)
  end
  
  def button_up(id)
    @messages << "Button released: #{Gosu.button_id_to_char(id)} (#{id})"
    case id
    when Gosu::MS_LEFT
      if @build_mode
        tile = @map.tile_at(mouse_x + @camera.x, mouse_y + @camera.y)
        return unless tile
        p @build_obj
        tile.type = @build_obj
        tile.img = AssetManager.load_tile(@build_obj)
        @map.update
      end
    when Gosu::MS_WHEEL_UP then @camera.zoom += 0.1
    when Gosu::MS_WHEEL_DOWN then @camera.zoom -= 0.1
      
    when Gosu::KB_1
      @build_mode = true
      @build_obj = :Floor
    end
  end
  
  def needs_cursor?; true; end
end

Window.new.show if $0 == __FILE__