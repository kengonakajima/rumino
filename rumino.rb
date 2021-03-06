#
# rumino: for quick hack servers
#

require "rubygems"
require "json"
require "fileutils"
require "erb"
require "net/smtp"
require "webrick"
require "cgi"
require "pp"
require "httpclient"


def assert(x,*msg)
  if !x then 
    raise msg.join()
  end
end

def error(*ary)
  s = ary.join(" ")
  raise(s)
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


def pp_s(h)
  return PP.pp(h,"").strip
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
def cmdq(s)
  return `#{s}`
end


def differ(h1,h2)
  return Marshal.dump(h1) != Marshal.dump(h2)
end

def md5(s)
  return Digest::MD5.new.update(s)
end
def sha1(s)
  return Digest::SHA1.hexdigest(s)
end

# globs = [ "*.rb", "js/*.js", .. ]
def monitorFiles(globs, &blk )
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
        blk.call( changed )
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
    p  $!
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

# opt[0]: [ "hoge.wav", "fuga.png" ]
def sendmail(from,to,subj,msg,*opts)
  if opts.size == 1 then
    files = opts[0]
  end
  if not files then files = [] end

  date = Time.now.to_s

  text  = "Subject: #{subj}\n"
  text += "From: #{from}\n"
  if files.size == 0 then
    text += "Content-type: text/plain; charset=iso-2022-jp\n"
  else
    p "multipart"
    boundary = Digest::SHA1.hexdigest(Time.now.to_f.to_s)
    text += "Content-type: multipart/mixed; boundary=" + boundary + "\n"
    text += "MIME-Version: 1.0\n"
  end
  text += "Sender: #{from}\n"
  text += "Date: #{date}\n"
  text += "To: #{to}\n"
  text += "\n"
  if files.size == 0 then
    text += "#{msg}\n"
  else
    text += "--" + boundary + "\n"
    text += "Content-Type: text/plain; charset=iso-2022-jp;\n"
    text += "Content-Transfer-Encoding: 7bit\n"    
    text += "\n"
    text += "#{msg}\n"
    text += "\n"
    files.size.times do |i|
      f = files[i]
      data = readFile(f)
      if data then
        p "path: #{f} datalen: #{data.size}"
        text += "--" + boundary + "\n"
        bn = File.basename(f)
        text += "Content-Type: application/octet-stream; name=\"#{bn}\"\n"
        text += "Content-Disposition: attachment; filename=\"#{bn}\"\n"
        text += "Content-Transfer-Encoding: base64\n"        
        text += "\n"
        text += [data].pack("m")
      else
        p "file #{f} not found"
      end      
      
      if i == files.size-1 then
        text += "--" + boundary + "--\n"
      end
    end
  end

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
def killTZ(datestr)
  datestr =~ /(.*)-[0-9][0-9]:[0-9][0-9]/ 
  if $1 then
    return $1
  else
    return datestr
  end
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
$MIMETypes = {
  "txt" => "text/plain",
  "md" => "text/plain",
  "js" => "text/javascript",
  "json" => "application/json",
  "css" => "text/css",
  "png" => "image/png",
  "jpg" => "image/jpeg",
  "jpeg" => "image/jpeg",
  "gif" => "image/gif",
  "bmp" => "image/bmp",  
  "html" => "text/html",
  "htm" => "text/html",
  "pdf" => "application/pdf",
  "wav" => "audio/wav",
  "mp3" => "audio/mp3"
}

class MiniWebException < Exception
  def initialize(s)
    @msg = s
  end
  def to_s() return @msg end
end
 
