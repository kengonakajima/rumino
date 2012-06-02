#
# rumino: for quick hack servers
#

require "rubygems"
require "json/pure"
require "fileutils"

def assert(x)
  if !x then 
    raise 
  end
end
def strdate()
  t = Time.now
  return sprintf( "%d_%02d%02d_%02d%02d%02d", t.year,t.month,t.day, t.hour,t.min,t.sec )
end

def prt(*ary)
  STDERR.print(ary.join())
end
def p(*ary)
  STDERR.print( "[",Time.now,"] ",ary.join(),"\n")
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
    f.write( "#{Process.pid}" )
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
  return out.join("\n")
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

