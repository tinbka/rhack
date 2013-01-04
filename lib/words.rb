# encoding: utf-8
if !defined? RuDict and !defined? String::RuDict
    
  if d = RHACK::CONFIG['rudict'] and File.file? d and (d = YAML.load(read d)).is Hash
    String::RuDict = d
  end
  
end

class String
  RuDict = {} if !defined? RuDict
  
  def x(int)
    "#{int} #{if cyr?
        if forms = RuDict[self]
          mod = int%10
          forms[mod == 1 ? 0 : int.in(2..4) ? 1 : 2]
        else self end
      else
        mod = int%10
        int == 1 ? self : pluralize
      end}"
  end
  
end