require 'gosu'
require 'pry'

require_relative 'lib/data_manager'
require_relative 'lib/world'

class Numeric
  def ms
    self
  end

  def s
    self * 1000
  end

  def min
    (self * 60).s
  end

  def h
    (self * 60).min
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

  def update
    @camera.y += @camera.speed if Gosu.button_down?(Gosu::KB_UP)
    @camera.y -= @camera.speed if Gosu.button_down?(Gosu::KB_DOWN)
    @camera.x -= @camera.speed if Gosu.button_down?(Gosu::KB_RIGHT)
    @camera.x += @camera.speed if Gosu.button_down?(Gosu::KB_LEFT)
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
    @map.add_layer(:Buildqueue, nil, { tile_draw: [1,1,0x20_ffffff, :default]  })
    @job_queue = []
    
    @camera = Camera.new(self)
  end
  
  def update
    @camera.update

    every 50.ms do
      @map.move_tile_to_base_layer(@job_queue.shift, :Buildqueue) if @job_queue.any?
    end
    every 1.s do
      self.caption = CAPTION + " | FPS: #{Gosu.fps} | #{@camera}"
      @messages.shift
    end
  end
  
  def draw
    @log.draw_rel(@action_mode, self.width-10, 10, 50, 1.0, 0.0)
    @log.draw(@messages.first, 10, 10, 50)
    
    Gosu.scale(@camera.zoom) do
      Gosu.translate(@camera.x, @camera.y) do
        @map.draw
        @map.layer.each{|_,lay| lay.draw }
    
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
    tiles = @map.layer[:Buildqueue].tiles_between(*@dragging_started_at, @camera.mouse_x_world, @camera.mouse_y_world)

    unless tiles.empty?
      tiles.each do |t|
        val = @build_obj
        t.type = val
        friends = @map.layer[:Buildqueue].update_connected_tile(t)
        friends.each do |_,f| @map.layer[:Buildqueue].update_connected_tile(f) end
        @job_queue << t
      end
      @map.layer[:Buildqueue].update
    end
  end

  def every(milliseconds)
    if (Gosu.milliseconds - @last_tick[milliseconds]) > milliseconds
      yield
      @last_tick[milliseconds] = Gosu.milliseconds
    end
  end
end

$debug = false
Window.new.show if $0 == __FILE__