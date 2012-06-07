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
assert(elapsedTime(path)<10)

j = {"a"=>1,"b"=>"c"}
assert(!differ(h,j))
k = {"a"=>1,"b"=>"d"}
assert(differ(h,k))

t = [
  [ 1, "hello", 3 ],
  nil,
  [ 500, 100, "hoge" ]
]
s=gentbl(t)
ss = "1   hello 3    \n500 100   hoge \n"
assert(s==ss)

assert(shortdate(0)=="now")
assert(shortdate(65)=="1min")
assert(shortdate(7300)=="2hr")
assert(shortdate(8*24*3600)=="8day")
assert(shortdate(800*24*3600)=="2year")

assert(writeFile("/tmp/js1",{"a"=>1,"b"=>2}.to_json))
assert(writeFile("/tmp/js2",{"b"=>3,"c"=>4}.to_json))
h=mergeJSONs("/tmp/js1","/tmp/js2")
assert(h)
h.each do |k,v|print("::",k,v) end
print("aaa:", h["a"])
assert(h["a"]==1)
assert(h["b"]==3)
assert(h["c"]==4)

p "done"

