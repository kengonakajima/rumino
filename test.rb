require "./rumino.rb"

p "start"



# hash
h={"a"=>1,"b"=>2}
assert(h.a==1)
assert(h.b==2)
assert(h.c==nil)


# timer
p unixtime( "2012-06-10 11:11:11" ) 
assert( unixtime( "2012-06-10 11:11:11" ) == 1339294271 )

# file 

nt = nowi()

path = "/tmp/rumino_test_hoge_#{nt}"
assert(rm_rf(path))
assert(mkdir(path))
assert(exist(path))
assert(rm_rf(path))
assert(!exist(path))

assert(ensureDir(path+"/a/b/c/d"))
assert(rm_rf(path+"/a/b/c/d"))


assert(ok(false)=="NG")
assert(ok(true)=="OK")

assert(existProcess(getpid()))

assert(ls("./*.rb").size>=2)

aaa = "hello"
assert(doerb( "erb.tmpl",binding).strip=="hello")

p quote("a\nb\n")
assert(quote("a\nb\n")==" > a\n > b\n")

path = "/tmp/rumino_test_hoge_2_#{nt}"
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
assert(h["a"]==1)
assert(h["b"]==3)
assert(h["c"]==4)

# mysql
my = MysqlWrapper.new( "localhost","root","","")
p my.stat()
my.close()
conf = { "host"=>"localhost", "user"=>"root", "password"=>"","database"=>""}
my = MysqlWrapper.new( conf)


my.query( "create database if not exists test")
my.query( "use test")
my.query( "drop table if exists rumino_test" )

my.query( "create table if not exists rumino_test ( id int not null primary key auto_increment, name char(50), createdAt datetime )" )

#my.query( "insert into rumino_test set name='aa', createdAt=now() " )
#my.query( "insert into rumino_test set name='aa', createdAt=now() " )
#my.query( "insert into rumino_test set name='aa', createdAt=now() " )

nowt = now()
newid = my.insert( "rumino_test", { :name=>"aa", :createdAt=>todate(nowt)})
newid = my.insert( "rumino_test", { :name=>"aa", :createdAt=>todate(nowt)})
newid = my.insert( "rumino_test", { "name"=>"aa", "createdAt"=>todate(nowt)})
assert(newid==3)
cnt = my.queryScalar( "select count(*) from rumino_test" )
assert(cnt==3)
cnt = my.count( "rumino_test where id>=2")
assert(cnt==2)
e=false
begin
  my.insert( "rumino_test", {:name=>[1,2,3], :createdAt=>{"a"=>"b"}})
rescue
  p "got exception: ", $!
  e=true
end
assert(e)
out=my.query1( "select * from rumino_test where id=1")
assert(out)
assert(out.id==1)

res = my.query( "select id,name,createdAt from rumino_test" )
assert( res.size == 3 )

res.each do |ent|
  print("row:",ent["id"], ",", ent["name"], ",", ent["createdAt"], "\n" )
  assert( ent["name"]=="aa")
  assert( ent["createdAt"].to_i == nowt.to_i )
end

res = my.query( "select * from rumino_test where id >= ? and name='?' and name !='?' order by id", 2, "aa", "\t\n" )
assert(res.size==2)
assert(res[0].id==2)
assert(res[1].id==3)

# array
ary = my.queryArray( "select id from rumino_test order by id" )
assert( ary.size == 3 )
assert( ary[0] == 1 )
assert( ary[1] == 2 )
assert( ary[2] == 3 )
e=false
begin
  my.queryArray( "select id,name from rumino_test order by id" )
rescue
  p "expected:", $!
  e=true
end
assert(e)


# update
my.update( "rumino_test", { "name"=>"bb" }, "id=2")
out=my.query1( "select * from rumino_test where id=2")
assert(out.name=="bb")
my.update( "rumino_test", { "name"=>"cc" }, "id=?",2)
out=my.query1( "select * from rumino_test where id=2")
assert(out.name=="cc")

# boolean
my.query( "drop table if exists rumino_test_bool" )
my.query( "create table rumino_test_bool ( v int )" )
my.insert( "rumino_test_bool", { :v => true } )
v = my.queryScalar( "select v from rumino_test_bool limit 1" )
assert(v==1)
my.update( "rumino_test_bool", { :v => false }, "v=1" )
v = my.queryScalar( "select v from rumino_test_bool limit 1" )
assert(v==0)
v = my.queryScalar( "select v from rumino_test_bool limit ?",1 )
assert(v==0)

# ensureColumns
my.query( "drop table if exists rumino_test_ens" )
my.query( "create table rumino_test_ens ( v int, name char(100), age int )" )
assert( my.ensureColumns( "rumino_test_ens", [ "v","name", "age" ] ) )
e=false
begin
  my.ensureColumns( "rumino_test_ens", [ "v","name", :age, "causeserror" ] )
rescue
  p "expected:", $!
  e=true
end
assert(e)

#
def dumplocaltest(a,b,c)
  return dumplocal(binding)
end
assert( dumplocaltest(1,"2",3) == "a:1(Fixnum)\tb:2(String)\tc:3(Fixnum)\t\n" )

#
assert( esc("hello\"") == "hello\\\"" )
assert( my.esc("hello\"") == "hello\\\"" )

p "done"

