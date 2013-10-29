require 'nokogiri'
require 'peregrin'

class Extractor
  attr_accessor :pourcent_extract

  SKIP_TAG = ["strong", "span", "body", "b", "em", "i"]

  def initialize(filepath, pourcent_extract = 5)
    @source_file = Peregrin::Epub.read(filepath)
    @source_book = @source_file.to_book
    @pourcent_extract = pourcent_extract
    @added_content = []
    @final_para = nil
    @new_uuid = nil
    @debug = false

    total = get_total_count
    if @limit.nil?
      @limit = (total * @pourcent_extract / 100).round
    end
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
    puts "TOTAL #{total}" if @debug
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
        unless t.text.nil?
          unless SKIP_TAG.include?(t.name)
            text = t.text.gsub("\r\n", "").gsub("\n", "").strip

            count_length += text.length
            if count_length >= @limit && stop_component == false && !["comment", "br", "a", "i", "em", "span", "b", "strong", "text"].include?(t.name)
              stop_component = true
            end
          end
        end
        if stop_component == true
          if stop_node.nil?
            if t.name == "text"
              stop_node = t.parent()
            else
              stop_node = t
            end
          else
            unless node_in_children?(t, stop_node)
              t.remove
            end
          end
        end
      end

    if stop_component == true
      if @final_para.nil?
        stop_node.set_attribute('id', 'last_elem_preview')
      else
        body = doc.at_css("body")
        body.add_child(@final_para)
      end
    end

      c.contents = doc.to_html
    end

    @source_book.components.delete_if{|c| component_remove.include?(c)}
    clean_chapters(component_remove)
    clean_link(component_remove)

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

  def set_max_word(limit)
    @limit = limit
  end

  def debug_mode(debug = false)
    @debug = debug
  end

  def component_have_id?(component, id)
    doc = Nokogiri::HTML.parse(component.contents)
    find_id = doc.at_css("##{id}")
    if !find_id.nil?
      return true
    end
    return false
  end

  def find_chapter_from_components(component, chapters)
    found_chapter = nil
    chapters.each do |c|
      if !c.children.empty?
        res = find_chapter_from_components(component, c.children)
        if !res.nil?
          found_chapter = res
        end
      end

      if c.src.match('#')
        id = c.src.split('#')[1]
        if component_have_id?(component, id)
          found_chapter = c
        end
      else
        if c.src == component.src
          found_chapter = c
        end
      end
    end
    return found_chapter
  end

  def clean_chapters(component_remove, chapters = nil)
    @last_comp = @source_book.components.last if @last_comp.nil?
    @last_chapter = find_chapter_from_components(@last_comp, @source_book.chapters) if @last_chapter.nil?
    @current_pos = 1 if @current_pos.nil?
    if chapters.nil?
      search_chaps = @source_book.chapters
    else
      search_chaps = chapters
    end
    search_chaps.map! do |c|

      change_chapter = false
      if component_remove.map(&:src).include?(c.src.split('#').first)
        change_chapter = true
      end

      if c.src.split('#').size > 1 && change_chapter == false
        @source_book.components.each do |comp|
          if c.src.split('#').first == comp.src && !component_have_id?(comp, c.src.split('#')[1])
            #puts "test #{comp.src} with #{c.src.split('#').last}"
            change_chapter = true
          end
        end
      end

      if change_chapter == true
        c.src = @last_comp.src.split('#').first + "#last_elem_preview"
      end
      if @last_pos.nil? && change_chapter == true
        @last_pos = @current_pos
      end
      if change_chapter == true
        c.position = @last_pos
      else
        c.position = @current_pos
      end
      @current_pos += 1

      if !c.children.empty?
        clean_chapters(component_remove, c.children)
      end

      c
    end
  end

  def clean_link(component_remove)
    @last_comp = @source_book.components.last if @last_comp.nil?
    last_para = @last_comp.src.split('#').first + "#last_elem_preview"
    @source_book.components.each do |c|
      doc = Nokogiri::HTML.parse(c.contents)
      doc.css('a').each do |link|
        if !link.attr('href').nil?
          href = link.attr('href')
          next if href.match('http:')
          if href.match('#')
            html = href.split('#').first
            id = href.split('#').last
            if component_remove.map(&:src).include?(html)
              link.set_attribute('href', last_para)
            end
            if !component_have_id?(c, id)
              link.set_attribute('href', last_para)
            end
          else
            if component_remove.map(&:src).include?(href)
              link.set_attribute('href', last_para)
            end
          end
        end
        c.contents = doc.to_html
      end
    end
  end

  def node_in_children?(source_node, target_node)
    source_node.traverse do |t|
      return true if t == target_node
    end
    return false
  end

end
