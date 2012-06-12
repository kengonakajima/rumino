#
# rumino: for quick hack servers
#

require "rubygems"
require "json"
require "fileutils"
require "erb"
require "net/smtp"
require "webrick"

class Hash
  # to get rid of deprecation warnings..
  def id()
    return self["id"]
  end
  def method_missing(name,*args)
#    print( "NN:", name, ",", self, "\n")
    v = self[name.to_s]
    return v
  end
end



def assert(x,*msg)
  if !x then 
    raise msg.join()
  end
end


def pathdate()
  t = Time.now
  return sprintf( "%d_%02d%02d_%02d%02d%02d", t.year,t.month,t.day, t.hour,t.min,t.sec )
end

def prt(*ary)
  s = ary.join()
  STDERR.print(s)
  return s
end


def p(*ary)
  s = "[",Time.now.strftime("%Y-%m-%d %H:%M:%S"),"] ",ary.join(),"\n"
  STDERR.print(s)
  return s
end
def println(*ary)
  s = ary.join() + "\n"
  print s  
end
def cmd(s)
  p(s)
  return `#{s}`
end

def differ(h1,h2)
  return Marshal.dump(h1) != Marshal.dump(h2)
end

# globs = [ "*.rb", "js/*.js", .. ]
def monitorFiles(globs, proc )
  t = Thread.new do 
    changed = []
    lastmtime={}
    while true
      sleep 1
      all=[]
      globs.each do |pat|
        all += Dir.glob(pat) 
      end

      all.each do |fn|
        next if fn =~ /^_/
        s = File::Stat.new(fn)
        if lastmtime[fn] then
          if s.mtime != lastmtime[fn] then
            changed.push(fn)
            print fn, ": ", s.mtime, "  ",s.size, "\n"
            lastmtime[fn] = s.mtime
          end
        else
          lastmtime[fn] = s.mtime
        end
      end
      if changed.size > 0 then 
        proc.call( changed )
        changed = []
      end
    end
  end
  return t
end

def savePid(path)
  begin
    f=File.open(path,"w")
    f.write( "#{Process.pid}\n" )
    f.close()
    return true
  rescue
    return false
  end
end

def readJSON(path)
  begin
    f = File.open(path,"r")
    h = JSON.parse(f.read())
    f.close()
    return h
  rescue
    p "cannot read json from: #{path} : #{$!}"
    return nil
  end
end
def mergeJSONs(*paths)
  out={}
  paths.each do |path|
    if path then 
      h = readJSON(path)
      if h then 
        out=out.merge(h)
      end
    end
  end
  return out
end

def writeFile(path,s)
  begin
    f = File.open(path,"w")
    f.write(s)
    f.close()
    return true
  rescue
    return false
  end
end
def appendFile(path,s)
  begin
    f = File.open(path,"a+")
    f.write(s)
    f.close()
    return true
  rescue
    return false
  end
end
def readFile(path)
  begin
    f = File.open(path,"r")
    data = f.read()
    f.close()
    return data
  rescue
    return nil
  end
end

def exist(path)
  begin
    return File::Stat.new(path)
  rescue
    return false
  end
end
def eexit(s)
  p s
  exit 1
end
def quote(s)
  out=[]
  s.split("\n").each do |line|
    out.push( " > #{line}" )
  end
  return out.join("\n") + "\n"
end
def mkdir(path)
  begin
    Dir::mkdir(path,0755)
    return true
  rescue
    return false
  end
end
def ensureDir(path)
  begin
    ary=path.split("/")
    ary.size.times do |i|
      p=ary[0..i].join("/")
      mkdir(p)
    end
    return exist(path)
  rescue
    return false
  end
end
def ls(pat)
  return Dir.glob(pat)
end
def rm_rf(pat)
  begin
    FileUtils.rm_r(pat, {:force=>true})
    return true
  rescue
    return false
  end
end

def getTmpl(path)
  src = File.open(path,"r").read()
  return ERB.new(src)
end


def doerb(tmplpath,b)
#  STDERR.print "doerb start path:#{tmplpath}\n"
  erb = getTmpl(tmplpath)
  s = erb.result(b)
#  STDERR.print "doerb end path:#{tmplpath} slen:#{s.size}\n"
  return s
