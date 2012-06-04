#
# rumino: for quick hack servers
#

require "rubygems"
require "json/pure"
require "fileutils"
require "erb"
require "net/smtp"

def assert(x)
  if !x then 
    raise 
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
  s = "[",Time.now,"] ",ary.join(),"\n"
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
    p "cannot read json from: #{path}"
    return nil
  end
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

