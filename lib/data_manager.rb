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

    # Ground
    33 => :Ground,
    34 => :Floor,
    35 => :Blank,

    # Additional
    49 => :Build_Preview,
  }
  def self.tile(name)
    @tiles[name]
  end

  def self.load_tileset
    @tileset = Gosu::Image.new(File.join(__dir__, '..', 'assets', "Tileset.png"), tileable: true)
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