end

def sendmail(from,to,subj,msg)
  date = Time.now.to_s

  text  = "Subject: #{subj}\n"
  text += "From: #{from}\n"
  text += "Content-type: text/plain; charset=iso-2022-jp\n"
  text += "Sender: #{from}\n"
  text += "Date: #{date}\n"
  text += "To: #{to}\n"
  text += "\n\n"
  text += "#{msg}\n"
  text += "-----end of message---------------------\n"

  begin
    p "start smtp...\n"
    smtp = Net::SMTP.start( "localhost" , 25 )

    p "send_mail:"
    smtp.send_mail( text, from, to )
    smtp.finish
    p "finished.\n"
    return true
  rescue
    p "SEND ERROR : #{$!}\n"
    p "mail text:\n"
    p text
    return false
  end
end

def existProcess(pid)
  assert(pid)
  s = `ps -p #{pid}`.split("\n")[-1].split(" ")[0]
  if s.to_i == pid.to_i then 
    return true
  else
    return false
  end
end

def ok(b)
  if b then return "OK" else return "NG" end
end
def getpid()
  return Process.pid
end
def kill9self()
  cmd "kill -KILL #{getpid()}"
end

# input: 2D array
# a = [ [1,"helllllo",3], [500,100, "bb" ] ] 
# 
# outout: text table
#   1 helllllo  3
# 500      100 bb
#
# 

def gentbl(t)
  colszs=[]
  t.each do |line|
    next if not line
    line.size.times do |i|
      elem = line[i]
      sz = elem.to_s.size
      colszs[i] = sz if !colszs[i] or colszs[i] < sz 
    end 
  end
  out = ""
  t.each do |line|
    next if not line
    line.size.times do |i|
      elem = line[i].to_s
      col = " " * colszs[i]
      elem.size.times do |j|
        col[j] = elem[j]
      end
      out += col + " "
    end
    out += "\n"
  end
  return out
end

def elapsedTime(path)
  begin
    s = File::Stat.new(path)
    if s then 
      return Time.now - s.mtime
    end
  rescue
    return nil
  end
end

def now()
  return Time.now()
end

def nowi()
  return Time.now.to_i()
end
def unixtime(date)
  return Time::parse(date).utc.to_i
end


def nowdate()  # mysql datetime format
  todate(Time.now())
end
def todate(t)
  return sprintf( "%04d-%02d-%02d %02d:%02d:%02d", t.year,t.month,t.day, t.hour,t.min,t.sec )
end


def shortdate(sec)
  if sec < 60 then
    return "now"
  elsif sec < 3600 then
    return "#{(sec/60).to_i}min"
  elsif sec < 3600*24 then
    return "#{(sec/60/60).to_i}hr"
  elsif sec < 3600*24*365 then
    return "#{(sec/60/60/24).to_i}day"
  else
    return "#{(sec/60/60/24/365).to_i}year"
  end
end

# argv : json conf file paths (merged)
class MiniWebRequest
  def initialize(req)
    @req = req
    @data = {}
  end
  def set(name,val)
    @data[name]=val
  end
  def get(name)
    return @data[name]
  end
  def method_missing(name,*args)
    @req.send(name,*args)
  end
end