class MiniWeb
  def initialize(h)
    p "MiniWeb:", h.to_json
    @global = false

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

    @recvpost = nil
    @recvget = nil
  end

  def onPOST(&blk)
    @recvpost = blk
  end
  def onGET(&blk)
    @recvget = blk
  end


  def start()
    p "MiniWeb: starting server: #{@port} #{@bindaddr}"

    @srv = WEBrick::HTTPServer.new({ 
                                     :BindAddress => @bindaddr,
                                     :Port => @port
                                   })
    @srv.mount_proc("/") do |req,res|
      def res.sendRaw(code,ct,data)
        self.status = code
        self.body = data
        self["Content-Type"] = ct
      end
      def res.sendJSON(h)
        self.sendRaw( 200, "application/json", h.to_json )
      end
      def res.sendPPHTML(h)
        self.sendRaw( 200, "text/html", "<html><body><pre>" + pp_s(h)  + "</pre></body></html>" )
      end
      def res.error(emsg)
        self.sendJSON({ :message => emsg })
        raise MiniWebException.new(emsg)
      end
      def res.sendHTML(t)
        self.sendRaw( 200, "text/html", t)
      end


      def res.sendFile(path)
        mtype = nil
        $MIMETypes.each do |ext,mt|
          if path =~ /\.#{ext}$/ then
            mtype = mt
            break
          end
        end
        mtype = "text/plain" if mtype == nil 
          
        code = nil
        data = readFile(path)
        if data 
          code = 200 
        else
          code = 404
          data = "not found"
        end
        return self.sendRaw( code, mtype, data )
      end
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
        t = typeof($!).to_s
        if t =~ /^WEBrick::HTTPStatus/ then
          res.status = $!.to_i
          res["Content-Type"]="text/html"
          p "webrick redirects.."
        else
          if @shutdownOnException then
            p "MiniWeb: caught exception, shutting down: #{$!}"
            $!.backtrace.each do |e| p(e) end
              @srv.shutdown()
            p "MiniWeb: shutdown() called on port #{@port}"
          end
          res.body = "error"
        end
      end
    end 

    @srv.start()
  end

  def method_missing(name,*args)
    @srv.send(name,*args)
  end
end

def httpQueryStringToHash(qstr)
  if !qstr then return nil end 
  h = {}
  ary = qstr.split("&")
  ary.each do |p|
    a,b = p.split("=")
    h[a]=b
  end
  return h
end

def httpRespond(req,res,cbclass)
  objectify(req)
  instance = cbclass.new
  ary = req.path.split("/")
  ary.shift
  fname = ary[0]
  req.paths = ary.dup
  req.paths.shift
  def req.paths()
    return @data["paths"]
  end
  if !fname or fname=="" then
    fname = "default"
  else
    if ! instance.methods.include?(fname) then
      req.paths.unshift(fname)
      fname = "default"
    end
  end
  instance.send( "before", req,res ) if instance.respond_to?( "before" )
  instance.send( fname, req,res )
  instance.send( "after", req,res ) if instance.respond_to?( "after" )
end

def httpServeStaticFiles(req,res,docroot,exts)
  return false if req.path =~ /\?/ 
  return false if req.path =~ /\.\./ 
  exts.each do |ext|
    return res.sendFile("#{docroot}#{req.path}") if req.path =~ /\.#{ext}$/ 
  end
  res.sendRaw( 404, "text/plain", "not found" )
  return false
end


class MysqlWrapper
  attr_accessor :doLog, :lastQuery
  def initialize(*args)
    require "mysql"
    host,user,pw,db = args[0],args[1],args[2],args[3]
    if args.size == 1 then 
      conf = args[0]
      host,user,pw,db = conf["host"], conf["user"], conf["password"], conf["database"]
    end
    @my = Mysql::new(host,user,pw,db)
    @doLog = false
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

  def printLog(s)
    @lastQuery = s
    if @doLog then
      p pp_s(["mysql query ",s ])
    end
  end

  # return an array of hashes
  def rawquery(s)
    printLog(s)
    return @my.query(s)
  end
  def queryScalar(s,*args)  
    if args.size > 0 then s = escf(s,*args) end
    printLog(s)
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
    printLog(s)
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
    if args.size > 0 then 
      s = escf(s,*args)
    end
    begin
      printLog(s)
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
      elsif typeof(v) == String or typeof(v) == WEBrick::HTTPUtils::FormData or typeof(v) == Symbol then
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
    q = "update #{tbl} set " + setstmt(h) + " where " + escf(cond,*args)
    return query(q)
  end

  def hasId(tbl)
    res = query( "explain #{tbl}")
    res.each do |ent|
      fn = ent["Field"]
      return true if fn == "id" 
    end
    return false
  end
