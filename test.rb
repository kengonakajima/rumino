require "./rumino.rb"



nt = Time.now.to_i
path = "/tmp/rumino_test_hoge_#{nt}"
assert(rm_rf(path))
assert(mkdir(path))
assert(exist(path))