class MiniWeb
  def initialize()
    @global = false
  end
  def configure(h)
    @conf = h
    @bindaddr = @conf["bindAddress"]
    if ! @bindaddr then @bindaddr = "127.0.0.1" end
    @port = @conf["webPort"]  
    if ! @port then @port = @conf["port"] end
    if ! @port then 
      raise "MiniWeb: 'port', or 'webPort' is required in config"
    end
    @shutdownOnException = true  # default is on
    if @conf["shutdownOnException"] == false then 
      @shutdownOnException = false
    end
  end

  def onPOST(&blk)
    @recvpost = blk
  end
  def onGET(&blk)
    @recvget = blk
  end

  def terminate()
    cmd("rm -f #{@pidfile}")
    @srv.shutdown()
  end

  def useGlobalTrapAndPidFile()
    if $miniweb_global_service then
      raise "MiniWeb: cannot use 2 instances of MiniWeb global service in a process"
    end
    if ! @conf["pidFile"] then 
      raise "MiniWeb: useGlobalTrapAndPidFile: 'pidFile' required in config"
    end
    @pidpath = @conf["pidFile"]
    @global = true
    trap("INT"){terminate()}
    trap("TERM"){terminate()}
  end

  def start()
    p "MiniWeb: starting server: #{@port} #{@bindaddr}"

    @srv = WEBrick::HTTPServer.new({ 
                                     :BindAddress => @bindaddr,
                                     :Port => @port
                                   })
    @srv.mount_proc("/") do |req,res|
      def res.sendJSON(h)
        self.body = h.to_json
        self["Content-Type"] = "application/json"
      end
      def res.sendHTML(t)
        self.body = t
        self["Content-Type"] = "text/html"
      end
      def res.sendRaw(d)
        self.body = d
        self["Content-Type"] = "text/plain"
      end
      req = MiniWebRequest.new(req)
      begin
        if req.request_method == "POST" then 
          if @recvpost then 
            @recvpost.call(req,res)
          end
        elsif req.request_method == "GET" then
          if @recvget then 
            @recvget.call(req,res)
          end
        end
      rescue
        if @shutdownOnException then
          p "MiniWeb: caught exception, shutting down: #{$!}"
          $!.backtrace.each do |e| p(e) end
          @srv.shutdown()
          p "MiniWeb: shutdown() called on port #{@port}"
        end
      end
    end 

    savePid(@pidpath)

    @srv.start()
  end

  def method_missing(name,*args)
    @srv.send(name,*args)
  end
end

def httpRespond(req,res,deftype)
  instance = deftype.new
  ary = req.path.split("/")
  ary.shift
  fname = ary[0]
  args = ary.dup
  args.shift
  req.set( "paths", args )
  def req.paths()
    return @data["paths"]
  end
  instance.send( fname, req,res )

end



class MysqlWrapper
  def initialize(*args)
    require "mysql"
    host,user,pw,db = args[0],args[1],args[2],args[3]
    if args.size == 1 then 
      conf = args[0]
      host,user,pw,db = conf["host"], conf["user"], conf["password"], conf["database"]
    end
    @my = Mysql::new(host,user,pw,db)
  end  
  def conv(t,v)
    case t
    when Mysql::Field::TYPE_TINY, Mysql::Field::TYPE_SHORT, Mysql::Field::TYPE_LONG, Mysql::Field::TYPE_INT24, Mysql::Field::TYPE_LONGLONG, Mysql::Field::TYPE_DECIMAL, Mysql::Field::TYPE_YEAR	
      return v.to_i
    when Mysql::Field::TYPE_FLOAT, Mysql::Field::TYPE_DOUBLE
      return v.to_f
    when Mysql::Field::TYPE_TIMESTAMP, Mysql::Field::TYPE_DATE, Mysql::Field::TYPE_TIME, Mysql::Field::TYPE_DATETIME	
      begin
        tv = Time.parse(v)
        return tv
      rescue
        p "Time.parse failed:#{$!} : #{v}"
        return nil
      end
      return Time.parse(v)
    when Mysql::Field::TYPE_STRING, Mysql::Field::TYPE_VAR_STRING, Mysql::Field::TYPE_BLOB, Mysql::Field::TYPE_CHAR
      return v
    when Mysql::Field::TYPE_SET, Mysql::Field::TYPE_ENUM, Mysql::Field::TYPE_NULL
      raise "column type #{t} is not implemented"
    else
      raise "column type #{t} is not known"
    end
  end
  # return an array of hashes
  def rawquery(s)
    return @my.query(s)
  end
  def queryScalar(s,*args)  
    if args.size > 0 then s = escf(s,*args) end
    res = @my.query(s)
    raise "not a scalar" if res.num_fields > 1 or res.num_rows > 1 
    row = res.fetch_row()
    fld = res.fetch_field
    if !row then 
      return nil
    else
      return conv( fld.type, row[0] )
    end
  end
  def query1(s,*args)  # get 1 hash
    res = query(s,*args)
    return res[0]
  end
  def queryArray(s,*args) # get array of scalar value
    if args.size > 0 then s = escf(s,*args) end
    res = @my.query(s)
    raise "has more fields than 2" if res.num_fields > 1 
    fld = res.fetch_field
    out = []
    res.each do |row|
      out.push( conv( fld.type, row[0] ) )
    end
    return out
  end

  def count(cond, *args)
    return queryScalar( "select count(*) from #{cond}", *args)
  end
  def query(s,*args)
