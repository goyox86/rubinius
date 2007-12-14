require 'mspec/runner/formatters/dotted'

class SpecRunner
  def initialize(formatter=nil)
    @only = []
    @except = []
    @formatter = formatter
    if @formatter == nil
      if formatter = ENV['SPEC_FORMATTER']
        klass = Object.const_get(formatter) rescue nil
        if klass.nil?
          puts "Unable to find formatter '#{formatter}', falling back."
          @formatter = DottedFormatter.new
        else
          @formatter = klass.new
        end
      else
        @formatter = DottedFormatter.new
      end
    end
    @formatter.start_timer
    reset_run
  end

  def formatter
    @formatter
  end
  
  def formatter=(formatter)
    @formatter = formatter
  end

  def escape(str)
    str.is_a?(Regexp) ? str : Regexp.new(Regexp.escape(str))
  end
  
  def convert_to_regexps(*args)
    args.inject([]) do |list, item|
      if item.is_a?(String) and File.exist?(item)
        if f = File.open(item, "r")
          f.each do |line|
            line.chomp!
            list << escape(line) unless line.empty?
          end
          f.close
        end
        list
      else
        list << escape(item)
      end
    end
  end
  
  def only(*args)
    @only = convert_to_regexps(*args)
  end
  
  def except(*args)
    @except = convert_to_regexps(*args)
  end
  
  def before(at=:each, &block)
    case at
    when :each
      @before_each << block
    when :all
      @before_all << block
    else
    end
  end
  
  def after(at=:each, &block)
    case at
    when :each
      @after_each << block
    when :all
      @after_all << block
    end
  end
  
  def it(msg, &block)
    @it << [msg, block]
  end
  
  def describe(*args)
    reset_run
    msg = args.join " "
    formatter.before_describe(msg)
    yield
    
    @before_all.each { |ba| instance_eval &ba }
    @it.each do |msg, block|
      formatter.before_it(msg)
      begin
        begin
          @before_each.each { |be| instance_eval &be }
          instance_eval &block
          Mock.verify_count
        rescue Exception => e
          formatter.exception(e)
        ensure
          @after_each.each { |ae| instance_eval &ae }
          Mock.cleanup
        end
      rescue Exception => e
        formatter.exception(e)
      end
      formatter.after_it(msg)
    end
    @after_all.each { |aa| instance_eval &aa }
    formatter.after_describe(msg)
  end
  
  private
  
  def reset_run
    @before_each = []
    @before_all  = []
    @after_each  = []
    @after_all   = []
    @it          = []
  end
end
