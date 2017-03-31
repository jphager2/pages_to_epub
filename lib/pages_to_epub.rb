require 'yaml'
require 'erb'
require 'rpub'

class PagesToEpub
  attr_reader :pages

  def initialize(pages)
    @pages = pages
             .select { |page| page[:body].to_s.length.nonzero?}
             .sort_by { |page| page[:title] }
  end

  def to_html
    in_dir do
      puts Dir.pwd
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
      if `which wkhtmltopdf`.empty?
        raise "wkhtmltopdf not installed on this machine" 
      end

      File.open('tmp/book.html', 'w') { |f| f.write(to_html) }

      `wkhtmltopdf --ignore-load-errors --encoding UTF-8 tmp/book.html book.pdf`

      File.delete('tmp/book.html')
    end
  end

  def to_epub(config = {})
    in_dir do
      page_template = File.read('templates/page.md.erb')

      pages.each_with_index do |page, chapter|
        markdown = ERB.new(page_template).result(binding) 

        page[:body].gsub!(/></, ">\n\n<")
        File.open("epub/#{chapter.to_s.rjust(5, '0')}.md", 'w') { |f|
          f.write(markdown)
        }
      end

      File.open('epub/config.yml', 'w') do |file|
        file.write(config.to_yaml)
      end

      Dir.chdir('epub') do
        `rpub complie`
        `rm config.yml`
        `rm *.md`
        `mv *.epub ..`
      end
    end
  end

  private

  def in_dir(&block)
    dir = File.expand_path('../..', __FILE__)
    Dir.chdir(dir, &block)
  end
end
