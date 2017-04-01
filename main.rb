require 'gosu'

class Tile
  attr_reader :x, :y
  attr_reader :img, :features
  def initialize(x,y,type)
    @x, @y = x, y
    @features = []
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
    # Static part
    @image.draw(0,0,0)
    
    # Tiles features
    each do |x,y,t|
      next if t.features.empty?
      t.features.each do |f|
        AssetManager.load_tile(f).draw(x*TILE_SIZE, y*TILE_SIZE, 1)
      end
    end
  end
  
  def each
    @tiles.each do |x, rows|
      rows.each do |y, tile|
        yield(x,y,tile)
      end
    end    
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
    tiles.compact
  end
end

class Camera
  attr_reader :x, :y, :zoom
  def initialize(win)
    @win = win # Unfortunately mouse_x and mouse_y aren't Gosu::module methods yet
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
  
  def mouse_x_world
    @win.mouse_x + self.x
  end
  
  def mouse_y_world
    @win.mouse_y + self.y
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
    
    @camera = Camera.new(self)
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
    
        if @dragging_started_at 
          if @action_mode == :Build
            tiles = @map.tiles_between(*@dragging_started_at, @camera.mouse_x_world, @camera.mouse_y_world)
            tiles.each do |t|
              AssetManager.load_tile(:Build_Preview).draw(t.x*Map::TILE_SIZE, t.y*Map::TILE_SIZE,1)
            end
          else
            x1, y1 = *@dragging_started_at
            x2, y2 = @camera.mouse_x_world, @camera.mouse_y_world
            Gosu.draw_quad(x1,y1,0x80_ff0000,
                           x1,y2,0x80_ff0000,
                           x2,y2,0x80_ff0000,
                           x2,y1,0x80_ff0000, 1)
          end
        end        
      end
    end
  end
  
  def button_down(id)
    @messages << "Button pressed: #{Gosu.button_id_to_char(id)} (#{id})"
    case id
    when Gosu::MS_LEFT
      @dragging_started_at = [@camera.mouse_x_world, @camera.mouse_y_world]
    end
  end
  
  def button_up(id)
    @messages << "Button released: #{Gosu.button_id_to_char(id)} (#{id})"
    case id
    when Gosu::MS_LEFT
      if @action_mode == :Build
        tiles = @map.tiles_between(*@dragging_started_at, @camera.mouse_x_world, @camera.mouse_y_world)
        
        tiles.each do |t|
          t.type = @build_obj
        end
        @map.update unless tiles.empty?
      end
      @dragging_started_at = nil
    when Gosu::MS_WHEEL_UP then @camera.zoom += 0.1
    when Gosu::MS_WHEEL_DOWN then @camera.zoom -= 0.1
      
    when Gosu::KB_1
      @action_mode = :Build
      @build_obj = :Floor
      
    when Gosu::KB_ESCAPE
      @action_mode = nil
    end
  end
  
  def needs_cursor?; true; end
end

Window.new.show if $0 == __FILE__