require 'gosu'
require 'pry'

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
    @img = AssetManager.tile(val)
    raise "No assets #{val.inspect} found!" if @img.nil?
  end

  # Returns only the "base"-type
  def type
    @type.to_s.split('_')[0].to_sym
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
        AssetManager.tile(f).draw(x*TILE_SIZE, y*TILE_SIZE, 1)
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

  def get_neighbours_for(tile)
    {
      N: @tiles[tile.x][tile.y-1],
      E: @tiles[tile.x+1][tile.y],
      S: @tiles[tile.x][tile.y+1],
      W: @tiles[tile.x-1][tile.y],
    }
  end

  # Friends are all tiles of same type
  def get_friends_directions_for(tile)
    get_friends_for(tile).keys
  end

  def get_friends_for(tile)
    get_neighbours_for(tile).select{|_, t| t.type == tile.type }
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
  SubimageMap = {
    # Walls
    # Solo
     1 => :Wall,

    # 1-neighbour
    13 => :Wall_N,
     2 => :Wall_E,
    14 => :Wall_S,
     5 => :Wall_W,

    # 2-neighbours
    12 => :Wall_N_S,
    11 => :Wall_E_W,

     6 => :Wall_N_E,
     4 => :Wall_E_S,
     3 => :Wall_S_W,
     7 => :Wall_N_W,

    # 3-neighbours
    16 => :Wall_N_E_W,
     9 => :Wall_N_S_W,
    10 => :Wall_N_E_S,
     8 => :Wall_E_S_W,

    # 4-neighbours
    15 => :Wall_N_E_S_W,

    49 => :Build_Preview,

    33 => :Ground,
    34 => :Floor,
  }
  def self.tile(name)
    @tiles[name]
  end

  def self.load_tileset
    @tileset = Gosu::Image.new(File.join(__dir__, 'assets', "Tileset.png"), tileable: true)
    @tiles = {}
    SubimageMap.each do |slot, tile_name|
      x = (slot-1) % 16 * Map::TILE_SIZE
      y = (slot-1) / 16 * Map::TILE_SIZE
      w = h = Map::TILE_SIZE
      puts "Extract #{tile_name} from P(#{x},#{y}), D(#{w},#{h})"
      @tiles[tile_name] = @tileset.subimage(x, y, w, h)
    end
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
    AssetManager.load_tileset
    
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
              AssetManager.tile(:Build_Preview).draw(t.x*Map::TILE_SIZE, t.y*Map::TILE_SIZE,1)
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
      build_object if @action_mode == :Build
      @dragging_started_at = nil
    when Gosu::MS_WHEEL_UP then @camera.zoom += 0.1
    when Gosu::MS_WHEEL_DOWN then @camera.zoom -= 0.1
    when Gosu::KB_1 then build_mode :Floor
    when Gosu::KB_2 then build_mode :Wall
    when Gosu::KB_F1 then $debug = !$debug
    when Gosu::KB_ESCAPE
      @action_mode = nil
    end
  end
  
  def needs_cursor?; true; end

  def build_mode(type)
    @action_mode = :Build
    @build_obj = type
  end

  def build_object
    tiles = @map.tiles_between(*@dragging_started_at, @camera.mouse_x_world, @camera.mouse_y_world)

    tiles.each do |t|
      val = @build_obj
      t.type = val
      if val == :Wall
        friends = update_connected_tile(t)
        friends.each do |_,f| update_connected_tile(f) end
      end
    end
    @map.update unless tiles.empty?
  end

  def update_connected_tile(tile)
    friends = @map.get_friends_for(tile)
    binding.pry if $debug
    tile.type = [tile.type, *friends.keys].join('_').to_sym
    friends
  end
end

$debug = false
Window.new.show if $0 == __FILE__