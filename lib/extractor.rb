require 'nokogiri'
require 'peregrin'

class Extractor
  attr_accessor :pourcent_extract

  SKIP_TAG = ["strong", "span", "div", "p", "body"]

  def initialize(filepath, pourcent_extract = 5)
    @source_file = Peregrin::Epub.read(filepath)
    @source_book = @source_file.to_book
    @pourcent_extract = pourcent_extract
    @added_content = []
    @final_para = nil
    @new_uuid = nil

    total = get_total_count
    @limit = (total * @pourcent_extract / 100).round    
  end

  def get_total_count
    component_stats = []
    total = 0

    @source_book.components.each do |c|
      component_stats << {:component => c, :count => count_text(c.contents)}
    end
    component_stats.each do |c|
      total += c[:count]
    end
    #puts "TOTAL #{total}" 
    return total
  end

  def count_text(content)
    doc = Nokogiri::HTML.parse(content)
    count_length = 0
    doc.at_css('body').traverse do |t|        
      unless t.text.nil?
        next if  SKIP_TAG.include?(t.name)
        text = t.text.gsub("\r\n", "").gsub("\n", "").strip        
        count_length += text.size
        end
      end
    return count_length
  end

  def get_extract(filepath)

    component_remove = []

    count_length = 0
    stop_component = false
    stop_node = nil
    @source_book.components.each do |c|

      if stop_component == true
        component_remove << c
        next
      end      

      doc = Nokogiri::HTML.parse(c.contents)
      doc.at_css('body').traverse do |t|
        unless SKIP_TAG.include?(t.name)        
          unless t.text.nil?          
            text = t.text.gsub("\r\n", "").gsub("\n", "").strip          

            count_length += text.length          
            if count_length >= @limit && stop_component == false
              stop_component = true
              stop_node = t
            end
          end
          if stop_component == true
            t.remove
          end
        end
      end

      c.contents = doc.to_html
    end

    @source_book.components.delete_if{|c| component_remove.include?(c)}
    clean_chapters(component_remove)    

    unless @final_para.nil?
      page = @source_book.components.last
      doc = Nokogiri::HTML.parse(page.contents)
      body = doc.at_css("body")
      body.add_child(html_data)
      @source_book.components.last.contents = body.to_html
    end

    @added_content.each do |c|
    	@source_book.add_component(c[0], c[1], c[2])
    end


    images_to_keep = []
    @source_book.components.each do |c|    
      doc = Nokogiri::HTML.parse(c.contents)
      images = doc.css("img")
      images.each do |img|
        images_to_keep << img.attr("src").split("/").last
      end
    end

    @source_book.resources.delete_if do |r|      
      unless images_to_keep.include?(r.src.split("/").last)
        if r.media_type.match("image")
          true
        else
          false          
        end
      else
        false
      end
    end

    if @source_book.property_for("type").nil?
      @source_book.add_property("type", "preview")
    else
      type_elem = @source_book.properties.select{|p| p.key == "type"}.first
      type_elem.value = "preview"
    end

    unless @new_uuid.nil?
      if @source_book.property_for("bookid").nil?
        @source_book.add_property("bookid", @new_uuid)
      else
        type_elem = @source_book.properties.select{|p| p.key == "bookid"}.first
        type_elem.value = @new_uuid
      end      
    end

    if @source_book.property_for("source").nil?
      @source_book.add_property("source", @source_book.property_for('identifier'))
    else
      type_elem = @source_book.properties.select{|p| p.key == "source"}.first
      type_elem.value = @source_book.property_for('identifier')
    end    
    
    # si epub3 on met a jour le <meta property="dcterms:modified">2011-01-01T12:00:00Z</meta>

    # @source_book.properties.each do |p|
    #   puts p.inspect
    # end

    epub = Peregrin::Epub.new(@source_book)
    epub.write(filepath)
  end

  def add_final_para(html_data)
    @final_para = html_data
  end

  def add_final_page(name, content, media_type = "application/xhtml+xml")
  	@added_content << [name, content, media_type]
  end

  def set_book_identifier(identifier)
    @new_uuid = identifier
  end

  def clean_chapters(component_remove, chapters = nil)
    last_chapter = @source_book.components.last
    if chapters.nil?
      search_chaps = @source_book.chapters
    else
      search_chaps = chapters
    end
    search_chaps.map! do |c|      
      if !c.children.empty?
        clean_chapters(component_remove, c.children)
      end
      if component_remove.map(&:src).include?(c.src.split('#').first)
        c.src = last_chapter.src                
      end
      c
    end
  end

end
