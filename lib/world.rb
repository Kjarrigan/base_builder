class Tile
  attr_reader :x, :y
  attr_reader :img, :features
  def initialize(x,y,type)
    @x, @y = x, y
    @features = []
    @img = false
    self.type = type
  end

  def type=(val)
    @type = val
    if val.nil?
      @img = nil
      return
    end

    @img = AssetManager.tile(val)
    raise "No assets #{val.inspect} found!" if @img.nil?
  end

  # Returns only the "base"-type
  def type
    return nil if @type.nil?
    @type.to_s.split('_')[0].to_sym
  end

  def draw(*args)
    return false unless @img
    @img.draw(*args)
  end
end

class Map
  TILE_SIZE = 32

  attr_reader :layer
  def initialize(width, height, base_tile = :Ground, attrs = {})
    @width = width
    @height = height
    @attrs = attrs
    @tiles = {}
    @layer = {}
    width.times do |x|
      @tiles[x] ||= {}
      height.times do |y|
        @tiles[x][y] = Tile.new(x, y, base_tile)
      end
    end
    update
  end

  def add_layer(name, base_tile = :Blank, attrs={tile_draw: []})
    @layer[name] = Map.new(@width, @height, base_tile, attrs)
  end

  def update
    @image = Gosu.record(@width*TILE_SIZE, @height*TILE_SIZE) do
      @tiles.each do |x, rows|
        rows.each do |y, tile|
          tile.draw(x*TILE_SIZE, y*TILE_SIZE, 0, *@attrs[:tile_draw])
        end
      end
    end
  end

  def draw
    # Static part
    @image.draw(0,0,0)
    @layer.each{|_,lay| lay.draw }

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

  def update_connected_tile(tile)
    friends = get_friends_for(tile)
    tile.type = [tile.type, *friends.keys].join('_').to_sym if tile.type == :Wall
    friends
  end

  def move_tile_to_base_layer(t, layer_name)
    bt = @tiles[t.x][t.y]
    bt.type = t.type
    friends = update_connected_tile(bt)
    friends.each do |_,f| update_connected_tile(f) end
    t.type = nil
    update
    layer[layer_name].update
  end
end
