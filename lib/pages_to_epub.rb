require 'yaml'
require 'erb'
require 'rpub'
require 'fileutils'

class PagesToEpub
  attr_reader :pages

  def initialize(pages)
    @pages = pages
             .select { |page| page[:body].to_s.length.nonzero?}
             .sort_by { |page| page[:title] }
  end

  def to_html
    in_dir do
      layout = File.read('templates/layout.html.erb')
      page_template = File.read('templates/page.html.erb')

      pages_html = pages.map { |page|
        ERB.new(page_template).result(binding)
      }.join

      ERB.new(layout).result(binding)
    end
  end

  def to_pdf
    in_dir do
      if system('which', 'wkhtmltopdf').empty?
        raise "wkhtmltopdf not installed on this machine" 
      end

      File.open('tmp/book.html', 'w') { |f| f.write(to_html) }

      system(*%w(wkhtmltopdf --ignore-load-errors --encoding UTF-8 tmp/book.html book.pdf))

      File.delete('tmp/book.html')
    end
  end

  def to_epub(config = {})
    current_dir = Dir.pwd
    in_dir do
      page_template = File.read('templates/page.md.erb')

      Dir.chdir('epub') do
        pages.each_with_index do |page, chapter|
          markdown = ERB.new(page_template).result(binding) 

          page[:body].gsub!(/></, ">\n\n<")
          chapter_filename = "#{chapter.to_s.rjust(5, '0')}.md"
          File.open(chapter_filename, 'w') { |f|
            f.write(markdown)
          }
        end

        config[:title] ||= 'New Epub Book'

        File.open('config.yml', 'w') do |file|
          file.write(config.to_yaml)
        end

        system('rpub', 'compile')

        FileUtils.mv(Dir.glob('*.epub'), current_dir)
        FileUtils.rm(Dir.glob('*'))
      end
    end
  end

  private

  def in_dir(&block)
    dir = File.expand_path('../..', __FILE__)
    Dir.chdir(dir, &block)
  end
end