#    p "query:",s
    if args.size > 0 then 
      s = escf(s,*args)
    end
    begin
      res = @my.query(s)
    rescue
      p "mysql query error: '#{$!}' \n#{$!.backtrace} query:'#{s}'"
      return nil
    end
    return nil if !res

    # 
    out = []
#    p "nr:", res.num_rows
    fields = res.fetch_fields
#    fields.each do |f| print("FF:", f.type, "\n" )end
    res.each do |row|
      ent = {}
      fields.size.times do |fi|
        rn = fields[fi].name
        rt = fields[fi].type
        rv = conv(rt, row[fi])
        ent[rn] = rv
#        p "ent[#{rn}] = #{rv}(#{typeof(rv)}) #{rv.class} #{rt} rowval:#{row[fi]}"
      end
      out.push(ent)
    end
    return out
  end
  def esc(s)
    return Mysql::escape_string(s)
  end
  def setstmt(h)
    sets = []
    h.each do |k,v|
      k = k.to_s
      if typeof(v) == Fixnum or typeof(v) == Float then 
        sets.push( "#{k}= #{v}" )
      elsif typeof(v) == String then
        vv = esc( v.to_s )
        sets.push( "#{k}= '#{vv}'" )
      elsif typeof(v) == TrueClass then 
        sets.push( "#{k}=1")
      elsif typeof(v) == FalseClass then 
        sets.push( "#{k}=0")
      elsif typeof(v) == NilClass then
        sets.push( "#{k}=NULL")
      else
        raise "data(#{typeof(v)}) have to be Fixnum or String"
      end
    end    
    return sets.join(",")
  end
  def update(tbl,h,cond,*args)
    q = "update #{tbl} set " + setstmt(h) + " where " + cond
    return query(q,*args)
  end
  def insert(tbl,h)
    q = "insert into #{tbl} set " + setstmt(h)
    query(q)
    q = "select last_insert_id() as id"
    res = query(q)
    res.each do |row|
      return row["id"].to_i
    end
    return nil
  end
  def ensureColumns(name,colnames)
    argh={}
    colnames.each do |nm| argh[nm.to_s]=true end
    res = query( "explain #{name}")
    
    dbh={}
    res.each do |ent|
      fn = ent["Field"]
      dbh[fn] = true
      if ! argh[fn] then 
        p "WARNING: table '#{name}' has excess field '#{fn}'"
      end
    end
    argh.keys.each do |k|
      if !dbh[k] then 
        raise "FATAL: table '#{name}' doesn't have field '#{k}'"
      end
    end
    return true
  end
  def method_missing(name,*args)
    @my.send(name,*args)
  end
end

def esc(s)
  return Mysql::escape_string(s)
end

# replace each ? to each args
def escf(fmt,*args)
  raise "escf: arg mismatch" if fmt.count("?") != args.size
  ind=0
  out = fmt.gsub("?").each do 
    arg = args[ind]
    ind += 1
    if typeof(arg) == String then 
      esc(arg)
    else
      arg
    end
  end
  return out
end


# suck: at the last of file... to avoid emacs ruby-mode bug of keyword 'class' !
def typeof(o)
  return o.class
end

def dumplocal(b)  # usage: argdump(binding)
  out = b.eval( <<EOF
__s = ""
local_variables.each do |name| 
  if name != "__s" and name =~ /^[a-zA-Z0-9]+$/ then
    __s += name + ":"
    __s += eval( name + ".to_s" )
    __s += "(" + eval( "typeof("+name+").to_s" ) + ")"
    __s += '\t'
  end
end
__s += "\n"
EOF
)
  return out
end


# timer funcs
def setInterval(n,&blk)
  t = Thread.new do
    while true
      blk.call()
      sleep n
    end
  end
  return t
end
def setTimeout(n,&blk)
  t = Thread.new do
    sleep n
    blk.call()
  end
  return t
end
