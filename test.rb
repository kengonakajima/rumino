require "./rumino.rb"



nt = Time.now.to_i
path = "/tmp/rumino_test_hoge_#{nt}"
rm_rf(path)
mkdir(path)
assert( exist(path) )
