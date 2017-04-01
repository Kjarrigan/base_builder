require 'gosu'

class Tile
  attr_reader :img
  def initialize(x,y,type)
    @x, @y = x, y
    self.type = type
  end
  
  def type=(val)
    @type = val
    @img = AssetManager.load_tile(val)
  end
end
  
class Map
  TILE_SIZE = 32
  
  def initialize(width, height)
    @width = width
    @height = height
    @tiles = {}
    width.times do |x|
      @tiles[x] ||= {}
      height.times do |y|
        @tiles[x][y] = Tile.new(x, y, :Ground)
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
  
  def tiles_between(x1, y1, x2, y2)
    tiles = []
    
    x1, x2 = x2, x1 if x1 > x2
    y1, y2 = y2, y1 if y1 > y2
    (x1..x2).step(TILE_SIZE).each do |tx|
      (y1..y2).step(TILE_SIZE).each do |ty|
        tiles << tile_at(tx,ty)
      end
    end
    p tiles
    tiles.compact
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
    @current_action = nil
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
    @log.draw_rel(@action_mode, self.width-10, 10, 50, 1.0, 0.0)
    @log.draw(@messages.first, 10, 10, 50)
    
    Gosu.scale(@camera.zoom) do
      Gosu.translate(@camera.x, @camera.y) do
        @map.draw
      end
    end
  end
  
  def button_down(id)
    @messages << "Button pressed: #{Gosu.button_id_to_char(id)} (#{id})"
    case id
    when Gosu::MS_LEFT
      @dragging_started_at = [mouse_x + @camera.x, mouse_y + @camera.y]
    end
  end
  
  def button_up(id)
    @messages << "Button released: #{Gosu.button_id_to_char(id)} (#{id})"
    case id
    when Gosu::MS_LEFT
      if @action_mode == :Build
        tiles = @map.tiles_between(*@dragging_started_at, mouse_x + @camera.x, mouse_y + @camera.y)
        return if tiles.empty?
        
        tiles.each do |t|
          t.type = @build_obj
        end
        @map.update
      end
    when Gosu::MS_WHEEL_UP then @camera.zoom += 0.1
    when Gosu::MS_WHEEL_DOWN then @camera.zoom -= 0.1
      
    when Gosu::KB_1
      @action_mode = :Build
      @build_obj = :Floor
    end
  end
  
  def needs_cursor?; true; end
end

Window.new.show if $0 == __FILE__