#  def replace(tbl,h)
#    query("replace into #{tbl} set " + setstmt(h) )
#  end
  def insert(tbl,h)
    query("insert into #{tbl} set " + setstmt(h) )
    if hasId(tbl) then
      id = queryScalar("select last_insert_id() as id")
      assert(id)
      id=id.to_i
      if id > 0 then # this table ha auto_increment!
        return query1( "select * from #{tbl} where id=?",id)
      end
    end
    return h
  end

  def ensureTable(name, confary)
    cols={}
    inds={}
    confary.each do |ent|
      colname,t,indflag = ent[0].to_s,ent[1],ent[2]
      cols[colname] = t
      if indflag then
        inds[colname] = true
      end
    end
    
    raise "no column" if cols.keys.size == 0
    defs=[]
    
    cols.each do |k,v|
      defs.push( "#{k} #{v}" )
    end
    inds.each do |k,v|
      defs.push( "index(#{k})" )
    end

    q= "create table if not exists #{name} ( " + defs.join(",") + ")"
    query(q)

    # if no, alter table!
    res = query("explain #{name}" )
      
    dbh={}
    res.each do |ent|
      fn = ent["Field"]
      dbh[fn] = true
      if ! cols[fn] then 
        p "WARNING: table '#{name}' has excess field '#{fn}'"
      end
    end

    addcolumn = false
    cols.each do |nm,t|  
      if !dbh[nm] then
        addcolumn = true
        q = "alter table #{name} add column #{nm} #{t}"
        p(q)
        query(q)
        if inds[nm] then
          q = "alter table #{name} add index(#{nm})"
          p(q)
          query(q)
        end
      end
    end
    return addcolumn
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
  return fmt if args.size==0 

  argneed = fmt.count("?")
  raise "escf: arg number mismatch. fmt has #{argneed}, #{args.size} given. fmt:#{fmt}" if argneed != args.size
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


# exit process and clean it

def usePidfile(pidfile)
  return false if !pidfile 
  if ! savePid(pidfile)   then
    p "cannot save pid file : ", pidfile, "\n"
    return false
  end
  $_rumino_pidpath = pidfile
  trap("INT") do exitCleanPidfile(1) end
  trap("TERM") do exitCleanPidfile(1) end
  p "saved pid file at ", pidfile, "  listen to INT and TERM.."
  return true
end

def exitCleanPidfile(code)
  cmd("rm -f #{$_rumino_pidpath}")  
  p "call exit!()"
  exit!(code)
end


class Curl
  def initialize(prefix)
    @prefix = prefix
  end
  def get(path)
    hc = HTTPClient.new
    path = URI.escape(path)
    p "GET: #{path}"
    res = hc.get(@prefix+path)
    if res.code >=400 and res.code <=499 then
      return nil
    end
    return res.content
  end
  def post(path,datahash)
    hc = HTTPClient.new
    res = hc.post(@prefix+path,datahash)
    return res.content
  end
  def getJSON(path)
    s = get(path)
    j = JSON.parse(s)
    return j
  end

end


$__genTmpPath_cnt =0
def genTmpPath()
  $__genTmpPath_cnt += 1
  return "/tmp/_tmp_#{getpid()}_#{nowi()}_#{$__genTmpPath_cnt}"
end


#
#
#

class Hash
  def pick(*args)
    out={}
    args.each do |arg|
      if typeof(arg)==Array then
        arg.each do |name|
          name = name.to_s
          if self[name] then out[name]=self[name] end 
        end
      else
        name = arg.to_s
        if self[name] then out[name]=self[name] end 
      end
    end
    return out
  end
  def valsort()
    return self.sort do |a,b| a[1] <=> b[1] end
  end
end

# suck: at the last of file... to avoid emacs ruby-mode bug of keyword 'class' !
def typeof(o)
  return o.class
end


def objectify(cls)
  if typeof(cls) != Class then
    cls = typeof(cls)
  end
  src = <<EOF
class #{cls}
  def id()
    return self["id"]
  end
  # for non-hash classes
  def method_missing(name,*args)
    name = name.to_s
#    p( "MM: '", name,"'",typeof(name))
    if name =~ /^(.*)\=$/ then # set
      methname = $1
      if #{cls}.respond_to?("[]") then
        if self[methname.to_sym] then
          self[methname.to_sym] = nil
        end
        self[methname] = args[0]
      else
        if @data==nil then @data={} end
        @data[methname] = args[0]
      end
      return args[0]
    else # get
      if #{cls}.respond_to?("[]") then
        v = self[name]
        if !v then
          v = self[name.to_sym]
        end
        return v
      else
         if #{cls}.respond_to?(name) then
          return self.send(name)
         else
           v = @data[name]
           if !v then
             v = @data[name.to_sym]
           end
          return v
        end
      end
    end
    return nil
  end
end
EOF
  eval(src)
       
end

objectify(Hash)



