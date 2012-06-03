require "./rumino.rb"

p "start"

nt = Time.now.to_i

path = "/tmp/rumino_test_hoge_#{nt}"
assert(rm_rf(path))
assert(mkdir(path))
assert(exist(path))
assert(rm_rf(path))
assert(!exist(path))

assert(ok(false)=="NG")
assert(ok(true)=="OK")

assert(existProcess(getpid()))

assert(ls("./*.rb").size>=2)

aaa = "hello"
assert(doerb( "erb.tmpl",binding).strip=="hello")

p quote("a\nb\n")
assert(quote("a\nb\n")==" > a\n > b\n")

path = "/tmp/rumino_test_hoge_#{nt}"
assert(writeFile(path,"hoge"))
assert(appendFile(path,"piyo"))
assert(appendFile(path,"piyo"))
assert(readFile(path)=="hogepiyopiyo")
h = {"a"=>1,"b"=>"c"}
assert(writeFile(path,h.to_json))
rh = readJSON(path)
assert(rh)
assert(rh["a"]==1)
assert(rh["b"]=="c")

assert(savePid(path))
r = readFile(path)
assert(r)
pid=r.strip.to_i
assert(existProcess(pid))

j = {"a"=>1,"b"=>"c"}
assert(!differ(h,j))
k = {"a"=>1,"b"=>"d"}
assert(differ(h,k))

t = [
  [ 1, "hello", 3 ],
  [ 500, 100, "hoge" ]
]
s=gentbl(t)
ss = "1   hello 3    \n500 100   hoge \n"
assert(s==ss)



p "done"

