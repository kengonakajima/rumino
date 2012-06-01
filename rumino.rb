#
# rumino: for quick hack servers
#

def strdate()
  t = Time.now
  return sprintf( "%d_%02d%02d_%02d%02d%02d", t.year,t.month,t.day, t.hour,t.min,t.sec )
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

