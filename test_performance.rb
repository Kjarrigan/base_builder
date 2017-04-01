require 'benchmark'


h = Hash.new

5000.times do |i|
  h[i] = rand(100)
end

def select(h)
  sum = 0
  sub_set = h.select{|_,v| v == 50 }
  sub_set.each do |s|
    sum += 1
  end
  sum
end

def each(h)
  sum = 0
  h.each do |_,v|
    sum += 1 if v == 50
  end
  sum
end

puts select(h)
puts each(h)

Benchmark.bm do |x|
  x.report { 10000.times do select(h) end }
  x.report { 10000.times do each(h) end }
end